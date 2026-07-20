--!strict
--@author: Shadow
--@date: 2026/07/18
--[[@description:
	Server-authoritative movement runtime for core movement and parkour mode toggles.
]]
-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local MovementTypes = require("./MovementTypes")
local MovementNetwork = require("./MovementNetwork") :: any

-----------------------------
-- TYPES --
-----------------------------
type MovementMode = MovementTypes.MovementMode
type MovementAction = MovementTypes.MovementAction
type ModeFlags = MovementTypes.ModeFlags
type ActionCooldownMap = MovementTypes.ActionCooldownMap
type MovementConfig = MovementTypes.MovementConfig
type ActionRequestPayload = MovementTypes.ActionRequestPayload
type ActorMovementProfile = MovementTypes.ActorMovementProfile
type NetworkMovementSnapshot = MovementTypes.NetworkMovementSnapshot
type NormalizedActionRequest = {
	Action: MovementAction,
	Direction: Vector3?,
	RunEnabled: boolean?,
}

-----------------------------
-- VARIABLES --
-----------------------------
local MovementService = {}

local activeProfiles: { [Instance]: ActorMovementProfile } = {}
local baseWalkSpeedChangedConnections: { [Instance]: RBXScriptConnection } = {}
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local missingBaseStatWarned: { [Instance]: boolean } = {}
local initialWalkSpeedApplyDelay = 0.15

local defaultConfig: MovementConfig = {
	ModesDefault = {
		Core = true,
		Parkour = false,
	},
	Core = {
		BaseFallbackWalkSpeed = 16,
		BaseWalkSpeedAttributeKey = "BaseWalkSpeed",
		RunMultiplier = 1.5,
		RunFlatBonus = 0,
		DodgeImpulse = 48,
		DodgeDuration = 0.2,
		DodgeCooldown = 0.8,
	},
	Parkour = {
		VaultEnabled = true,
		WallRunEnabled = true,
		ClimbEnabled = true,
		SlideEnabled = true,
		VaultImpulse = 32,
		WallRunSpeed = 28,
		ClimbSpeed = 20,
		SlideImpulse = 36,
	},
	Cooldowns = {
		RunToggle = 0,
		Dodge = 0.8,
		Vault = 0.5,
		WallRun = 0.2,
		Climb = 0.1,
		Slide = 0.6,
	},
}

local activeConfig: MovementConfig = defaultConfig

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function CloneCooldownMap(source: ActionCooldownMap): ActionCooldownMap
	local sourceAny = source :: any
	return {
		RunToggle = sourceAny.RunToggle,
		Dodge = sourceAny.Dodge,
		Vault = sourceAny.Vault,
		WallRun = sourceAny.WallRun,
		Climb = sourceAny.Climb,
		Slide = sourceAny.Slide,
	} :: ActionCooldownMap
end

local function CloneModeFlags(source: ModeFlags): ModeFlags
	return {
		Core = source.Core,
		Parkour = source.Parkour,
	}
end

local function GetHumanoid(instance: Instance): Humanoid?
	if instance:IsA("Player") then
		local character = instance.Character
		if not character then
			return nil
		end
		return character:FindFirstChildOfClass("Humanoid")
	end

	if instance:IsA("Model") then
		return instance:FindFirstChildOfClass("Humanoid")
	end

	return nil
end

local function GetCharacterModel(instance: Instance): Model?
	if instance:IsA("Player") then
		return instance.Character
	end

	if instance:IsA("Model") then
		return instance
	end

	return nil
end

local function GetRootPart(instance: Instance): BasePart?
	local model: Model? = nil
	if instance:IsA("Player") then
		model = instance.Character
	elseif instance:IsA("Model") then
		model = instance
	end

	if not model then
		return nil
	end

	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end

	return model.PrimaryPart
end

local function ApplyWalkSpeed(instance: Instance, profile: ActorMovementProfile)
	local humanoid = GetHumanoid(instance)
	if not humanoid then
		return
	end

	local baseWalkSpeed = activeConfig.Core.BaseFallbackWalkSpeed
	local baseWalkSpeedAttributeKey = activeConfig.Core.BaseWalkSpeedAttributeKey
	local character = GetCharacterModel(instance)
	if character then
		local rawAttribute = character:GetAttribute(baseWalkSpeedAttributeKey)
		if type(rawAttribute) == "number" then
			baseWalkSpeed = rawAttribute
			missingBaseStatWarned[instance] = nil
		elseif not missingBaseStatWarned[instance] then
			missingBaseStatWarned[instance] = true
			warn(
				string.format(
					"[MovementService] Stat key '%s' not found or invalid on %s. Falling back to BaseFallbackWalkSpeed (%s).",
					baseWalkSpeedAttributeKey,
					character:GetFullName(),
					tostring(baseWalkSpeed)
				)
			)
			humanoid.WalkSpeed = 0
			return
		end
	end

	local finalWalkSpeed = baseWalkSpeed
	if profile.IsRunning and profile.EnabledModes.Core then
		finalWalkSpeed = (baseWalkSpeed * activeConfig.Core.RunMultiplier) + activeConfig.Core.RunFlatBonus
	end

	humanoid.WalkSpeed = finalWalkSpeed
