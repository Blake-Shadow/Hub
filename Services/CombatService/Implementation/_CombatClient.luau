--!strict
--@author: Shadow
--@date: 2026-07-19
--[[@description:
	Game-level client wrapper for CombatClient.
	Provides implementation-facing API surface with RequestPunch.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local CombatClient = require(ReplicatedStorage.Services.CombatService.SystemPackage.CombatClient) :: any

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local _CombatClient = {}
local isInputBound = false
local DEBUG_ENABLED = true

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function _CombatClient.RequestPunch(direction: Vector3?)
	CombatClient.RequestPunch(direction)
end

function _CombatClient.RequestAction(actionId: string, direction: Vector3?, meta: { [string]: any }?)
	CombatClient.RequestAction(actionId, direction, meta)
end

function _CombatClient.OnFeedback(listener: (payload: any) -> ())
	CombatClient.OnFeedback(listener)
end

function _CombatClient.GetLastFeedback(): any
	return CombatClient.GetLastFeedback()
end

function _CombatClient.Init()
	if isInputBound then
		return
	end
	isInputBound = true

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if DEBUG_ENABLED then
				print("[_CombatClient] MouseButton1 detected -> RequestPunch (character forward)")
			end
			_CombatClient.RequestPunch(nil)
		end
	end)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(_CombatClient)
