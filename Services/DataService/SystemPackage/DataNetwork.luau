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
local DataCodecs = require("./Codecs/DataCodecs")

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
local activeUpdateHandler: (dataPayload: any) -> () = nil :: any
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
	DataCodecs.EnsureRegistered()
	BufferNetwork.FireClient(
		DataNetwork.DataUpdateRemote,
		player,
		DataCodecs.DataUpdateCodecName,
		DataCodecs.WrapData(dataPayload)
	)
end

function DataNetwork.SetRequestHandler(handler: (player: Player) -> any)
	activeRequestHandler = handler
end

function DataNetwork.SetUpdateHandler(handler: (dataPayload: any) -> ())
	activeUpdateHandler = handler
end

function DataNetwork.RequestData(): any
	DataCodecs.EnsureRegistered()
	local ok, responsePayload = BufferNetwork.InvokeServer(
		DataNetwork.DataRequestRemote,
		DataCodecs.DataRequestCodecName,
		DataCodecs.DataResponseCodecName,
		DataCodecs.BuildRequestPayload()
	)

	if not ok then
		return nil
	end

	return DataCodecs.UnwrapData(responsePayload)
end

function DataNetwork.Init()
	DataCodecs.EnsureRegistered()

	if RunService:IsServer() then
		BufferNetwork.BindServerInvoke(
			DataNetwork.DataRequestRemote,
			DataCodecs.DataRequestCodecName,
			DataCodecs.DataResponseCodecName,
			function(player: Player, _requestPayload: any)
			if not activeRequestHandler then
				error("[DATA NETWORK CRITICAL] Data retrieval request received, but no configuration handler was bound!")
			end

			local response = activeRequestHandler(player)
			return DataCodecs.WrapData(response)
		end,
			DataCodecs.WrapData(nil)
		)
	elseif RunService:IsClient() then
		BufferNetwork.BindClientEvent(DataNetwork.DataUpdateRemote, DataCodecs.DataUpdateCodecName, function(payload: any)
			local dataPayload = DataCodecs.UnwrapData(payload)
			if activeUpdateHandler then
				activeUpdateHandler(dataPayload)
			end
		end)
	end
end
-----------------------------
-- MAIN --
-----------------------------
local updateData, requestData = BuildNetworkDirectory()

DataNetwork.DataUpdateRemote = updateData
DataNetwork.DataRequestRemote = requestData

return table.freeze(DataNetwork)