end

local function ScheduleInitialWalkSpeedApply(instance: Instance, profile: ActorMovementProfile)
	task.delay(initialWalkSpeedApplyDelay, function()
		local currentProfile = activeProfiles[instance]
		if currentProfile ~= profile then
			return
		end

		ApplyWalkSpeed(instance, profile)
	end)
end

local function DisconnectConnection(registry: { [Instance]: RBXScriptConnection }, key: Instance)
	local connection = registry[key]
	if connection then
		connection:Disconnect()
		registry[key] = nil
	end
end

local function BindBaseWalkSpeedSignal(instance: Instance)
	local character = GetCharacterModel(instance)
	if not character then
		return
	end

	DisconnectConnection(baseWalkSpeedChangedConnections, instance)

	baseWalkSpeedChangedConnections[instance] = character
		:GetAttributeChangedSignal(activeConfig.Core.BaseWalkSpeedAttributeKey)
		:Connect(function()
			local profile = activeProfiles[instance]
			if profile then
				ApplyWalkSpeed(instance, profile)
			end
		end)
end

local function BuildSnapshot(profile: ActorMovementProfile): NetworkMovementSnapshot
	return {
		EnabledModes = CloneModeFlags(profile.EnabledModes),
		IsRunning = profile.IsRunning,
		ActiveAction = profile.ActiveAction,
		CooldownEndsAt = CloneCooldownMap(profile.CooldownEndsAt),
	}
end

local function ReplicateProfile(instance: Instance)
	if not instance:IsA("Player") then
		return
	end

	local profile = activeProfiles[instance]
	if not profile then
		return
	end

	MovementNetwork:ReplicateToPlayer(instance, BuildSnapshot(profile))
end

local function GetOrCreateProfile(instance: Instance): ActorMovementProfile
	local existing = activeProfiles[instance]
	if existing then
		return existing
	end

	local profile: ActorMovementProfile = {
		EnabledModes = CloneModeFlags(activeConfig.ModesDefault),
		IsRunning = false,
		ActiveAction = nil,
		CooldownEndsAt = CloneCooldownMap(activeConfig.Cooldowns),
		LastDirection = Vector3.new(0, 0, -1),
	}

	activeProfiles[instance] = profile
	ScheduleInitialWalkSpeedApply(instance, profile)
	return profile
end

local function IsActionCoolingDown(profile: ActorMovementProfile, action: MovementAction): boolean
	return os.clock() < profile.CooldownEndsAt[action]
end

local function StartCooldown(profile: ActorMovementProfile, action: MovementAction, duration: number)
	profile.CooldownEndsAt[action] = os.clock() + math.max(0, duration)
end

local function GetConfiguredCooldown(action: MovementAction): number
	return activeConfig.Cooldowns[action]
end

local function ResolveDirection(instance: Instance, payloadDirection: Vector3?): Vector3
	if payloadDirection and payloadDirection.Magnitude > 0.001 then
		return payloadDirection.Unit
	end

	local rootPart = GetRootPart(instance)
	if rootPart then
		return rootPart.CFrame.LookVector.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function NormalizeActionRequest(payload: any): NormalizedActionRequest?
	if type(payload) ~= "table" then
		return nil
	end

	local action = payload.Action
	if type(action) ~= "string" then
		return nil
	end

	if
		action ~= "RunToggle"
		and action ~= "Dodge"
		and action ~= "Vault"
		and action ~= "WallRun"
		and action ~= "Climb"
		and action ~= "Slide"
	then
		return nil
	end

	local direction: Vector3? = nil
	if typeof(payload.Direction) == "Vector3" then
		direction = payload.Direction
	end

	local runEnabled: boolean? = nil
	local meta = payload.Meta
	if type(meta) == "table" and type(meta.Enabled) == "boolean" then
		runEnabled = meta.Enabled
	end

	return {
		Action = action,
		Direction = direction,
		RunEnabled = runEnabled,
	}
end

local function HandleRunToggle(instance: Instance, profile: ActorMovementProfile, runEnabled: boolean?)
	if not profile.EnabledModes.Core then
		return
	end

	if IsActionCoolingDown(profile, "RunToggle") then
		return
	end

	profile.IsRunning = if runEnabled == nil then not profile.IsRunning else runEnabled
	profile.ActiveAction = nil
	StartCooldown(profile, "RunToggle", GetConfiguredCooldown("RunToggle"))
	ApplyWalkSpeed(instance, profile)
	ReplicateProfile(instance)
end

