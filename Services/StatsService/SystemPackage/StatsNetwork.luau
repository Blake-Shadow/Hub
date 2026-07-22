--!strict
--@author: Shadow
--@date: 2026/07/02
--[[@description:
    Handles network communication boundaries for player statistics.
    Programmatically sets up its own custom network directories and Remotes.
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
local StatsCodecs = require("./Codecs/StatsCodecs")

-----------------------------
-- VARIABLES --
-----------------------------
local StatsNetwork = {}

StatsNetwork.AllocateStatRemote = nil :: any
StatsNetwork.DamageNumberRemote = nil :: any
StatsNetwork.SyncProfileRemote = nil :: any

local activeAllocationHandler: (player: Player, statName: string) -> () = nil :: any
local activeSyncProfileHandler: ((profile: any) -> ())? = nil
local activeDamageNumberHandler: ((targetCharacter: Model, amount: number, isCritical: boolean) -> ())? = nil
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildNetworkDirectory()
	local remotesFolder = ReplicatedStorage.Assets:WaitForChild("Remotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "Remotes"
		remotesFolder.Parent = ReplicatedStorage.Assets
	end

	local statsFolder = remotesFolder:FindFirstChild("Stats")
	if not statsFolder then
		statsFolder = Instance.new("Folder")
		statsFolder.Name = "Stats"
		statsFolder.Parent = remotesFolder
	end
	
	local AllocateStatRemote = statsFolder:FindFirstChild("AllocateStatRemote") :: RemoteEvent
	if not AllocateStatRemote and RunService:IsServer() then
		AllocateStatRemote = Instance.new("RemoteEvent")
		if AllocateStatRemote then
            AllocateStatRemote.Name = "AllocateStatRemote"
            AllocateStatRemote.Parent = statsFolder
        end
	end
	
	local DamageNumberRemote = statsFolder:FindFirstChild("DamageNumberRemote") :: RemoteEvent
	if not DamageNumberRemote and RunService:IsServer() then
		DamageNumberRemote = Instance.new("RemoteEvent")
		if DamageNumberRemote then
            DamageNumberRemote.Name = "DamageNumberRemote"
            DamageNumberRemote.Parent = statsFolder
        end
	end
	
	local SyncProfileRemote = statsFolder:FindFirstChild("SyncProfileRemote") :: RemoteEvent
	if not SyncProfileRemote and RunService:IsServer() then
		SyncProfileRemote = Instance.new("RemoteEvent")
		if SyncProfileRemote then
            SyncProfileRemote.Name = "SyncProfileRemote"
            SyncProfileRemote.Parent = statsFolder
        end
	end
	
	if RunService:IsClient() then
		AllocateStatRemote = statsFolder:WaitForChild("AllocateStatRemote") :: RemoteEvent
		DamageNumberRemote = statsFolder:WaitForChild("DamageNumberRemote") :: RemoteEvent
		SyncProfileRemote = statsFolder:WaitForChild("SyncProfileRemote") :: RemoteEvent
	end
	return AllocateStatRemote, DamageNumberRemote, SyncProfileRemote
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function StatsNetwork.DisplayDamage(player: Player, targetCharacter: Model, amount: number, isCritical: boolean)
	StatsCodecs.EnsureRegistered()
	BufferNetwork.FireClient(
		StatsNetwork.DamageNumberRemote,
		player,
		StatsCodecs.DamageNumberCodecName,
		StatsCodecs.BuildDamagePayload(targetCharacter, amount, isCritical)
	)
end

function StatsNetwork.SyncProfile(player: Player, profile: any)
	StatsCodecs.EnsureRegistered()
	BufferNetwork.FireClient(
		StatsNetwork.SyncProfileRemote,
		player,
		StatsCodecs.SyncProfileCodecName,
		StatsCodecs.WrapProfile(profile)
	)
end

function StatsNetwork.SetAllocationHandler(handler: (player: Player, statName: string) -> ())
	activeAllocationHandler = handler
end

function StatsNetwork.SetSyncProfileHandler(handler: (profile: any) -> ())
	activeSyncProfileHandler = handler
end

function StatsNetwork.SetDamageNumberHandler(handler: (targetCharacter: Model, amount: number, isCritical: boolean) -> ())
	activeDamageNumberHandler = handler
end

function StatsNetwork.RequestAllocateStat(statName: string)
	StatsCodecs.EnsureRegistered()
	local remote = StatsNetwork.AllocateStatRemote
	if remote then
		BufferNetwork.FireServer(remote, StatsCodecs.AllocateStatCodecName, StatsCodecs.BuildAllocatePayload(statName))
	end
end

function StatsNetwork.Init()
	StatsCodecs.EnsureRegistered()

	if RunService:IsServer() then
		BufferNetwork.BindServerEvent(StatsNetwork.AllocateStatRemote, StatsCodecs.AllocateStatCodecName, function(player: Player, payload: any)
			local statName = StatsCodecs.ExtractAllocatePayload(payload)
			if not statName then
				return
			end

				if not activeAllocationHandler then
					error("[STATS NETWORK CRITICAL] Allocation request received, but no configuration handler was bound!")
				end
				activeAllocationHandler(player, statName)
		end)
	elseif RunService:IsClient() then
		BufferNetwork.BindClientEvent(StatsNetwork.SyncProfileRemote, StatsCodecs.SyncProfileCodecName, function(payload: any)
			if activeSyncProfileHandler then
				activeSyncProfileHandler(StatsCodecs.UnwrapProfile(payload))
			end
		end)

		BufferNetwork.BindClientEvent(StatsNetwork.DamageNumberRemote, StatsCodecs.DamageNumberCodecName, function(payload: any)
			if activeDamageNumberHandler then
				local targetCharacter, amount, isCritical = StatsCodecs.ExtractDamagePayload(payload)
				if targetCharacter and amount and isCritical ~= nil then
					activeDamageNumberHandler(targetCharacter, amount, isCritical)
				end
			end
		end)
	end
end
-----------------------------
-- MAIN --
-----------------------------
local allocateStat, damageNumber, syncProfile = BuildNetworkDirectory()

StatsNetwork.AllocateStatRemote = allocateStat
StatsNetwork.DamageNumberRemote = damageNumber
StatsNetwork.SyncProfileRemote = syncProfile

return table.freeze(StatsNetwork)