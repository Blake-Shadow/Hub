--!strict
--@author: Shadow
--@date: 2026-07-19
--[[@description:
	Server-side combat execution service.
	Uses direct DamageFormula with external hitbox target resolver injection.
]]
-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local DamageFormula = require(ReplicatedStorage.Modules.Helpers.DamageFormula.DamageFormula)
local CombatTypes = require("./CombatTypes")
local CombatNetwork = require("./CombatNetwork") :: any

-----------------------------
-- TYPES --
-----------------------------
type CombatActionId = CombatTypes.CombatActionId
type CombatActionRequestPayload = CombatTypes.CombatActionRequestPayload
type CombatFeedbackPayload = CombatTypes.CombatFeedbackPayload
type CombatActionConfig = CombatTypes.CombatActionConfig
type CombatProfile = CombatTypes.CombatProfile
type CombatAttributeKeys = CombatTypes.CombatAttributeKeys
type CombatServiceInitConfig = CombatTypes.CombatServiceInitConfig
type HitboxTargetResolver = CombatTypes.HitboxTargetResolver

type NormalizedCombatRequest = {
	ActionId: CombatActionId,
	Direction: Vector3?,
	Meta: { [string]: any }?,
}

-----------------------------
-- VARIABLES --
-----------------------------
local CombatService = {}

local activeProfiles: { [Instance]: CombatProfile } = {}

local defaultActionConfigs: { [CombatActionId]: CombatActionConfig } = {
	Punch = {
		Cooldown = 0.45,
		HitboxRadius = 6,
		SkillPower = 6,
		Variance = 0.08,
		MinDamage = 1,
		CritChance = 0.1,
		CritMultiplier = 1.5,
		AttackAttributeKey = "BasePower",
		DefenseAttributeKey = "BaseDefense",
	},
}

local activeActionConfigs: { [CombatActionId]: CombatActionConfig } = defaultActionConfigs

local defaultAttributeKeys: CombatAttributeKeys = {
	Attack = "BasePower",
	Defense = "BaseDefense",
	CurrentHealth = "CurrentHealth",
	LastDamage = "LastDamage",
	LastDamageCritical = "LastDamageCritical",
}

local activeAttributeKeys: CombatAttributeKeys = defaultAttributeKeys
local activeHitboxTargetResolver: HitboxTargetResolver? = nil
local hasInitialized = false
local DEBUG_ENABLED = true
local hasWarnedMissingResolver = false

local function CloneActionConfigs(
	source: { [CombatActionId]: CombatActionConfig }
): { [CombatActionId]: CombatActionConfig }
	local cloned = {}
	for actionId, config in pairs(source) do
		cloned[actionId] = table.clone(config)
	end
	return cloned
end

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function ResolveCharacter(instance: Instance): Model?
	if instance:IsA("Player") then
		return instance.Character
	end

	if instance:IsA("Model") then
		return instance
	end

	return nil
end

local function GetHumanoid(character: Model?): Humanoid?
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function GetOrCreateProfile(instance: Instance): CombatProfile
	local existing = activeProfiles[instance]
	if existing then
		return existing
	end

	local cooldownEndsAt = {}
	for actionId in pairs(activeActionConfigs) do
		cooldownEndsAt[actionId] = 0
	end

	local profile: CombatProfile = {
		CooldownEndsAt = cooldownEndsAt,
	}

	activeProfiles[instance] = profile
	return profile
end

local function IsActionCoolingDown(profile: CombatProfile, actionId: CombatActionId): boolean
	return os.clock() < (profile.CooldownEndsAt[actionId] or 0)
end

local function StartCooldown(profile: CombatProfile, actionId: CombatActionId, duration: number)
	profile.CooldownEndsAt[actionId] = os.clock() + math.max(0, duration)
end

local function ApplyDamage(targetCharacter: Model, amount: number)
	local humanoid = GetHumanoid(targetCharacter)
	if humanoid then
		humanoid.Health = math.max(0, humanoid.Health - amount)
	end

	local currentHealthAttribute = targetCharacter:GetAttribute(activeAttributeKeys.CurrentHealth)
	if type(currentHealthAttribute) == "number" then
		targetCharacter:SetAttribute(activeAttributeKeys.CurrentHealth, math.max(0, currentHealthAttribute - amount))
	end
end

local function BuildFeedbackPayload(
	actionId: CombatActionId,
	hitCount: number,
	totalDamage: number,
	criticalHits: number
): CombatFeedbackPayload
	return {
		ActionId = actionId,
		HitCount = hitCount,
		TotalDamage = totalDamage,
		CriticalHits = criticalHits,
		Timestamp = os.clock(),
	}
end

local function ResolveDirection(attackerCharacter: Model, payloadDirection: Vector3?): Vector3
	if payloadDirection and payloadDirection.Magnitude > 0.001 then
		return payloadDirection.Unit
	end

	local rootPart = attackerCharacter:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.CFrame.LookVector.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function NormalizeActionRequest(payload: any): NormalizedCombatRequest?
	if type(payload) ~= "table" then
		return nil
	end

	local actionId = payload.ActionId
	if type(actionId) ~= "string" then
		return nil
	end

	if actionId == "BasicAttack" then
		actionId = "Punch"
	end

	local direction: Vector3? = nil
	if typeof(payload.Direction) == "Vector3" then
		direction = payload.Direction
	end

	local meta: { [string]: any }? = nil
	if type(payload.Meta) == "table" then
		meta = payload.Meta
	end

	return {
		ActionId = actionId,
		Direction = direction,
		Meta = meta,
	}
