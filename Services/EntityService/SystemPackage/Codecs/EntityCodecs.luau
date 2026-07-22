--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Codec registry for EntityService transport.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BufferService = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService) :: any

local EntityCodecs = {}

EntityCodecs.SyncCodecName = "EntitySync"

local codecsRegistered = false

local function BuildEntitySyncCodec()
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
		if typeof(payload.Model) ~= "Instance" or not payload.Model:IsA("Model") then
			return false, "Model must be a Model instance"
		end
		if type(payload.Data) ~= "table" then
			return false, "Data must be a table"
		end
		return true, nil
	end
	return codec
end

function EntityCodecs.BuildSyncPayload(model: Model, data: { [string]: any }): { [string]: any }
	return {
		Model = model,
		Data = data,
	}
end

function EntityCodecs.ExtractSyncPayload(payload: any): (Model?, { [string]: any }?)
	if type(payload) ~= "table" then
		return nil, nil
	end

	local model = payload.Model
	local data = payload.Data
	if typeof(model) == "Instance" and model:IsA("Model") and type(data) == "table" then
		return model, data
	end

	return nil, nil
end

function EntityCodecs.EnsureRegistered()
	if codecsRegistered then
		return
	end

	BufferService:RegisterCodec(EntityCodecs.SyncCodecName, BuildEntitySyncCodec())
	codecsRegistered = true
end

return table.freeze(EntityCodecs)
