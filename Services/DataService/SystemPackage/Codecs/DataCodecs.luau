--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Data codec registry for DataService network transport.
	Uses JSON-in-buffer payloads so the system stays schema-flexible.
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

-----------------------------
-- VARIABLES --
-----------------------------
local DataCodecs = {}

DataCodecs.DataUpdateCodecName = "DataUpdate"
DataCodecs.DataRequestCodecName = "DataRequest"
DataCodecs.DataResponseCodecName = "DataResponse"

local DATA_REQUEST_VERSION = 1
local DATA_UPDATE_VERSION = 1
local DATA_RESPONSE_VERSION = 1

local codecsRegistered = false

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildEnvelope(hasValue: boolean, value: any): { [string]: any }
	return {
		HasValue = hasValue,
		Value = value,
	}
end

local function BuildJsonCodec(version: number, validator: (payload: any) -> (boolean, string?))
	local codec = BufferService:CreateCodecTemplate(version)

	codec.Encode = function(payload: any): buffer
		local jsonPayload = HttpService:JSONEncode(payload)
		local encoded = string.char(version) .. jsonPayload
		return buffer.fromstring(encoded)
	end

	codec.Decode = function(payload: buffer): any
		local encoded = buffer.tostring(payload)
		if #encoded < 2 then
			error("Invalid payload length")
		end

		local versionByte = string.byte(encoded, 1)
		if versionByte ~= version then
			error("Unsupported payload version")
		end

		local jsonPayload = string.sub(encoded, 2)
		return HttpService:JSONDecode(jsonPayload)
	end

	codec.Validate = validator
	return codec
end

local function ValidateRequestPayload(payload: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload must be a table"
	end

	if payload.RequestType ~= "GetData" then
		return false, "RequestType must be 'GetData'"
	end

	return true, nil
end

local function ValidateEnvelopePayload(payload: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload must be a table"
	end

	if type(payload.HasValue) ~= "boolean" then
		return false, "HasValue must be a boolean"
	end

	return true, nil
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function DataCodecs.WrapData(value: any): { [string]: any }
	return BuildEnvelope(value ~= nil, value)
end

function DataCodecs.UnwrapData(payload: any): any
	if type(payload) == "table" and payload.HasValue == true then
		return payload.Value
	end
	return nil
end

function DataCodecs.BuildRequestPayload(): { [string]: any }
	return {
		RequestType = "GetData",
	}
end

function DataCodecs.EnsureRegistered()
	if codecsRegistered then
		return
	end

	BufferService:RegisterCodec(DataCodecs.DataRequestCodecName, BuildJsonCodec(DATA_REQUEST_VERSION, ValidateRequestPayload))
	BufferService:RegisterCodec(DataCodecs.DataUpdateCodecName, BuildJsonCodec(DATA_UPDATE_VERSION, ValidateEnvelopePayload))
	BufferService:RegisterCodec(DataCodecs.DataResponseCodecName, BuildJsonCodec(DATA_RESPONSE_VERSION, ValidateEnvelopePayload))
	codecsRegistered = true
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(DataCodecs)