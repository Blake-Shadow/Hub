--!strict
--@author: Shadow
--@date:
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
-- PRIVATE FUNCTIONS --
-----------------------------
local function ResolveSyncRemote(): RemoteEvent?
	local networkRemote = ClassNetwork.SyncClassProfileRemote
	if networkRemote then
		return networkRemote
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end

	local remotes = assets:FindFirstChild("Remotes")
	if not remotes then
		return nil
	end

	local classFolder = remotes:FindFirstChild("Class")
	if not classFolder then
		return nil
	end

	local syncRemote = classFolder:FindFirstChild("SyncClassProfile")
	if syncRemote and syncRemote:IsA("RemoteEvent") then
		return syncRemote
	end

	return nil
end

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

	local allocationRemote = ClassNetwork.AllocateNodeRemote
	if allocationRemote then
		allocationRemote:FireServer(nodeName)
	end
end

-- Lifecycle Initializer
function ClassClient.Init()
	local syncRemote = ResolveSyncRemote()
	if not syncRemote then
		warn("[ClassClient] SyncClassProfile remote missing during init.")
		return
	end

	syncRemote.OnClientEvent:Connect(function(newProfile: any)
		localCache = newProfile

		for _, listener in ipairs(changeListeners) do
			task.spawn(listener, newProfile)
		end
	end)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(ClassClient)
