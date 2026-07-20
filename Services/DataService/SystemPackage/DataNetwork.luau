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

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local DataNetwork = {}

DataNetwork.DataUpdateRemote = nil :: any
DataNetwork.DataRequestRemote = nil :: any

local activeRequestHandler: (player: Player) -> any = nil :: any
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
	
	local dataFolder = remotesFolder:FindFirstChild("Data")
	if not dataFolder then
		dataFolder = Instance.new("Folder")
		dataFolder.Name = "Data"
		dataFolder.Parent = remotesFolder
	end
	
	local updateDataRemote = dataFolder:FindFirstChild("UpdateData") :: RemoteEvent
	if not updateDataRemote then
		updateDataRemote = Instance.new("RemoteEvent")
		if updateDataRemote then
            updateDataRemote.Name = "UpdateData"
	        updateDataRemote.Parent = dataFolder
        end
	end
	
	local requestDataRemote = dataFolder:FindFirstChild("RequestData") :: RemoteFunction
	if not requestDataRemote then
		requestDataRemote = Instance.new("RemoteFunction")
        if requestDataRemote then
            requestDataRemote.Name = "RequestData"
	        requestDataRemote.Parent = dataFolder
        end
	end
	
	if RunService:IsClient() then
		updateDataRemote = dataFolder:WaitForChild("UpdateData") :: RemoteEvent
		requestDataRemote = dataFolder:WaitForChild("RequestData") :: RemoteFunction
	end
	return updateDataRemote, requestDataRemote
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function DataNetwork.UpdateClientData(player: Player, dataPayload: any)
	DataNetwork.DataUpdateRemote:FireClient(player, dataPayload)
end

function DataNetwork.SetRequestHandler(handler: (player: Player) -> any)
	activeRequestHandler = handler
end

function DataNetwork.Init()
	if RunService:IsServer() then
		DataNetwork.DataRequestRemote.OnServerInvoke = function(player: Player)
			if not activeRequestHandler then
				error("[DATA NETWORK CRITICAL] Data retrieval request received, but no configuration handler was bound!")
			end
			return activeRequestHandler(player)
		end
	end
end
-----------------------------
-- MAIN --
-----------------------------
local updateData, requestData = BuildNetworkDirectory()

DataNetwork.DataUpdateRemote = updateData
DataNetwork.DataRequestRemote = requestData

return table.freeze(DataNetwork)