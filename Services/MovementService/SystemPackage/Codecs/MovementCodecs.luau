--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Codec registry for MovementService transport.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BufferService = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService) :: any

local MovementCodecs = {}

MovementCodecs.ActionRequestCodecName = "MovementActionRequest"
MovementCodecs.ReplicationCodecName = "MovementStateReplicated"

local codecsRegistered = false

local function BuildActionRequestCodec()
	local codec = BufferService:CreateCodecTemplate(1)
	codec.TransportMode = "Table"
	codec.Encode = function(payload: any): any
		return payload
	end
	codec.Decode = function(payload: any): any
		return payload
	end
	codec.Validate = function(payload: any): (boolean, string?)
		if type(payload) ~= "table" then
			return false, "payload must be a table"
		end
		if type(payload.Action) ~= "string" then
			return false, "Action must be a string"
		end
		if payload.Direction ~= nil and typeof(payload.Direction) ~= "Vector3" then
			return false, "Direction must be a Vector3 when provided"
		end
		if payload.Meta ~= nil and type(payload.Meta) ~= "table" then
			return false, "Meta must be a table when provided"
		end
		return true, nil
	end
	return codec
end

local function BuildReplicationCodec()
	local codec = BufferService:CreateCodecTemplate(1)
	codec.TransportMode = "Table"
	codec.Encode = function(payload: any): any
		return payload
	end
	codec.Decode = function(payload: any): any
		return payload
	end
	codec.Validate = function(payload: any): (boolean, string?)
		if type(payload) ~= "table" then
			return false, "payload must be a table"
		end
		if type(payload.EnabledModes) ~= "table" then
			return false, "EnabledModes must be a table"
		end
		if type(payload.IsRunning) ~= "boolean" then
			return false, "IsRunning must be a boolean"
		end
		if payload.ActiveAction ~= nil and type(payload.ActiveAction) ~= "string" then
			return false, "ActiveAction must be a string when provided"
		end
		if type(payload.CooldownEndsAt) ~= "table" then
			return false, "CooldownEndsAt must be a table"
		end
		return true, nil
	end
	return codec
end

function MovementCodecs.EnsureRegistered()
	if codecsRegistered then
		return
	end

	BufferService:RegisterCodec(MovementCodecs.ActionRequestCodecName, BuildActionRequestCodec())
	BufferService:RegisterCodec(MovementCodecs.ReplicationCodecName, BuildReplicationCodec())
	codecsRegistered = true
end

return table.freeze(MovementCodecs)