local function HandleDodge(instance: Instance, profile: ActorMovementProfile, requestedDirection: Vector3?)
	if not profile.EnabledModes.Core then
		return
	end

	if IsActionCoolingDown(profile, "Dodge") then
		return
	end

	local direction = ResolveDirection(instance, requestedDirection)
	profile.LastDirection = direction
	profile.ActiveAction = "Dodge"
	StartCooldown(profile, "Dodge", math.max(GetConfiguredCooldown("Dodge"), activeConfig.Core.DodgeCooldown))
	ReplicateProfile(instance)

	local rootPart = GetRootPart(instance)
	if rootPart then
		local impulse = direction * activeConfig.Core.DodgeImpulse
		rootPart.AssemblyLinearVelocity += Vector3.new(impulse.X, 0, impulse.Z)
	end

	task.delay(activeConfig.Core.DodgeDuration, function()
		local current = activeProfiles[instance]
		if not current then
			return
		end

		if current.ActiveAction == "Dodge" then
			current.ActiveAction = nil
			ReplicateProfile(instance)
		end
	end)
end

local function HandleParkourAction(instance: Instance, profile: ActorMovementProfile, action: MovementAction)
	if not profile.EnabledModes.Parkour then
		return
	end

	if IsActionCoolingDown(profile, action) then
		return
	end

	profile.ActiveAction = action
	StartCooldown(profile, action, GetConfiguredCooldown(action))
	ReplicateProfile(instance)

	task.delay(0.2, function()
		local current = activeProfiles[instance]
		if not current then
			return
		end

		if current.ActiveAction == action then
			current.ActiveAction = nil
			ReplicateProfile(instance)
		end
	end)
end

local function HandleActionRequest(player: Player, payload: ActionRequestPayload)
	local request = NormalizeActionRequest(payload)
	if not request then
		return
	end

	local profile = GetOrCreateProfile(player)

	if request.Action == "RunToggle" then
		HandleRunToggle(player, profile, request.RunEnabled)
	elseif request.Action == "Dodge" then
		HandleDodge(player, profile, request.Direction)
	elseif
		request.Action == "Vault"
		or request.Action == "WallRun"
		or request.Action == "Climb"
		or request.Action == "Slide"
	then
		HandleParkourAction(player, profile, request.Action)
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function MovementService:SetConfig(config: MovementConfig)
	activeConfig = config
	for instance in pairs(missingBaseStatWarned) do
		missingBaseStatWarned[instance] = nil
	end

	for instance, profile in pairs(activeProfiles) do
		BindBaseWalkSpeedSignal(instance)
		ScheduleInitialWalkSpeedApply(instance, profile)
	end
end

function MovementService:RegisterEntity(instance: Instance)
	local profile = GetOrCreateProfile(instance)
	BindBaseWalkSpeedSignal(instance)
	ScheduleInitialWalkSpeedApply(instance, profile)

	if instance:IsA("Player") then
		local player = instance
		local existingConnection = characterAddedConnections[player]
		if not existingConnection then
			characterAddedConnections[player] = player.CharacterAdded:Connect(function()
				BindBaseWalkSpeedSignal(player)
				local currentProfile = activeProfiles[player]
				if currentProfile then
					ScheduleInitialWalkSpeedApply(player, currentProfile)
				end
			end)
		end
	end

	ReplicateProfile(instance)
end

function MovementService:UnregisterEntity(instance: Instance)
	DisconnectConnection(baseWalkSpeedChangedConnections, instance)
	missingBaseStatWarned[instance] = nil

	if instance:IsA("Player") then
		local player = instance
		local connection = characterAddedConnections[player]
		if connection then
			connection:Disconnect()
			characterAddedConnections[player] = nil
		end
	end

	activeProfiles[instance] = nil
end

function MovementService:GetProfile(instance: Instance): ActorMovementProfile?
	return activeProfiles[instance]
end

function MovementService:SetModeEnabled(instance: Instance, mode: MovementMode, enabled: boolean)
	local profile = GetOrCreateProfile(instance)
	profile.EnabledModes[mode] = enabled

	if mode == "Core" and not enabled then
		profile.IsRunning = false
		profile.ActiveAction = nil
		ApplyWalkSpeed(instance, profile)
	end

	ReplicateProfile(instance)
end

function MovementService:IsModeEnabled(instance: Instance, mode: MovementMode): boolean
	local profile = activeProfiles[instance]
	if not profile then
		return false
	end

	return profile.EnabledModes[mode]
end

function MovementService:Init()
	MovementNetwork:RegisterActionRequestHandler(function(player: Player, payload: ActionRequestPayload)
		HandleActionRequest(player, payload)
	end)
	MovementNetwork:Init()

	Players.PlayerAdded:Connect(function(player)
		self:RegisterEntity(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:UnregisterEntity(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:RegisterEntity(player)
		end)
	end
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(MovementService)