end

local function ExecutePunch(
	attackerCharacter: Model,
	config: CombatActionConfig,
	direction: Vector3?
): (number, number, number)
	local attackDirection = ResolveDirection(attackerCharacter, direction)

	local attackAttributeKey = config.AttackAttributeKey
	if attackAttributeKey == "" then
		attackAttributeKey = activeAttributeKeys.Attack
	end

	local defenseAttributeKey = config.DefenseAttributeKey
	if defenseAttributeKey == "" then
		defenseAttributeKey = activeAttributeKeys.Defense
	end

	local hitboxTargetResolver = activeHitboxTargetResolver
	if not hitboxTargetResolver then
		if not hasWarnedMissingResolver then
			hasWarnedMissingResolver = true
			warn("[CombatService] Punch requested but HitboxTargetResolver is not configured.")
		end
		return 0, 0, 0
	end

	local targets = hitboxTargetResolver(attackerCharacter, config.HitboxRadius, attackDirection)

	local hitCount = 0
	local totalDamage = 0
	local criticalHits = 0

	for _, targetCharacter in ipairs(targets) do
		local targetHumanoid = GetHumanoid(targetCharacter)
		if targetHumanoid and targetHumanoid.Health > 0 then
			local finalDamage, isCritical = DamageFormula.CalculateFromCharacters(
				attackerCharacter,
				targetCharacter,
				attackAttributeKey,
				defenseAttributeKey,
				config.SkillPower,
				nil,
				nil,
				nil,
				config.CritChance,
				config.CritMultiplier,
				config.Variance,
				config.MinDamage,
				nil,
				nil,
				nil
			)

			ApplyDamage(targetCharacter, finalDamage)
			targetCharacter:SetAttribute(activeAttributeKeys.LastDamage, finalDamage)
			targetCharacter:SetAttribute(activeAttributeKeys.LastDamageCritical, isCritical)

			totalDamage += finalDamage
			if isCritical then
				criticalHits += 1
			end
			hitCount += 1
		end
	end

	if DEBUG_ENABLED then
		print(string.format("[CombatService] %s punched and hit %d target(s).", attackerCharacter.Name, hitCount))
	end

	return hitCount, totalDamage, criticalHits
end

local function ExecuteActionCore(attackerInstance: Instance, request: NormalizedCombatRequest): CombatFeedbackPayload?
	local config = activeActionConfigs[request.ActionId]
	if not config then
		return nil
	end

	local attackerCharacter = ResolveCharacter(attackerInstance)
	local attackerHumanoid = GetHumanoid(attackerCharacter)
	if not attackerCharacter or not attackerHumanoid or attackerHumanoid.Health <= 0 then
		return nil
	end

	local profile = GetOrCreateProfile(attackerInstance)
	if IsActionCoolingDown(profile, request.ActionId) then
		return nil
	end

	local hitCount = 0
	local totalDamage = 0
	local criticalHits = 0

	if request.ActionId == "Punch" then
		hitCount, totalDamage, criticalHits = ExecutePunch(attackerCharacter, config, request.Direction)
	end

	StartCooldown(profile, request.ActionId, config.Cooldown)
	return BuildFeedbackPayload(request.ActionId, hitCount, totalDamage, criticalHits)
end

local function HandleActionRequest(player: Player, payload: CombatActionRequestPayload)
	local request = NormalizeActionRequest(payload)
	if not request then
		return
	end

	local feedback = ExecuteActionCore(player, request)
	if feedback then
		CombatNetwork:ReplicateFeedbackToPlayer(player, feedback)
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function CombatService.ExecuteAction(
	attackerInstance: Instance,
	actionId: CombatActionId,
	direction: Vector3?
): CombatFeedbackPayload?
	local request: NormalizedCombatRequest = {
		ActionId = actionId,
		Direction = direction,
		Meta = nil,
	}

	local feedback = ExecuteActionCore(attackerInstance, request)
	if feedback and attackerInstance:IsA("Player") then
		CombatNetwork:ReplicateFeedbackToPlayer(attackerInstance, feedback)
	end

	return feedback
end

function CombatService:ClearEntity(instance: Instance)
	activeProfiles[instance] = nil
end

function CombatService:Configure(config: CombatServiceInitConfig?)
	activeProfiles = {}

	if config and config.Actions then
		activeActionConfigs = CloneActionConfigs(config.Actions)
	else
		activeActionConfigs = CloneActionConfigs(defaultActionConfigs)
	end

	if config and config.AttributeKeys then
		activeAttributeKeys = {
			Attack = config.AttributeKeys.Attack,
			Defense = config.AttributeKeys.Defense,
			CurrentHealth = config.AttributeKeys.CurrentHealth,
			LastDamage = config.AttributeKeys.LastDamage,
			LastDamageCritical = config.AttributeKeys.LastDamageCritical,
		}
	else
		activeAttributeKeys = defaultAttributeKeys
	end

	activeHitboxTargetResolver = if config then config.HitboxTargetResolver else nil
end

function CombatService:Init(config: CombatServiceInitConfig?)
	if config then
		self:Configure(config)
	end
	if hasInitialized then
		return
	end
	hasInitialized = true

	CombatNetwork:RegisterActionRequestHandler(function(player: Player, payload: CombatActionRequestPayload)
		HandleActionRequest(player, payload)
	end)
	CombatNetwork:Init(if config then config.NetworkConfig else nil)

	Players.PlayerRemoving:Connect(function(player)
		self:ClearEntity(player)
	end)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(CombatService)
