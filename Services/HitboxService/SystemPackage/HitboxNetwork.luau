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

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local HitboxNetwork = {}

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

-----------------------------
-- MAIN --
-----------------------------
local visualRemote, inputRemote = BuildNetworkDirectory()

HitboxNetwork.VisualRemote = visualRemote
HitboxNetwork.InputRemote = inputRemote

return table.freeze(HitboxNetwork)