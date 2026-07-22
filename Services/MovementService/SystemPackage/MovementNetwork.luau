--!strict
--@author: Shadow
--@date: 2026/07/18
--[[@description:
	Networking boundary for movement/parkour action requests and replication snapshots.
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
local MovementTypes = require("./MovementTypes")
local MovementCodecs = require("./Codecs/MovementCodecs")

-----------------------------
-- TYPES --
-----------------------------
type ActionRequestPayload = MovementTypes.ActionRequestPayload
type NetworkMovementSnapshot = MovementTypes.NetworkMovementSnapshot

-----------------------------
-- VARIABLES --
-----------------------------
local MovementNetwork = {}

MovementNetwork.ActionRequestRemote = nil :: RemoteEvent?
MovementNetwork.StateReplicatedRemote = nil :: RemoteEvent?

local activeActionRequestHandler: ((player: Player, payload: ActionRequestPayload) -> ())? = nil
local activeReplicationHandler: ((payload: NetworkMovementSnapshot) -> ())? = nil

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildNetworkDirectory(): (RemoteEvent, RemoteEvent)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		assetsFolder = Instance.new("Folder")
		assetsFolder.Name = "Assets"
		assetsFolder.Parent = ReplicatedStorage
	end

	local remotesFolder = assetsFolder:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = assetsFolder
	end

	local movementFolder = remotesFolder:FindFirstChild("Movement")
	if not movementFolder then
		movementFolder = Instance.new("Folder")
		movementFolder.Name = "Movement"
		movementFolder.Parent = remotesFolder
	end

	local actionRemote = movementFolder:FindFirstChild("MovementActionRequest")
	if not actionRemote then
		actionRemote = Instance.new("RemoteEvent")
		actionRemote.Name = "MovementActionRequest"
		actionRemote.Parent = movementFolder
	end

	local replicatedRemote = movementFolder:FindFirstChild("MovementStateReplicated")
	if not replicatedRemote then
		replicatedRemote = Instance.new("RemoteEvent")
		replicatedRemote.Name = "MovementStateReplicated"
		replicatedRemote.Parent = movementFolder
	end

	if RunService:IsClient() then
		actionRemote = movementFolder:WaitForChild("MovementActionRequest")
		replicatedRemote = movementFolder:WaitForChild("MovementStateReplicated")
	end

	local resolvedAction = actionRemote :: RemoteEvent
	local resolvedReplicated = replicatedRemote :: RemoteEvent

	return resolvedAction, resolvedReplicated
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function MovementNetwork:RegisterActionRequestHandler(handler: (player: Player, payload: ActionRequestPayload) -> ())
	activeActionRequestHandler = handler
end

function MovementNetwork:RegisterReplicationHandler(handler: (payload: NetworkMovementSnapshot) -> ())
	activeReplicationHandler = handler
end

function MovementNetwork:RequestAction(payload: ActionRequestPayload)
	MovementCodecs.EnsureRegistered()
	local remote = self.ActionRequestRemote
	if remote then
		BufferNetwork.FireServer(remote, MovementCodecs.ActionRequestCodecName, payload)
	end
end

function MovementNetwork:ReplicateToPlayer(player: Player, payload: NetworkMovementSnapshot)
	MovementCodecs.EnsureRegistered()
	local remote = self.StateReplicatedRemote
	if remote then
		BufferNetwork.FireClient(remote, player, MovementCodecs.ReplicationCodecName, payload)
	end
end

function MovementNetwork:ReplicateToAll(payloadByPlayer: { [Player]: NetworkMovementSnapshot })
	MovementCodecs.EnsureRegistered()
	local remote = self.StateReplicatedRemote
	if remote then
		for player, payload in pairs(payloadByPlayer) do
			BufferNetwork.FireClient(remote, player, MovementCodecs.ReplicationCodecName, payload)
		end
	end
end

function MovementNetwork:Init()
	MovementCodecs.EnsureRegistered()

	if RunService:IsServer() then
		local remote = self.ActionRequestRemote
		if remote then
			BufferNetwork.BindServerEvent(remote, MovementCodecs.ActionRequestCodecName, function(player: Player, payload: any)
				if activeActionRequestHandler then
					activeActionRequestHandler(player, payload :: ActionRequestPayload)
				end
			end)
		end
	elseif RunService:IsClient() then
		local remote = self.StateReplicatedRemote
		if remote then
			BufferNetwork.BindClientEvent(remote, MovementCodecs.ReplicationCodecName, function(payload: any)
				if activeReplicationHandler then
					activeReplicationHandler(payload :: NetworkMovementSnapshot)
				end
			end)
		end
	end
end

-----------------------------
-- MAIN --
-----------------------------
local actionRequestRemote, stateReplicatedRemote = BuildNetworkDirectory()

MovementNetwork.ActionRequestRemote = actionRequestRemote
MovementNetwork.StateReplicatedRemote = stateReplicatedRemote

return table.freeze(MovementNetwork)
