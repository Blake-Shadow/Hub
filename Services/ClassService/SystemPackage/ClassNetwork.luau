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
local ClassCodecs = require("./Codecs/ClassCodecs")

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local ClassNetwork = {}

ClassNetwork.AllocateNodeRemote = nil :: any
ClassNetwork.SyncClassProfileRemote = nil :: any

local activeAllocationHandler: (player: Player, nodeName: string) -> () = nil :: any
local activeSyncHandler: (profile: any) -> () = nil :: any
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

	local classFolder = remotesFolder:FindFirstChild("Class")
	if not classFolder then
		classFolder = Instance.new("Folder")
		classFolder.Name = "Class"
		classFolder.Parent = remotesFolder
	end

	local AllocateNodeRemote = classFolder:FindFirstChild("AllocateNode") :: RemoteEvent
	if not AllocateNodeRemote then
		AllocateNodeRemote = Instance.new("RemoteEvent")
		if AllocateNodeRemote then
			AllocateNodeRemote.Name = "AllocateNode"
			AllocateNodeRemote.Parent = classFolder
		end
	end

	local SyncClassProfileRemote = classFolder:FindFirstChild("SyncClassProfile") :: RemoteEvent
	if not SyncClassProfileRemote then
		SyncClassProfileRemote = Instance.new("RemoteEvent")
		if SyncClassProfileRemote then
			SyncClassProfileRemote.Name = "SyncClassProfile"
			SyncClassProfileRemote.Parent = classFolder
		end
	end

	if RunService:IsClient() then
		AllocateNodeRemote = classFolder:WaitForChild("AllocateNode") :: RemoteEvent
		SyncClassProfileRemote = classFolder:WaitForChild("SyncClassProfile") :: RemoteEvent
	end
	return AllocateNodeRemote, SyncClassProfileRemote
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function ClassNetwork.SyncClassProfile(player: Player, classProfileData: any)
	ClassCodecs.EnsureRegistered()
	if not ClassNetwork.SyncClassProfileRemote then
		return
	end
	BufferNetwork.FireClient(
		ClassNetwork.SyncClassProfileRemote,
		player,
		ClassCodecs.SyncProfileCodecName,
		ClassCodecs.WrapSyncProfilePayload(classProfileData)
	)
end

function ClassNetwork.SetAllocationHandler(handler: (player: Player, nodeName: string) -> ())
	activeAllocationHandler = handler
end

function ClassNetwork.SetSyncHandler(handler: (profile: any) -> ())
	activeSyncHandler = handler
end

function ClassNetwork.RequestAllocateNode(nodeName: string)
	ClassCodecs.EnsureRegistered()
	local remote = ClassNetwork.AllocateNodeRemote
	if remote then
		BufferNetwork.FireServer(remote, ClassCodecs.AllocateNodeCodecName, ClassCodecs.BuildAllocateNodePayload(nodeName))
	end
end

function ClassNetwork.Init()
	ClassCodecs.EnsureRegistered()

	if RunService:IsServer() then
		if not ClassNetwork.AllocateNodeRemote or not ClassNetwork.AllocateNodeRemote.OnServerEvent then
			warn("[ClassNetwork] Allocation remote not ready yet.")
			return
		end

		BufferNetwork.BindServerEvent(ClassNetwork.AllocateNodeRemote, ClassCodecs.AllocateNodeCodecName, function(player: Player, payload: any)
			if not activeAllocationHandler then
				warn(
					"[CLASS NETWORK CRITICAL] Talent point allocation request received, but no configuration handler was bound!"
				)
				return
			end

			local nodeName = ClassCodecs.ExtractAllocateNodePayload(payload)
			if not nodeName then
				return
			end
			activeAllocationHandler(player, nodeName)
		end)
	elseif RunService:IsClient() then
		if ClassNetwork.SyncClassProfileRemote then
			BufferNetwork.BindClientEvent(ClassNetwork.SyncClassProfileRemote, ClassCodecs.SyncProfileCodecName, function(payload: any)
				if activeSyncHandler then
					activeSyncHandler(ClassCodecs.ExtractSyncProfilePayload(payload))
				end
			end)
		end
	end
end
-----------------------------
-- MAIN --
-----------------------------
local allocateNode, syncClassProfile = BuildNetworkDirectory()

ClassNetwork.AllocateNodeRemote = allocateNode
ClassNetwork.SyncClassProfileRemote = syncClassProfile

return table.freeze(ClassNetwork)
