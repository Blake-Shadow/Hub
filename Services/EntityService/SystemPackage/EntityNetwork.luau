--!strict
--@author: Shadow
--@date: 
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferNetwork = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferNetwork) :: any
local EntityCodecs = require("./Codecs/EntityCodecs")

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local EntityNetwork = {}

EntityNetwork.EntitySyncRemote = nil :: any

local activeSyncHandler: (model: Model, data: {[string]: any}) -> () = nil :: any
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildNetworkDirectory()
	local remotesFolder = ReplicatedStorage.Assets:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage.Assets
	end
	
	local entityFolder = remotesFolder:FindFirstChild("Entity")
	if not entityFolder then
		entityFolder = Instance.new("Folder")
		entityFolder.Name = "Entity"
		entityFolder.Parent = remotesFolder
	end
	
	local EntitySyncRemote = entityFolder:FindFirstChild("EntitySync") :: RemoteEvent
	if not EntitySyncRemote then
		EntitySyncRemote = Instance.new("RemoteEvent")
        if EntitySyncRemote then
            EntitySyncRemote.Name = "EntitySync"
            EntitySyncRemote.Parent = entityFolder
        end
	end
	
	if RunService:IsClient() then
		EntitySyncRemote = entityFolder:WaitForChild("EntitySync") :: RemoteEvent
	end
	return EntitySyncRemote
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
-- FOR THE SERVER: Send data to everyone
function EntityNetwork.SyncEntity(model: Model, data: {[string]: any})
	EntityCodecs.EnsureRegistered()
	BufferNetwork.FireAllClients(EntityNetwork.EntitySyncRemote, EntityCodecs.SyncCodecName, EntityCodecs.BuildSyncPayload(model, data))
end

-- FOR THE CLIENT: Set the function that runs when data is received
function EntityNetwork.SetSyncHandler(handler: (model: Model, data: {[string]: any}) -> ())
	activeSyncHandler = handler
end

function EntityNetwork.Init()
	EntityCodecs.EnsureRegistered()

	if RunService:IsClient() then
		BufferNetwork.BindClientEvent(EntityNetwork.EntitySyncRemote, EntityCodecs.SyncCodecName, function(payload: any)
			local model, data = EntityCodecs.ExtractSyncPayload(payload)
			if not model or not data then
				return
			end

			if activeSyncHandler then
				activeSyncHandler(model, data)
			end
		end)
	end
end
-----------------------------
-- MAIN --
-----------------------------
local entitySync = BuildNetworkDirectory()

EntityNetwork.EntitySyncRemote = entitySync

return table.freeze(EntityNetwork)