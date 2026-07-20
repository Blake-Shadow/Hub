--!strict
--@author: Shadow
--@date: 2026/07/18
--[[@description:
	Client-side movement input dispatcher and replication cache.
]]
-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local MovementTypes = require("./MovementTypes")
local MovementNetwork = require("./MovementNetwork") :: any

-----------------------------
-- TYPES --
-----------------------------
type MovementAction = MovementTypes.MovementAction
type ActionRequestPayload = MovementTypes.ActionRequestPayload
type NetworkMovementSnapshot = MovementTypes.NetworkMovementSnapshot
type MovementKeybinds = {
	RunToggle: Enum.KeyCode,
	Dodge: Enum.KeyCode,
	Vault: Enum.KeyCode,
	WallRun: Enum.KeyCode,
	Climb: Enum.KeyCode,
	Slide: Enum.KeyCode,
}
type PartialMovementKeybinds = {
	RunToggle: Enum.KeyCode?,
	Dodge: Enum.KeyCode?,
	Vault: Enum.KeyCode?,
	WallRun: Enum.KeyCode?,
	Climb: Enum.KeyCode?,
	Slide: Enum.KeyCode?,
}

-----------------------------
-- VARIABLES --
-----------------------------
local MovementClient = {}

local localPlayer = Players.LocalPlayer
local cachedSnapshot: NetworkMovementSnapshot? = nil
local updateListeners: { (snapshot: NetworkMovementSnapshot) -> () } = {}
local keybinds: MovementKeybinds = {
	RunToggle = Enum.KeyCode.LeftShift,
	Dodge = Enum.KeyCode.Q,
	Vault = Enum.KeyCode.E,
	WallRun = Enum.KeyCode.R,
	Climb = Enum.KeyCode.F,
	Slide = Enum.KeyCode.C,
}

local isInitialized = false

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function GetMoveDirection(): Vector3
	local character = localPlayer.Character
	if not character then
		return Vector3.new(0, 0, -1)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return Vector3.new(0, 0, -1)
	end

	local direction = humanoid.MoveDirection
	if direction.Magnitude <= 0.001 then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			return rootPart.CFrame.LookVector.Unit
		end
		return Vector3.new(0, 0, -1)
	end

	return direction.Unit
end

local function DispatchAction(action: MovementAction, direction: Vector3?, meta: { [string]: any }?)
	local payload: ActionRequestPayload = {
		Action = action,
		Direction = direction,
		Meta = meta,
	}
	MovementNetwork:RequestAction(payload)
end

local function NotifySnapshotUpdated(snapshot: NetworkMovementSnapshot)
	cachedSnapshot = snapshot
	for _, listener in ipairs(updateListeners) do
		task.spawn(listener, snapshot)
	end
end

local function ResolveBoundAction(keyCode: Enum.KeyCode): MovementAction?
	if keybinds.RunToggle == keyCode then
		return "RunToggle"
	end
	if keybinds.Dodge == keyCode then
		return "Dodge"
	end
	if keybinds.Vault == keyCode then
		return "Vault"
	end
	if keybinds.WallRun == keyCode then
		return "WallRun"
	end
	if keybinds.Climb == keyCode then
		return "Climb"
	end
	if keybinds.Slide == keyCode then
		return "Slide"
	end

	return nil
end

local function SetActionKeybind(action: MovementAction, keyCode: Enum.KeyCode)
	if action == "RunToggle" then
		keybinds.RunToggle = keyCode
	elseif action == "Dodge" then
		keybinds.Dodge = keyCode
	elseif action == "Vault" then
		keybinds.Vault = keyCode
	elseif action == "WallRun" then
		keybinds.WallRun = keyCode
	elseif action == "Climb" then
		keybinds.Climb = keyCode
	elseif action == "Slide" then
		keybinds.Slide = keyCode
	end
end

local function GetActionKeybind(action: MovementAction): Enum.KeyCode
	if action == "RunToggle" then
		return keybinds.RunToggle
	elseif action == "Dodge" then
		return keybinds.Dodge
	elseif action == "Vault" then
		return keybinds.Vault
	elseif action == "WallRun" then
		return keybinds.WallRun
	elseif action == "Climb" then
		return keybinds.Climb
	end

	return keybinds.Slide
end

local function HandleInputBegan(inputObject: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	local action = ResolveBoundAction(inputObject.KeyCode)
	if action == "RunToggle" then
		DispatchAction("RunToggle", nil, { Enabled = true })
	elseif action == "Dodge" then
		DispatchAction("Dodge", GetMoveDirection(), nil)
	elseif action == "Vault" or action == "WallRun" or action == "Climb" or action == "Slide" then
		DispatchAction(action, GetMoveDirection(), nil)
	end
end

local function HandleInputEnded(inputObject: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	local action = ResolveBoundAction(inputObject.KeyCode)
	if action == "RunToggle" then
		DispatchAction("RunToggle", nil, { Enabled = false })
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function MovementClient.GetSnapshot(): NetworkMovementSnapshot?
	return cachedSnapshot
end

function MovementClient.IsRunning(): boolean
	if not cachedSnapshot then
		return false
	end
	return cachedSnapshot.IsRunning
end

function MovementClient.GetCooldownEnd(action: MovementAction): number
	if not cachedSnapshot then
		return 0
	end
	return cachedSnapshot.CooldownEndsAt[action]
end

function MovementClient.OnSnapshotUpdated(callback: (snapshot: NetworkMovementSnapshot) -> ())
	table.insert(updateListeners, callback)
	if cachedSnapshot then
		callback(cachedSnapshot)
	end
end

function MovementClient.RequestAction(action: MovementAction, direction: Vector3?, meta: { [string]: any }?)
	DispatchAction(action, direction, meta)
end

function MovementClient.SetKeybind(action: MovementAction, keyCode: Enum.KeyCode)
	SetActionKeybind(action, keyCode)
end

function MovementClient.SetKeybinds(newKeybinds: PartialMovementKeybinds)
	if newKeybinds.RunToggle then
		keybinds.RunToggle = newKeybinds.RunToggle
	end
	if newKeybinds.Dodge then
		keybinds.Dodge = newKeybinds.Dodge
	end
	if newKeybinds.Vault then
		keybinds.Vault = newKeybinds.Vault
	end
	if newKeybinds.WallRun then
		keybinds.WallRun = newKeybinds.WallRun
	end
	if newKeybinds.Climb then
		keybinds.Climb = newKeybinds.Climb
	end
	if newKeybinds.Slide then
		keybinds.Slide = newKeybinds.Slide
	end
end

function MovementClient.GetKeybind(action: MovementAction): Enum.KeyCode
	return GetActionKeybind(action)
end

function MovementClient.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	MovementNetwork:RegisterReplicationHandler(function(snapshot: NetworkMovementSnapshot)
		NotifySnapshotUpdated(snapshot)
	end)
	MovementNetwork:Init()

	UserInputService.InputBegan:Connect(HandleInputBegan)
	UserInputService.InputEnded:Connect(HandleInputEnded)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(MovementClient)
