--!strict
--@author: Shadow
--@date: 2026/07/07
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local StatsType = require("./StatsType")
local StatsNetwork = require("./StatsNetwork")
local GameMath = require(ReplicatedStorage.Modules.Helpers.GameMath.GameMath)

-----------------------------
-- VARIABLES --
-----------------------------
local StatsService = {}

local LiveProfiles: { [Instance]: StatsType.ActorStatsProfile } = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

--[[
	RECALCULATE TOTAL
	Takes a single stat registry property and updates its final compiled Total
	using the universal flat and percentage calculations.
]]
local function RecalculateTotal(property: StatsType.StatProperty)
	local afterFlat = GameMath.CombineBaseValues(property.Base, property.Modifiers.Flat)
	property.Total = GameMath.ApplyPercentageModifier(afterFlat, property.Modifiers.Percent)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

--[[
	REGISTRY ENTITY
	Initializes a brand-new live session data tracking profile for a character or NPC.
]]
function StatsService:RegistryEntity(
	entity: Instance,
	baseBlueprints: { [string]: number },
	resourceBlueprints: { [string]: string }
)
	local profile: StatsType.ActorStatsProfile = {
		Registry = {},
		ResourcesPool = {},
	}

	for key, value in pairs(baseBlueprints) do
		profile.Registry[key] = {
			Base = value,
			Modifiers = { Flat = 0, Percent = 0 },
			Total = value,
		}
	end

	for poolKey, maxStatKey in pairs(resourceBlueprints) do
		local matchingStat = profile.Registry[maxStatKey]
		profile.ResourcesPool[poolKey] = {
			Current = matchingStat and matchingStat.Total or 100,
			MaxStatKey = maxStatKey,
		}
	end

	LiveProfiles[entity] = profile

	if entity:IsA("Player") then
		StatsNetwork.SyncProfileRemote(entity, profile)
	end
end

--[[
	UPDATE BASE STATS
	Re-evaluates a profile's raw baseline values (e.g., from stat allocation point changes or gear swaps)
	and automatically runs calculations to refresh final totals.
]]
function StatsService:UpdateBaseStats(entity: Instance, updatedBlueprints: { [string]: number })
	local profile = LiveProfiles[entity]
	if not profile then
		return
	end

	-- Map newly calculated base stats straight into the active registry profile
	for key, newValue in pairs(updatedBlueprints) do
		local property = profile.Registry[key]
		if property then
			property.Base = newValue
			RecalculateTotal(property)
		end
	end

	-- Keep current status resource pools capped inside new max ranges safely
	for _, pool in pairs(profile.ResourcesPool) do
		local maxProperty = profile.Registry[pool.MaxStatKey]
		local maxLimit = maxProperty and maxProperty.Total or pool.Current
		pool.Current = math.clamp(pool.Current, 0, maxLimit)
	end

	-- Sync up player UI instances over network
	if entity:IsA("Player") then
		StatsNetwork.SyncProfileRemote(entity, profile)
	end
end

--[[
	GET PROFILE
	Fetches an active live tracking sheet for any given instance.
]]
function StatsService:GetProfile(entity: Instance): StatsType.ActorStatsProfile?
	return LiveProfiles[entity]
end

--[[
	MODIFY RESOURCE
	Changes health, mana, or spores current values safely within limits.
]]
function StatsService:ModifyResource(entity: Instance, poolKey: string, amount: number)
	local profile = LiveProfiles[entity]
	if not profile then
		return
	end

	local pool = profile.ResourcesPool[poolKey]
	if pool then
		local maxProperty = profile.Registry[pool.MaxStatKey]
		local maxLimit = maxProperty and maxProperty.Total or pool.Current

		pool.Current = math.clamp(pool.Current + amount, 0, maxLimit)

		if entity:IsA("Player") then
			StatsNetwork.SyncProfileRemote(entity, profile)
		end
	end
end

--[[
	CLEAR ENTITY
	Wipes memory profiles immediately to eliminate server memory leaks.
]]
function StatsService:ClearEntity(entity: Instance)
	LiveProfiles[entity] = nil
end

--[[
	INITIALIZATION HOOK
]]
function StatsService:Init()
	Players.PlayerRemoving:Connect(function(player)
		self:ClearEntity(player)
	end)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StatsService)
