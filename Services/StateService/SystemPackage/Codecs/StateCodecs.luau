--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	State codec registry and builders.
]]
-----------------------------
-- SERVICES --
-----------------------------
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferService = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService) :: any
local StateTypes = require("../StateTypes")

-----------------------------
-- TYPES --
-----------------------------
type NetworkStatePayload = StateTypes.NetworkStatePayload

type ActionRequestPayload = {
	ActionName: string,
	Data: any,
}

-----------------------------
-- VARIABLES --
-----------------------------
local StateCodecs = {}

StateCodecs.ReplicationCodecName = "StateReplicated"
StateCodecs.ActionRequestCodecName = "StateActionRequest"

local REPLICATION_CODEC_VERSION = 1
local ACTION_REQUEST_CODEC_VERSION = 1
local codecsRegistered = false

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function ClampInt(value: number, minValue: number, maxValue: number): number
	return math.clamp(math.floor(value + 0.5), minValue, maxValue)
end

local function ValidateReplicationPayload(payload: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload must be a table"
	end

	for stateName, stateData in pairs(payload) do
		if type(stateName) ~= "string" then
			return false, "state name must be a string"
		end

		if type(stateData) ~= "table" then
			return false, "state data must be a table"
		end

		if type(stateData.Active) ~= "boolean" then
			return false, "state data Active must be a boolean"
		end

		if type(stateData.StackCount) ~= "number" then
			return false, "state data StackCount must be a number"
		end
	end

	return true, nil
end

local function ValidateActionRequestPayload(payload: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload must be a table"
	end

	if type(payload.ActionName) ~= "string" then
		return false, "ActionName must be a string"
	end

	return true, nil
end

local function BuildReplicationCodec()
	local codec = BufferService:CreateCodecTemplate(REPLICATION_CODEC_VERSION)

	codec.Encode = function(payload: NetworkStatePayload): buffer
		local count = 0
		local totalSize = 1 + 2 -- version + entry count
		for stateName in pairs(payload) do
			count += 1
			totalSize += 2 + #stateName + 1 + 2 -- name length + name + active + stack
		end

		local packed = buffer.create(totalSize)
		local offset = 0
		buffer.writeu8(packed, offset, REPLICATION_CODEC_VERSION)
		offset += 1
		buffer.writeu16(packed, offset, ClampInt(count, 0, 65535))
		offset += 2

		for stateName, stateData in pairs(payload) do
			local stackCount = ClampInt(stateData.StackCount, 0, 65535)
			local activeFlag = if stateData.Active then 1 else 0

			buffer.writeu16(packed, offset, #stateName)
			offset += 2
			buffer.writestring(packed, offset, stateName)
			offset += #stateName
			buffer.writeu8(packed, offset, activeFlag)
			offset += 1
			buffer.writeu16(packed, offset, stackCount)
			offset += 2
		end

		return packed
	end

	codec.Decode = function(payload: buffer): NetworkStatePayload
		if buffer.len(payload) < 3 then
			error("Invalid StateReplicated payload length")
		end

		local offset = 0
		local version = buffer.readu8(payload, offset)
		offset += 1
		if version ~= REPLICATION_CODEC_VERSION then
			error("Unsupported StateReplicated payload version")
		end

		local entryCount = buffer.readu16(payload, offset)
		offset += 2

		local decoded: NetworkStatePayload = {}
		for _ = 1, entryCount do
			local nameLength = buffer.readu16(payload, offset)
			offset += 2
			local stateName = buffer.readstring(payload, offset, nameLength)
			offset += nameLength
			local isActive = buffer.readu8(payload, offset) == 1
			offset += 1
			local stackCount = buffer.readu16(payload, offset)
			offset += 2

			decoded[stateName] = {
				Active = isActive,
				StackCount = stackCount,
			}
		end

		return decoded
	end

	codec.Validate = ValidateReplicationPayload
	return codec
end

local function BuildActionRequestCodec()
	local codec = BufferService:CreateCodecTemplate(ACTION_REQUEST_CODEC_VERSION)

	codec.Encode = function(payload: ActionRequestPayload): buffer
		local actionName = payload.ActionName
		local hasData = payload.Data ~= nil
		local jsonData = ""
		if hasData then
			jsonData = HttpService:JSONEncode(payload.Data)
		end

		local totalSize = 1 + 2 + #actionName + 1
		if hasData then
			totalSize += 2 + #jsonData
		end

		local packed = buffer.create(totalSize)
		local offset = 0
		buffer.writeu8(packed, offset, ACTION_REQUEST_CODEC_VERSION)
		offset += 1
		buffer.writeu16(packed, offset, #actionName)
		offset += 2
		buffer.writestring(packed, offset, actionName)
		offset += #actionName
		buffer.writeu8(packed, offset, if hasData then 1 else 0)
		offset += 1

		if hasData then
			buffer.writeu16(packed, offset, #jsonData)
			offset += 2
			buffer.writestring(packed, offset, jsonData)
		end

		return packed
	end

	codec.Decode = function(payload: buffer): ActionRequestPayload
		if buffer.len(payload) < 4 then
			error("Invalid StateActionRequest payload length")
		end

		local offset = 0
		local version = buffer.readu8(payload, offset)
		offset += 1
		if version ~= ACTION_REQUEST_CODEC_VERSION then
			error("Unsupported StateActionRequest payload version")
		end

		local actionNameLength = buffer.readu16(payload, offset)
		offset += 2
		local actionName = buffer.readstring(payload, offset, actionNameLength)
		offset += actionNameLength

		local hasData = buffer.readu8(payload, offset) == 1
		offset += 1

		local data = nil
		if hasData then
			local jsonLength = buffer.readu16(payload, offset)
			offset += 2
			local jsonPayload = buffer.readstring(payload, offset, jsonLength)
			data = HttpService:JSONDecode(jsonPayload)
		end

		return {
			ActionName = actionName,
			Data = data,
		}
	end

	codec.Validate = ValidateActionRequestPayload
	return codec
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function StateCodecs.BuildActionRequestPayload(actionName: string, data: any): ActionRequestPayload
	return {
		ActionName = actionName,
		Data = data,
	}
end

function StateCodecs.ExtractActionRequestPayload(payload: ActionRequestPayload): (string, any)
	return payload.ActionName, payload.Data
end

function StateCodecs.EnsureRegistered()
	if codecsRegistered then
		return
	end

	BufferService:RegisterCodec(StateCodecs.ReplicationCodecName, BuildReplicationCodec())
	BufferService:RegisterCodec(StateCodecs.ActionRequestCodecName, BuildActionRequestCodec())
	codecsRegistered = true
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StateCodecs)
