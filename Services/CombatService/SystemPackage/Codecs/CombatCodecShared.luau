--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
    Shared helpers for combat codec builders.
]]
-----------------------------
-- VARIABLES --
-----------------------------
local CombatCodecShared = {}

CombatCodecShared.ACTION_TO_ENUM = {
	Punch = 1,
	BasicAttack = 1,
}

CombatCodecShared.ENUM_TO_ACTION = {
	[1] = "Punch",
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function CombatCodecShared.ResolveActionEnum(actionId: string): number?
	return CombatCodecShared.ACTION_TO_ENUM[actionId]
end

function CombatCodecShared.ResolveActionId(value: number): string?
	return CombatCodecShared.ENUM_TO_ACTION[value]
end

function CombatCodecShared.ClampInt(value: number, minValue: number, maxValue: number): number
	return math.clamp(math.floor(value + 0.5), minValue, maxValue)
end

function CombatCodecShared.ValidateActionId(actionId: any): (boolean, string?)
	if type(actionId) ~= "string" then
		return false, "ActionId must be a string"
	end

	if CombatCodecShared.ResolveActionEnum(actionId) == nil then
		return false, "ActionId is not recognized"
	end

	return true, nil
end

function CombatCodecShared.ValidateNumberField(payload: any, fieldName: string): (boolean, string?)
	if type(payload[fieldName]) ~= "number" then
		return false, string.format("%s must be a number", fieldName)
	end

	return true, nil
end

function CombatCodecShared.WriteHeader(packed: buffer, version: number, actionId: string): number
	local actionEnum = CombatCodecShared.ResolveActionEnum(actionId)
	if not actionEnum then
		error("Unsupported combat action")
	end

	local offset = 0
	buffer.writeu8(packed, offset, version)
	offset += 1
	buffer.writeu8(packed, offset, actionEnum)
	offset += 1

	return offset
end

function CombatCodecShared.ReadHeader(payload: buffer, expectedVersion: number): (string, number)
	local offset = 0
	local version = buffer.readu8(payload, offset)
	offset += 1
	if version ~= expectedVersion then
		error("Unsupported payload version")
	end

	local actionEnum = buffer.readu8(payload, offset)
	offset += 1
	local actionId = CombatCodecShared.ResolveActionId(actionEnum)
	if not actionId then
		error("Unknown payload action enum")
	end

	return actionId, offset
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(CombatCodecShared)
