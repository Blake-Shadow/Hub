--!strict
--@author: Shadow
--@date: 2026/07/01
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
local HitboxCodecs = require("./Codecs/HitboxCodecs")

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local HitboxNetwork = {}

local activeVisualHandler: ((payload: any) -> ())? = nil

-- CONSTANTS --

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

	local HitboxFolder = remotesFolder:FindFirstChild("Hitbox")
	if not HitboxFolder then
		HitboxFolder = Instance.new("Folder")
		HitboxFolder.Name = "Hitbox"
		HitboxFolder.Parent = remotesFolder
	end

	local HitboxVisualRemote = HitboxFolder:FindFirstChild("HitboxVisualRemote") :: RemoteEvent
	if not HitboxVisualRemote and RunService:IsServer() then
		HitboxVisualRemote = Instance.new("RemoteEvent")
		if HitboxVisualRemote then
            HitboxVisualRemote.Name = "HitboxVisualRemote"
            HitboxVisualRemote.Parent = HitboxFolder
        end
	end
	
	local HitboxInputRemote = HitboxFolder:FindFirstChild("HitboxInputRemote") :: RemoteEvent
	if not HitboxInputRemote and RunService:IsServer() then
		HitboxInputRemote = Instance.new("RemoteEvent")
		if HitboxInputRemote then
            HitboxInputRemote.Name = "HitboxInputRemote"
            HitboxInputRemote.Parent = HitboxFolder
        end
	end
	
	if RunService:IsClient() then
		HitboxVisualRemote = HitboxFolder:WaitForChild("HitboxVisualRemote") :: RemoteEvent
		HitboxInputRemote = HitboxFolder:WaitForChild("HitboxInputRemote") :: RemoteEvent
	end

	return HitboxVisualRemote, HitboxInputRemote
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function HitboxNetwork.BroadcastShapeVisual(shapeType: string, targetCFrame: CFrame, size: Vector3, radius: number)
	HitboxCodecs.EnsureRegistered()
	if HitboxNetwork.VisualRemote then
		BufferNetwork.FireAllClients(
			HitboxNetwork.VisualRemote,
			HitboxCodecs.VisualCodecName,
			HitboxCodecs.BuildShapePayload(shapeType, targetCFrame, size, radius)
		)
	end
end

function HitboxNetwork.BroadcastImpactVisual(victimModel: Model)
	HitboxCodecs.EnsureRegistered()
	if HitboxNetwork.VisualRemote then
		BufferNetwork.FireAllClients(
			HitboxNetwork.VisualRemote,
			HitboxCodecs.VisualCodecName,
			HitboxCodecs.BuildImpactPayload(victimModel)
		)
	end
end

function HitboxNetwork.SetVisualHandler(handler: (payload: any) -> ())
	activeVisualHandler = handler
end

function HitboxNetwork.Init()
	HitboxCodecs.EnsureRegistered()

	if RunService:IsClient() and HitboxNetwork.VisualRemote then
		BufferNetwork.BindClientEvent(HitboxNetwork.VisualRemote, HitboxCodecs.VisualCodecName, function(payload: any)
			if activeVisualHandler then
				activeVisualHandler(payload)
			end
		end)
	end
end

-----------------------------
-- MAIN --
-----------------------------
local visualRemote, inputRemote = BuildNetworkDirectory()

HitboxNetwork.VisualRemote = visualRemote
HitboxNetwork.InputRemote = inputRemote

return table.freeze(HitboxNetwork)