--!strict
--@author: Shadow
--@date: 2026-07-19
--[[@description:
	Client-side combat action dispatcher and feedback cache.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local CombatTypes = require("./CombatTypes")
local CombatNetwork = require("./CombatNetwork") :: any

-----------------------------
-- TYPES --
-----------------------------
type CombatActionId = CombatTypes.CombatActionId
type CombatActionRequestPayload = CombatTypes.CombatActionRequestPayload
type CombatFeedbackPayload = CombatTypes.CombatFeedbackPayload

-----------------------------
-- VARIABLES --
-----------------------------
local CombatClient = {}

local cachedLastFeedback: CombatFeedbackPayload? = nil
local cachedWeaponEquipped = false
local feedbackListeners: { (payload: CombatFeedbackPayload) -> () } = {}

local isInitialized = false
local DEBUG_ENABLED = true

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function NotifyFeedback(payload: CombatFeedbackPayload)
	cachedLastFeedback = payload
	if payload.ActionId == "WeaponEquip" then
		cachedWeaponEquipped = true
	elseif payload.ActionId == "WeaponUnequip" then
		cachedWeaponEquipped = false
	end

	for _, listener in ipairs(feedbackListeners) do
		task.spawn(listener, payload)
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function CombatClient.RequestAction(actionId: CombatActionId, direction: Vector3?, meta: { [string]: any }?)
	local payload: CombatActionRequestPayload = {
		ActionId = actionId,
		Direction = direction,
		Meta = meta,
	}
	CombatNetwork:RequestAction(payload)
end

function CombatClient.RequestPunch(direction: Vector3?)
	if DEBUG_ENABLED then
		print("[CombatClient] RequestPunch fired.")
	end
	CombatNetwork:RequestPunch(direction)
end

function CombatClient.RequestBasicAttack(direction: Vector3?)
	CombatClient.RequestPunch(direction)
end

function CombatClient.RequestWeaponEquip()
	CombatClient.RequestAction("WeaponEquip", nil, nil)
end

function CombatClient.RequestWeaponUnequip()
	CombatClient.RequestAction("WeaponUnequip", nil, nil)
end

function CombatClient.IsWeaponEquipped(): boolean
	return cachedWeaponEquipped
end

function CombatClient.GetLastFeedback(): CombatFeedbackPayload?
	return cachedLastFeedback
end

function CombatClient.OnFeedback(listener: (payload: CombatFeedbackPayload) -> ())
	table.insert(feedbackListeners, listener)
	if cachedLastFeedback then
		listener(cachedLastFeedback)
	end
end

function CombatClient.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	CombatNetwork:RegisterFeedbackHandler(function(payload: CombatFeedbackPayload)
		NotifyFeedback(payload)
	end)
	CombatNetwork:Init()
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(CombatClient)
