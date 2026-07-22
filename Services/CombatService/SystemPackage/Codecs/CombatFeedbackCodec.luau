--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
    Codec builder for CombatFeedback payloads.
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
export type CombatFeedbackPayload = {
	ActionId: string,
	HitCount: number,
	TotalDamage: number,
	CriticalHits: number,
	Timestamp: number,
}

-----------------------------
-- VARIABLES --
-----------------------------
local CombatFeedbackCodec = {}

CombatFeedbackCodec.Version = 1
CombatFeedbackCodec.PacketSize = 14

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function ValidateFeedbackPayload(payload: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload must be a table"
	end

	local actionOk, actionError = CombatCodecShared.ValidateActionId(payload.ActionId)
	if not actionOk then
		return false, actionError
	end

	local hitOk, hitError = CombatCodecShared.ValidateNumberField(payload, "HitCount")
	if not hitOk then
		return false, hitError
	end

	local totalOk, totalError = CombatCodecShared.ValidateNumberField(payload, "TotalDamage")
	if not totalOk then
		return false, totalError
	end

	local critOk, critError = CombatCodecShared.ValidateNumberField(payload, "CriticalHits")
	if not critOk then
		return false, critError
	end

	local timeOk, timeError = CombatCodecShared.ValidateNumberField(payload, "Timestamp")
	if not timeOk then
		return false, timeError
	end

	return true, nil
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function CombatFeedbackCodec.Build()
	local codec = BufferService:CreateCodecTemplate(CombatFeedbackCodec.Version)

	codec.Encode = function(payload: CombatFeedbackPayload): buffer
		local hitCount = CombatCodecShared.ClampInt(payload.HitCount, 0, 65535)
		local totalDamage = CombatCodecShared.ClampInt(payload.TotalDamage, 0, 4294967295)
		local criticalHits = CombatCodecShared.ClampInt(payload.CriticalHits, 0, 65535)
		local timestampMs = CombatCodecShared.ClampInt(payload.Timestamp * 1000, 0, 4294967295)

		local packed = buffer.create(CombatFeedbackCodec.PacketSize)
		local offset = CombatCodecShared.WriteHeader(packed, CombatFeedbackCodec.Version, payload.ActionId)
		buffer.writeu16(packed, offset, hitCount)
		offset += 2
		buffer.writeu32(packed, offset, totalDamage)
		offset += 4
		buffer.writeu16(packed, offset, criticalHits)
		offset += 2
		buffer.writeu32(packed, offset, timestampMs)

		return packed
	end

	codec.Decode = function(payload: buffer): CombatFeedbackPayload
		if buffer.len(payload) ~= CombatFeedbackCodec.PacketSize then
			error("Invalid CombatFeedback payload length")
		end

		local actionId, offset = CombatCodecShared.ReadHeader(payload, CombatFeedbackCodec.Version)
		local hitCount = buffer.readu16(payload, offset)
		offset += 2
		local totalDamage = buffer.readu32(payload, offset)
		offset += 4
		local criticalHits = buffer.readu16(payload, offset)
		offset += 2
		local timestampMs = buffer.readu32(payload, offset)

		return {
			ActionId = actionId,
			HitCount = hitCount,
			TotalDamage = totalDamage,
			CriticalHits = criticalHits,
			Timestamp = timestampMs / 1000,
		}
	end

	codec.Validate = ValidateFeedbackPayload
	return codec
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(CombatFeedbackCodec)
