--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Codec registry for StatsService transport.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BufferService = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService) :: any

local StatsCodecs = {}

StatsCodecs.AllocateStatCodecName = "StatsAllocate"
StatsCodecs.DamageNumberCodecName = "StatsDamageNumber"
StatsCodecs.SyncProfileCodecName = "StatsSyncProfile"

local codecsRegistered = false

local function BuildAllocateStatCodec()
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
		if type(payload.StatName) ~= "string" or payload.StatName == "" then
			return false, "StatName must be a non-empty string"
		end
		return true, nil
	end
	return codec
end

local function BuildDamageNumberCodec()
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
		if typeof(payload.TargetCharacter) ~= "Instance" or not payload.TargetCharacter:IsA("Model") then
			return false, "TargetCharacter must be a Model"
		end
		if type(payload.Amount) ~= "number" then
			return false, "Amount must be a number"
		end
		if type(payload.IsCritical) ~= "boolean" then
			return false, "IsCritical must be a boolean"
		end
		return true, nil
	end
	return codec
end

local function BuildSyncProfileCodec()
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
		if type(payload.HasProfile) ~= "boolean" then
			return false, "HasProfile must be a boolean"
		end
		return true, nil
	end
	return codec
end

function StatsCodecs.BuildAllocatePayload(statName: string): { [string]: any }
	return { StatName = statName }
end

function StatsCodecs.ExtractAllocatePayload(payload: any): string?
	if type(payload) == "table" and type(payload.StatName) == "string" then
		return payload.StatName
	end
	return nil
end

function StatsCodecs.BuildDamagePayload(targetCharacter: Model, amount: number, isCritical: boolean): { [string]: any }
	return {
		TargetCharacter = targetCharacter,
		Amount = amount,
		IsCritical = isCritical,
	}
end

function StatsCodecs.ExtractDamagePayload(payload: any): (Model?, number?, boolean?)
	if type(payload) ~= "table" then
		return nil, nil, nil
	end
	local target = payload.TargetCharacter
	local amount = payload.Amount
	local isCritical = payload.IsCritical
	if typeof(target) == "Instance" and target:IsA("Model") and type(amount) == "number" and type(isCritical) == "boolean" then
		return target, amount, isCritical
	end
	return nil, nil, nil
end

function StatsCodecs.WrapProfile(profile: any): { [string]: any }
	return {
		HasProfile = profile ~= nil,
		Profile = profile,
	}
end

function StatsCodecs.UnwrapProfile(payload: any): any
	if type(payload) == "table" and payload.HasProfile == true then
		return payload.Profile
	end
	return nil
end

function StatsCodecs.EnsureRegistered()
	if codecsRegistered then
		return
	end

	BufferService:RegisterCodec(StatsCodecs.AllocateStatCodecName, BuildAllocateStatCodec())
	BufferService:RegisterCodec(StatsCodecs.DamageNumberCodecName, BuildDamageNumberCodec())
	BufferService:RegisterCodec(StatsCodecs.SyncProfileCodecName, BuildSyncProfileCodec())
	codecsRegistered = true
end

return table.freeze(StatsCodecs)
