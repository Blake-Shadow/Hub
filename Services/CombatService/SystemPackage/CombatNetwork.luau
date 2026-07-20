--!strict
--@author: Shadow
--@date: 2026-07-19
--[[@description:
	Networking boundary for combat action requests and combat feedback replication.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local CombatTypes = require("./CombatTypes")

-----------------------------
-- TYPES --
-----------------------------
type CombatActionRequestPayload = CombatTypes.CombatActionRequestPayload
type CombatFeedbackPayload = CombatTypes.CombatFeedbackPayload
type CombatNetworkConfig = CombatTypes.CombatNetworkConfig

-----------------------------
-- VARIABLES --
-----------------------------
local CombatNetwork = {}

local activeActionRequestHandler: ((player: Player, payload: CombatActionRequestPayload) -> ())? = nil
local activeFeedbackHandler: ((payload: CombatFeedbackPayload) -> ())? = nil
local actionRequestRemote: RemoteEvent? = nil
local feedbackRemote: RemoteEvent? = nil

local defaultConfig: CombatNetworkConfig = {
	AssetsFolderName = "Assets",
	RemotesFolderName = "Remotes",
	CombatFolderName = "Combat",
	ActionRequestRemoteName = "CombatActionRequest",
	FeedbackRemoteName = "CombatFeedback",
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function ResolveConfig(config: CombatNetworkConfig?): CombatNetworkConfig
	if not config then
		return defaultConfig
	end

	return {
		AssetsFolderName = config.AssetsFolderName or defaultConfig.AssetsFolderName,
		RemotesFolderName = config.RemotesFolderName or defaultConfig.RemotesFolderName,
		CombatFolderName = config.CombatFolderName or defaultConfig.CombatFolderName,
		ActionRequestRemoteName = config.ActionRequestRemoteName or defaultConfig.ActionRequestRemoteName,
		FeedbackRemoteName = config.FeedbackRemoteName or defaultConfig.FeedbackRemoteName,
	}
end

local function BuildNetworkDirectory(config: CombatNetworkConfig?): (RemoteEvent, RemoteEvent)
	local resolvedConfig = ResolveConfig(config)

	local assetsFolder = ReplicatedStorage:FindFirstChild(resolvedConfig.AssetsFolderName :: string)
	if not assetsFolder then
		assetsFolder = Instance.new("Folder")
		assetsFolder.Name = resolvedConfig.AssetsFolderName :: string
		assetsFolder.Parent = ReplicatedStorage
	end

	local remotesFolder = assetsFolder:FindFirstChild(resolvedConfig.RemotesFolderName :: string)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = resolvedConfig.RemotesFolderName :: string
		remotesFolder.Parent = assetsFolder
	end

	local combatFolder = remotesFolder:FindFirstChild(resolvedConfig.CombatFolderName :: string)
	if not combatFolder then
		combatFolder = Instance.new("Folder")
		combatFolder.Name = resolvedConfig.CombatFolderName :: string
		combatFolder.Parent = remotesFolder
	end

	local builtActionRequestRemote = combatFolder:FindFirstChild(resolvedConfig.ActionRequestRemoteName :: string)
	if not builtActionRequestRemote then
		builtActionRequestRemote = Instance.new("RemoteEvent")
		builtActionRequestRemote.Name = resolvedConfig.ActionRequestRemoteName :: string
		builtActionRequestRemote.Parent = combatFolder
	end

	local builtFeedbackRemote = combatFolder:FindFirstChild(resolvedConfig.FeedbackRemoteName :: string)
	if not builtFeedbackRemote then
		builtFeedbackRemote = Instance.new("RemoteEvent")
		builtFeedbackRemote.Name = resolvedConfig.FeedbackRemoteName :: string
		builtFeedbackRemote.Parent = combatFolder
	end

	if RunService:IsClient() then
		builtActionRequestRemote = combatFolder:WaitForChild(resolvedConfig.ActionRequestRemoteName :: string)
		builtFeedbackRemote = combatFolder:WaitForChild(resolvedConfig.FeedbackRemoteName :: string)
	end

	return builtActionRequestRemote :: RemoteEvent, builtFeedbackRemote :: RemoteEvent
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function CombatNetwork:RegisterActionRequestHandler(
	handler: (player: Player, payload: CombatActionRequestPayload) -> ()
)
	activeActionRequestHandler = handler
end

function CombatNetwork:RegisterFeedbackHandler(handler: (payload: CombatFeedbackPayload) -> ())
	activeFeedbackHandler = handler
end

function CombatNetwork:RequestAction(payload: CombatActionRequestPayload)
	local remote = actionRequestRemote
	if remote then
		remote:FireServer(payload)
	end
end

function CombatNetwork:RequestPunch(direction: Vector3?)
	self:RequestAction({
		ActionId = "Punch",
		Direction = direction,
		Meta = nil,
	})
end

function CombatNetwork:ReplicateFeedbackToPlayer(player: Player, payload: CombatFeedbackPayload)
	local remote = feedbackRemote
	if remote then
		remote:FireClient(player, payload)
	end
end

function CombatNetwork:Init(config: CombatNetworkConfig?)
	actionRequestRemote, feedbackRemote = BuildNetworkDirectory(config)

	if RunService:IsServer() then
		local remote = actionRequestRemote
		if remote then
			remote.OnServerEvent:Connect(function(player: Player, payload: CombatActionRequestPayload)
				if activeActionRequestHandler then
					activeActionRequestHandler(player, payload)
				end
			end)
		end
	elseif RunService:IsClient() then
		local remote = feedbackRemote
		if remote then
			remote.OnClientEvent:Connect(function(payload: CombatFeedbackPayload)
				if activeFeedbackHandler then
					activeFeedbackHandler(payload)
				end
			end)
		end
	end
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(CombatNetwork)
