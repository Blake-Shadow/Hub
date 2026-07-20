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
local MovementTypes = require("./MovementTypes")

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
	local remote = self.ActionRequestRemote
	if remote then
		remote:FireServer(payload)
	end
end

function MovementNetwork:ReplicateToPlayer(player: Player, payload: NetworkMovementSnapshot)
	local remote = self.StateReplicatedRemote
	if remote then
		remote:FireClient(player, payload)
	end
end

function MovementNetwork:ReplicateToAll(payloadByPlayer: { [Player]: NetworkMovementSnapshot })
	local remote = self.StateReplicatedRemote
	if remote then
		for player, payload in pairs(payloadByPlayer) do
			remote:FireClient(player, payload)
		end
	end
end

function MovementNetwork:Init()
	if RunService:IsServer() then
		local remote = self.ActionRequestRemote
		if remote then
			remote.OnServerEvent:Connect(function(player: Player, payload: ActionRequestPayload)
				if activeActionRequestHandler then
					activeActionRequestHandler(player, payload)
				end
			end)
		end
	elseif RunService:IsClient() then
		local remote = self.StateReplicatedRemote
		if remote then
			remote.OnClientEvent:Connect(function(payload: NetworkMovementSnapshot)
				if activeReplicationHandler then
					activeReplicationHandler(payload)
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
