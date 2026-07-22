--!strict
--@author: Shadow
--@date:
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------
-- DEPENDENCIES --
-----------------------------
local ClassNetwork = require("./ClassNetwork") :: any

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local ClassClient = {}

local localCache: any = nil
local changeListeners: { (newProfile: any) -> () } = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
-- Returns last replicated class profile snapshot.
function ClassClient.GetProfile(): any
	return localCache
end

-- Safely resolves deep nested values by dotted path.
function ClassClient.GetPath(path: string): any
	local profile = localCache
	if type(profile) ~= "table" then
		return nil
	end

	for segment in string.gmatch(path, "([^%.]+)") do
		profile = profile[segment]
		if profile == nil then
			return nil
		end
	end

	return profile
end

function ClassClient.OnChanged(listener: (newProfile: any) -> ())
	table.insert(changeListeners, listener)
end

function ClassClient.AllocateNode(nodeName: string)
	if type(nodeName) ~= "string" or nodeName == "" then
		return
	end
	ClassNetwork.RequestAllocateNode(nodeName)
end

-- Lifecycle Initializer
function ClassClient.Init()
	ClassNetwork.SetSyncHandler(function(newProfile: any)
		localCache = newProfile

		for _, listener in ipairs(changeListeners) do
			task.spawn(listener, newProfile)
		end
	end)

	ClassNetwork.Init()
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(ClassClient)
