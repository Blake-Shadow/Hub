--!strict
--@author: Shadow
--@date:
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")
-----------------------------
-- DEPENDENCIES --
-----------------------------
local StateNetwork = require("./StateNetwork") :: any
local StateTypes = require("./StateTypes")
-----------------------------
-- TYPES --
-----------------------------
type PlayerStateProfile = StateTypes.PlayerStateProfile
type StateConfig = StateTypes.StateConfig
type MasterConfig = StateTypes.MasterConfig
type NetworkStatePayload = StateTypes.NetworkStatePayload
type ActiveStateInstance = StateTypes.ActiveStateInstance
-----------------------------
-- VARIABLES --
-----------------------------
local StateService = {}

local activeProfiles: { [Instance]: PlayerStateProfile? } = {}
local masterConfig: MasterConfig? = nil

-- Hook for EntityHandler to receive updated math calculations
local activeStatUpdateHandler: ((instance: Instance, computedStats: { [string]: number }) -> ())? = nil
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-- Helper: Computes raw stat values based on base stats and active modifiers
local function RecalculateEntityStats(instance: Instance)
	local profile = activeProfiles[instance]
	if not profile then
		return
	end

	-- Establish baseline tracking tables
	local computedStats: { [string]: number } = {}
	local flatSums: { [string]: number } = {}
	local multProducts: { [string]: number } = {}

	for statName, _ in pairs(profile.BaseStats) do
		flatSums[statName] = 0
		multProducts[statName] = 1
	end

	-- Accumulate modifier calculations from all active state instances
	for stateName, instances in pairs(profile.ActiveStates) do
		if #instances == 0 then
			continue
		end

		if not masterConfig then
			continue
		end
		local stateSetting = masterConfig and masterConfig.States[stateName]
		if not stateSetting or not stateSetting.Modifiers then
			continue
		end

		for statName, modifierInstruction in pairs(stateSetting.Modifiers) do
			if profile.BaseStats[statName] == nil then
				continue
			end -- Safety check

			if modifierInstruction.Add then
				flatSums[statName] += modifierInstruction.Add
			end
			if modifierInstruction.Multiply then
				multProducts[statName] *= modifierInstruction.Multiply
			end
		end
	end

	-- Resolve final mathematical values: (Base + Additions) * Multipliers
	for statName, baseValue in pairs(profile.BaseStats) do
		computedStats[statName] = (baseValue + flatSums[statName]) * multProducts[statName]
	end

	-- Pipe the final calculations straight to your EntityHandler
	if activeStatUpdateHandler then
		activeStatUpdateHandler(instance, computedStats)
	end
end

-- Helper: Compresses active states and replicates them to the client
local function ReplicateProfile(instance: Instance)
	if not instance:IsA("Player") then
		return
	end

	local profile = activeProfiles[instance]
	if not profile then
		return
	end

	local payload: NetworkStatePayload = {}

	for stateName, instances in profile.ActiveStates do
		payload[stateName] = {
			Active = #instances > 0,
			StackCount = #instances,
		}
	end

	StateNetwork.ReplicateToPlayer(instance, payload)
end

-- Private Handler: Checks action restrictions before allowing client executions
local function HandleActionRequest(player: Player, actionName: string, _data: any)
	local profile = activeProfiles[player]
	if not profile then
		return
	end

	local disableCount = profile.ActiveDisables[actionName] or 0
	if disableCount > 0 then
		return -- Rejected silently (anti-cheat safeguard)
	end
	-- Custom action validation can continue safely here or be piped externally
end

-- Lifecycle: Player Joined
local function RegisterEntity(instance: Instance)
	local defaultProfile: PlayerStateProfile = {
		ActiveStates = {},
		ActiveDisables = {},
		BaseStats = {}, -- Left empty: external modules (like EntityHandler) define these
	}
	activeProfiles[instance] = defaultProfile
end

