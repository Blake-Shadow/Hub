--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Codec registry for HitboxService visual transport.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BufferService = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService) :: any

local HitboxCodecs = {}

HitboxCodecs.VisualCodecName = "HitboxVisual"

local codecsRegistered = false

local function BuildVisualCodec()
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
		if type(payload.ActionType) ~= "string" then
			return false, "ActionType must be a string"
		end
		return true, nil
	end
	return codec
end

function HitboxCodecs.BuildShapePayload(shapeType: string, targetCFrame: CFrame, size: Vector3, radius: number): { [string]: any }
	return {
		ActionType = "Shape",
		ShapeType = shapeType,
		TargetCFrame = targetCFrame,
		Size = size,
		Radius = radius,
	}
end

function HitboxCodecs.BuildImpactPayload(victimModel: Model): { [string]: any }
	return {
		ActionType = "Impact",
		VictimModel = victimModel,
	}
end

function HitboxCodecs.EnsureRegistered()
	if codecsRegistered then
		return
	end

	BufferService:RegisterCodec(HitboxCodecs.VisualCodecName, BuildVisualCodec())
	codecsRegistered = true
end

return table.freeze(HitboxCodecs)
