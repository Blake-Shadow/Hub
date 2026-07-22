--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Transport helper that bridges remotes with BufferService codecs.
	Network modules can remain table-first and delegate serialization here.
]]
-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferService = require("./BufferService") :: any
local BufferTypes = require("./BufferTypes")

-----------------------------
-- TYPES --
-----------------------------
type CodecName = BufferTypes.CodecName

-----------------------------
-- VARIABLES --
-----------------------------
local BufferNetwork = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function WarnTransport(message: string)
	warn(string.format("[BufferNetwork] %s", message))
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function BufferNetwork.FireServer(remote: RemoteEvent, codecName: CodecName, payload: any): boolean
	local ok, encoded, err = BufferService:Encode(codecName, payload)
	if not ok then
		WarnTransport(string.format("FireServer dropped '%s': %s", codecName, tostring(err)))
		return false
	end

	remote:FireServer(encoded)
	return true
end

function BufferNetwork.FireClient(remote: RemoteEvent, player: Player, codecName: CodecName, payload: any): boolean
	local ok, encoded, err = BufferService:Encode(codecName, payload)
	if not ok then
		WarnTransport(string.format("FireClient dropped '%s': %s", codecName, tostring(err)))
		return false
	end

	remote:FireClient(player, encoded)
	return true
end

function BufferNetwork.FireAllClients(remote: RemoteEvent, codecName: CodecName, payload: any): boolean
	local ok, encoded, err = BufferService:Encode(codecName, payload)
	if not ok then
		WarnTransport(string.format("FireAllClients dropped '%s': %s", codecName, tostring(err)))
		return false
	end

	remote:FireAllClients(encoded)
	return true
end

function BufferNetwork.BindServerEvent(
	remote: RemoteEvent,
	codecName: CodecName,
	handler: (player: Player, payload: any) -> ()
)
	return remote.OnServerEvent:Connect(function(player: Player, encodedPayload: any)
		local ok, decoded, err = BufferService:Decode(codecName, encodedPayload)
		if not ok then
			WarnTransport(string.format("Server decode dropped '%s': %s", codecName, tostring(err)))
			return
		end

		handler(player, decoded)
	end)
end

function BufferNetwork.BindClientEvent(remote: RemoteEvent, codecName: CodecName, handler: (payload: any) -> ())
	return remote.OnClientEvent:Connect(function(encodedPayload: any)
		local ok, decoded, err = BufferService:Decode(codecName, encodedPayload)
		if not ok then
			WarnTransport(string.format("Client decode dropped '%s': %s", codecName, tostring(err)))
			return
		end

		handler(decoded)
	end)
end

function BufferNetwork.InvokeServer(
	remote: RemoteFunction,
	requestCodecName: CodecName,
	responseCodecName: CodecName,
	requestPayload: any
): (boolean, any, string?)
	local encodeOk, encodedRequest, encodeErr = BufferService:Encode(requestCodecName, requestPayload)
	if not encodeOk then
		return false, nil, string.format("[BufferNetwork] InvokeServer encode failed '%s': %s", requestCodecName, tostring(encodeErr))
	end

	local invokeOk, encodedResponse = pcall(function()
		return remote:InvokeServer(encodedRequest)
	end)
	if not invokeOk then
		return false, nil, string.format("[BufferNetwork] InvokeServer runtime failed: %s", tostring(encodedResponse))
	end

	if encodedResponse == nil then
		return false, nil, "[BufferNetwork] InvokeServer returned nil response payload"
	end

	local decodeOk, decodedResponse, decodeErr = BufferService:Decode(responseCodecName, encodedResponse)
	if not decodeOk then
		return false, nil, string.format("[BufferNetwork] InvokeServer decode failed '%s': %s", responseCodecName, tostring(decodeErr))
	end

	return true, decodedResponse, nil
end

function BufferNetwork.BindServerInvoke(
	remote: RemoteFunction,
	requestCodecName: CodecName,
	responseCodecName: CodecName,
	handler: (player: Player, payload: any) -> any,
	fallbackResponse: any
)
	remote.OnServerInvoke = function(player: Player, encodedRequestPayload: any)
		local decodeOk, decodedRequest, decodeErr = BufferService:Decode(requestCodecName, encodedRequestPayload)
		if not decodeOk then
			WarnTransport(string.format("Server invoke decode dropped '%s': %s", requestCodecName, tostring(decodeErr)))
			local fallbackOk, fallbackEncoded = BufferService:Encode(responseCodecName, fallbackResponse)
			if fallbackOk then
				return fallbackEncoded
			end
			return nil
		end

		local rawResponse = handler(player, decodedRequest)
		local responseToSend = rawResponse
		if responseToSend == nil then
			responseToSend = fallbackResponse
		end

		local encodeOk, encodedResponse, encodeErr = BufferService:Encode(responseCodecName, responseToSend)
		if not encodeOk then
			WarnTransport(string.format("Server invoke encode dropped '%s': %s", responseCodecName, tostring(encodeErr)))
			local fallbackOk, fallbackEncoded = BufferService:Encode(responseCodecName, fallbackResponse)
			if fallbackOk then
				return fallbackEncoded
			end
			return nil
		end

		return encodedResponse
	end
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(BufferNetwork)
