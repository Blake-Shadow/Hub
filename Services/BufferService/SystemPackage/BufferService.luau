--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Centralized codec registry and serialization boundary.
	Gameplay systems pass normal tables; this layer handles transport format.
]]
-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferTypes = require("./BufferTypes")

-----------------------------
-- TYPES --
-----------------------------
type CodecName = BufferTypes.CodecName
type TransportMode = BufferTypes.TransportMode
type RegisteredCodec = BufferTypes.RegisteredCodec

-----------------------------
-- VARIABLES --
-----------------------------
local BufferService = {}

local activeCodecs: { [CodecName]: RegisteredCodec } = {}
local activeTransportMode: TransportMode = "Buffer"
local isDebugEnabled = false

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function ValidatePayload(codec: RegisteredCodec, payload: any): (boolean, string?)
	local validator = codec.Validate
	if not validator then
		return true, nil
	end

	local success, resultA, resultB = pcall(function()
		return validator(payload)
	end)

	if not success then
		return false, "Validator raised an error."
	end

	local ok = resultA == true
	local reason: string? = nil

	if type(resultB) == "string" then
		reason = resultB
	end

	return ok, reason
end

local function BuildError(reason: string): string
	return string.format("[BufferService] %s", reason)
end

local function PrintDebug(message: string)
	if isDebugEnabled then
		print(string.format("[BufferService] %s", message))
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function BufferService:SetDebugEnabled(enabled: boolean)
	isDebugEnabled = enabled
end

function BufferService:SetTransportMode(mode: TransportMode)
	activeTransportMode = mode
end

function BufferService:GetTransportMode(): TransportMode
	return activeTransportMode
end

function BufferService:RegisterCodec(name: CodecName, codec: RegisteredCodec)
	assert(type(name) == "string" and name ~= "", "[BufferService] Codec name must be a non-empty string.")
	assert(type(codec) == "table", "[BufferService] Codec must be a table.")
	assert(type(codec.Version) == "number", "[BufferService] Codec.Version must be a number.")
	assert(type(codec.Encode) == "function", "[BufferService] Codec.Encode must be a function.")
	assert(type(codec.Decode) == "function", "[BufferService] Codec.Decode must be a function.")

	activeCodecs[name] = codec
end

function BufferService:CreateCodecTemplate(version: number): RegisteredCodec
	assert(type(version) == "number", "[BufferService] CreateCodecTemplate requires a numeric version.")

	return {
		Version = version,
		Encode = function(_payload: any): buffer
			error("[BufferService] Codec template Encode is not implemented.")
		end,
		Decode = function(_payload: buffer): any
			error("[BufferService] Codec template Decode is not implemented.")
		end,
		Validate = function(_payload: any): (boolean, string?)
			return true, nil
		end,
	}
end

function BufferService:HasCodec(name: CodecName): boolean
	return activeCodecs[name] ~= nil
end

function BufferService:Encode(name: CodecName, payload: any): (boolean, any, string?)
	local codec = activeCodecs[name]
	if not codec then
		return false, nil, BuildError(string.format("Codec '%s' is not registered.", name))
	end

	local transportMode = codec.TransportMode or activeTransportMode

	local isValid, validationReason = ValidatePayload(codec, payload)
	if not isValid then
		return false, nil, BuildError(string.format("Encode validation failed for '%s': %s", name, validationReason or "unknown reason"))
	end

	if transportMode == "Table" then
		PrintDebug(string.format("ENCODE[%s] mode=Table", name))
		return true, payload, nil
	end

	local success, encodedOrError = pcall(function()
		return codec.Encode(payload)
	end)

	if not success then
		return false, nil, BuildError(string.format("Encode failed for '%s': %s", name, tostring(encodedOrError)))
	end

	if typeof(encodedOrError) ~= "buffer" then
		return false, nil, BuildError(string.format("Encode for '%s' did not return a buffer.", name))
	end

	local encodedPayload = encodedOrError :: buffer
	PrintDebug(string.format("ENCODE[%s] mode=Buffer bytes=%d", name, buffer.len(encodedPayload)))

	return true, encodedPayload, nil
end

function BufferService:Decode(name: CodecName, payload: any): (boolean, any, string?)
	local codec = activeCodecs[name]
	if not codec then
		return false, nil, BuildError(string.format("Codec '%s' is not registered.", name))
	end

	local transportMode = codec.TransportMode or activeTransportMode

	if transportMode == "Table" then
		local isValid, validationReason = ValidatePayload(codec, payload)
		if not isValid then
			return false, nil, BuildError(string.format("Decode validation failed for '%s': %s", name, validationReason or "unknown reason"))
		end

		PrintDebug(string.format("DECODE[%s] mode=Table", name))
		return true, payload, nil
	end

	if typeof(payload) ~= "buffer" then
		return false, nil, BuildError(string.format("Decode for '%s' expected a buffer payload.", name))
	end

	local rawPayload = payload :: buffer
	local success, decodedOrError = pcall(function()
		return codec.Decode(rawPayload)
	end)

	if not success then
		return false, nil, BuildError(string.format("Decode failed for '%s': %s", name, tostring(decodedOrError)))
	end

	local decodedPayload = decodedOrError
	local isValid, validationReason = ValidatePayload(codec, decodedPayload)
	if not isValid then
		return false, nil, BuildError(string.format("Decoded payload validation failed for '%s': %s", name, validationReason or "unknown reason"))
	end

	PrintDebug(string.format("DECODE[%s] mode=Buffer bytes=%d", name, buffer.len(rawPayload)))
	return true, decodedPayload, nil
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(BufferService)
