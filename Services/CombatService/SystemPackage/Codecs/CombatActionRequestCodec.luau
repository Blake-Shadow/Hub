--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
    Codec builder for CombatActionRequest payloads.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferService = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService) :: any
local CombatCodecShared = require("./CombatCodecShared")

-----------------------------
-- TYPES --
-----------------------------
export type CombatActionRequestPayload = {
	ActionId: string,
	Direction: Vector3?,
	Meta: { [string]: any }?,
}

-----------------------------
-- VARIABLES --
-----------------------------
local CombatActionRequestCodec = {}

CombatActionRequestCodec.Version = 1
CombatActionRequestCodec.PacketSize = 15

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function ValidateActionRequestPayload(payload: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload must be a table"
	end

	local actionOk, actionError = CombatCodecShared.ValidateActionId(payload.ActionId)
	if not actionOk then
		return false, actionError
	end

	if payload.Direction ~= nil and typeof(payload.Direction) ~= "Vector3" then
		return false, "Direction must be a Vector3 when provided"
	end

	return true, nil
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function CombatActionRequestCodec.Build()
	local codec = BufferService:CreateCodecTemplate(CombatActionRequestCodec.Version)

	codec.Encode = function(payload: CombatActionRequestPayload): buffer
		local encodedDirection = payload.Direction
		local hasDirection = if encodedDirection then 1 else 0
		local directionX = 0
		local directionY = 0
		local directionZ = 0

		if encodedDirection then
			directionX = encodedDirection.X
			directionY = encodedDirection.Y
			directionZ = encodedDirection.Z
		end

		local packed = buffer.create(CombatActionRequestCodec.PacketSize)
		local offset = CombatCodecShared.WriteHeader(packed, CombatActionRequestCodec.Version, payload.ActionId)
		buffer.writeu8(packed, offset, hasDirection)
		offset += 1
		buffer.writef32(packed, offset, directionX)
		offset += 4
		buffer.writef32(packed, offset, directionY)
		offset += 4
		buffer.writef32(packed, offset, directionZ)

		return packed
	end

	codec.Decode = function(payload: buffer): CombatActionRequestPayload
		if buffer.len(payload) ~= CombatActionRequestCodec.PacketSize then
			error("Invalid CombatActionRequest payload length")
		end

		local actionId, offset = CombatCodecShared.ReadHeader(payload, CombatActionRequestCodec.Version)
		local hasDirection = buffer.readu8(payload, offset)
		offset += 1

		local direction: Vector3? = nil
		if hasDirection == 1 then
			local x = buffer.readf32(payload, offset)
			offset += 4
			local y = buffer.readf32(payload, offset)
			offset += 4
			local z = buffer.readf32(payload, offset)
			direction = Vector3.new(x, y, z)
		end

		return {
			ActionId = actionId,
			Direction = direction,
			Meta = nil,
		}
	end

	codec.Validate = ValidateActionRequestPayload
	return codec
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(CombatActionRequestCodec)