-- Lifecycle: Player Left
local function OnPlayerRemoving(player: Player)
	activeProfiles[player] = nil
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
--[[ Inject the master state configs dynamically ]]
function StateService:SetConfig(config: MasterConfig)
	masterConfig = config
end

--[[ Hooks up your EntityHandler to receive computed stat tables ]]
function StateService:RegisterStatUpdateHandler(
	handler: (instance: Instance, computedStats: { [string]: number }) -> ()
)
	activeStatUpdateHandler = handler
end

function StateService:RegisterEntity(instance: Instance)
	if activeProfiles[instance] then
		return
	end

	RegisterEntity(instance)
end

function StateService:UnregisterEntity(instance: Instance)
	activeProfiles[instance] = nil
end

--[[ Allows EntityHandler to register or change a player's baseline stats dynamically ]]
function StateService:SetBaseStat(instance: Instance, statName: string, value: number)
	local profile = activeProfiles[instance]
	if not profile then
		return
	end

	profile.BaseStats[statName] = value
	RecalculateEntityStats(instance)
end

--[[ Apply a state to a player from a specific reference source ]]
function StateService:AddState(instance: Instance, stateName: string, source: string, duration: number?)
	local profile = activeProfiles[instance]
	if not profile or not masterConfig then
		return
	end

	local config = masterConfig.States[stateName]
	if not config then
		warn(`[StateService] State '{stateName}' is not registered in MasterConfig!`)
		return
	end

	-- Enforce stack protection rules
	if not config.Stackable and profile.ActiveStates[stateName] and #profile.ActiveStates[stateName] > 0 then
		return
	end

	if not profile.ActiveStates[stateName] then
		profile.ActiveStates[stateName] = {}
	end

	local stateInstance: ActiveStateInstance = {
		Source = source,
		StartTime = os.clock(),
		Duration = duration,
	}

	table.insert(profile.ActiveStates[stateName], stateInstance)

	-- Increment action restriction reference counters
	if config.Disables then
		for _, action in ipairs(config.Disables) do
			profile.ActiveDisables[action] = (profile.ActiveDisables[action] or 0) + 1
		end
	end

	-- Handle self-terminating timers safely
	if duration and duration > 0 then
		task.delay(duration, function()
			self:RemoveState(instance, stateName, source)
		end)
	end

	RecalculateEntityStats(instance)
	ReplicateProfile(instance)
end

--[[ Remove a state from a player using its reference source ID ]]
function StateService:RemoveState(instance: Instance, stateName: string, source: string)
	local profile = activeProfiles[instance]
	if not profile or not masterConfig then
		return
	end

	local instances = profile.ActiveStates[stateName]
	if not instances then
		return
	end

	local config = masterConfig.States[stateName]

	for i = #instances, 1, -1 do
		if instances[i].Source == source then
			table.remove(instances, i)

			-- Decrement action restriction counters safely
			if config and config.Disables then
				for _, action in ipairs(config.Disables) do
					if profile.ActiveDisables[action] then
						profile.ActiveDisables[action] = math.max(0, profile.ActiveDisables[action] - 1)
					end
				end
			end
			break
		end
	end

	RecalculateEntityStats(instance)
	ReplicateProfile(instance)
end

--[[ Fetch raw state memory profile of a player ]]
function StateService:GetPlayerProfile(player: Player): PlayerStateProfile?
	return activeProfiles[player]
end

function StateService:GetEntityProfile(instance: Instance): PlayerStateProfile?
	return activeProfiles[instance]
end

--[[ Centralized lifecycle initialization ]]
function StateService:Init()
	StateNetwork:RegisterActionRequestHandler(function(player, actionName, data)
		HandleActionRequest(player, actionName, data)
	end)

	Players.PlayerAdded:Connect(function(player)
		self:RegisterEntity(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:UnregisterEntity(player)
		OnPlayerRemoving(player)
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
return table.freeze(StateService)
