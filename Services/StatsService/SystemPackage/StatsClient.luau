--!strict
--@author: Shadow
--@date: 
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local StatsType = require("./StatsType")
local StatsNetwork = require("./StatsNetwork")

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local StatsClient = {}

local cachedProfile: StatsType.ActorStatsProfile? = nil
local updateListeners: {(profile: StatsType.ActorStatsProfile) -> ()} = {}
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function StatsClient.GetLocalProfile(): StatsType.ActorStatsProfile?
	return cachedProfile
end

function StatsClient.GetStatTotal(statKey: string): number
	if not cachedProfile then return 0 end
	local proprety = cachedProfile.Registry[statKey]
	return proprety and proprety.Total or 0
end

function StatsClient.GetResourcePool(poolKey: string): (number, number)
	if not cachedProfile then return 0, 0 end
	local pool = cachedProfile.ResourcesPool[poolKey]
	if not pool then return 0, 0 end
	
	local maxProprety = cachedProfile.Registry[pool.MaxStatKey]
	local maxVal = maxProprety and maxProprety.Total or pool.Current
	return pool.Current, maxVal
end

function StatsClient.OnProfileUpdated(callback: (profile: StatsType.ActorStatsProfile) -> ())
	table.insert(updateListeners, callback)
	if cachedProfile then
		callback(cachedProfile)
	end
end

function StatsClient.Init()
	StatsNetwork.SyncProfileRemote.OnClientEvent:Connect(function(updatedProfile: StatsType.ActorStatsProfile)
		cachedProfile = updatedProfile
		
		for _, callback in ipairs(updateListeners) do
			task.spawn(callback, cachedProfile :: StatsType.ActorStatsProfile)
		end
	end)
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StatsClient)