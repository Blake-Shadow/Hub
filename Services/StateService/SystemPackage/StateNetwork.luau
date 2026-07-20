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
local StateTypes = require("./StateTypes")
-----------------------------
-- TYPES --
-----------------------------
type NetworkStatePayload = StateTypes.NetworkStatePayload
-----------------------------
-- VARIABLES --
-----------------------------
local StateNetwork = {}

StateNetwork.StateReplicated = nil :: RemoteEvent?
StateNetwork.StateActionRequest = nil :: RemoteEvent?

local activeReplicationHandler: ((payload: NetworkStatePayload) -> ())? = nil
local activeActionRequestHandler: ((player: Player, actionName: string, data: any) -> ())? = nil
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildNetworkDirectory()
	local remotesFolder = ReplicatedStorage.Assets:FindFirstChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage
	end
	assert(remotesFolder, "[StateNetwork] Failed to resolve or create 'Assets.Remotes' folder.")
	
	local stateFolder = remotesFolder:FindFirstChild("State") :: Folder
	if not stateFolder then
		stateFolder = Instance.new("Folder") :: Folder
        if stateFolder then
            stateFolder.Name = "State"
            stateFolder.Parent = remotesFolder
        end
	end
	assert(stateFolder, "[StateNetwork] Failed to resolve or create 'Remotes.State' folder.")
	
	local StateReplicated = stateFolder:FindFirstChild("StateReplicated") :: RemoteEvent
	if not StateReplicated then
		StateReplicated = Instance.new("RemoteEvent") :: RemoteEvent
        if StateReplicated then
            StateReplicated.Name = "StateReplicated"
            StateReplicated.Parent = stateFolder
        end
	end
	
	local StateActionRequest = stateFolder:FindFirstChild("StateActionRequest") :: RemoteEvent
	if not StateActionRequest then
		StateActionRequest = Instance.new("RemoteEvent") :: RemoteEvent
        if StateActionRequest then
            StateActionRequest.Name = "StateActionRequest"
            StateActionRequest.Parent = stateFolder
        end
	end
	
	if RunService:IsClient() then
		StateReplicated = stateFolder:WaitForChild("StateReplicated") :: RemoteEvent
		StateActionRequest = stateFolder:WaitForChild("StateActionRequest") :: RemoteEvent
	end
	
	assert(StateReplicated, "[StateNetwork] Failed to resolve RemoteEvent 'StateReplicated'!")
	assert(StateActionRequest, "[StateNetwork] Failed to resolve RemoteEvent 'StateActionRequest'!")
	
	return StateReplicated, StateActionRequest
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
--[[ [SERVER] Replicate active states and stack counts to a specific player ]]
function StateNetwork:ReplicateToPlayer(player: Player, payload: NetworkStatePayload)
	local remote = self.StateReplicated
	if remote then
		remote:FireClient(player, payload)
	end
end

--[[ [SERVER] Batch replicate state data to all active players ]]
function StateNetwork:ReplicateToAll(payloads: { [Player]: NetworkStatePayload })
	local remote = self.StateReplicated
	if remote then
		for player, payload in pairs(payloads) do
			remote:FireClient(player, payload)
		end
	end
end

--[[ [CLIENT] Safely dispatch an action request to the server with optional payloads ]]
function StateNetwork:RequestAction(actionName: string, data: any)
	local remote = self.StateActionRequest
	if remote then
		remote:FireServer(actionName, data)
	end
end

--[[ Centralized registration hook to bind your Server-side state processor ]]
function StateNetwork:RegisterActionRequestHandler(handler: (player: Player, actionName: string, data: any) -> ())
	activeActionRequestHandler = handler
end

--[[ Centralized registration hook to bind your Client-side state manager ]]
function StateNetwork:RegisterReplicationHandler(handler: (payload: NetworkStatePayload) -> ())
	activeReplicationHandler = handler
end

--[[ Centralized Lifecycle Init matching Shadow's architecture ]]
function StateNetwork:Init()
	if RunService:IsClient() then
		local remote = self.StateReplicated
		if remote then
			remote.OnClientEvent:Connect(function(payload: NetworkStatePayload)
				if activeReplicationHandler then
					activeReplicationHandler(payload)
				end
			end)
		end
	elseif RunService:IsServer() then
		local remote = self.StateActionRequest
		if remote then
			remote.OnServerEvent:Connect(function(player: Player, actionName: string, data: any)
				if activeActionRequestHandler then
					activeActionRequestHandler(player, actionName, data)
				end
			end)
		end
	end
end
-----------------------------
-- MAIN --
-----------------------------
local stateReplicated, stateActionRequest = BuildNetworkDirectory()

StateNetwork.StateReplicated = stateReplicated
StateNetwork.StateActionRequest = stateActionRequest

return table.freeze(StateNetwork)