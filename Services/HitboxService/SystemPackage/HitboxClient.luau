--!strict
--@author: Shadow
--@date: 2026/07/01
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local HitboxNetwork = require("./HitboxNetwork")
-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local HitboxClient = {}

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function PlayHitImpactVisual(victimModel: Model?)
	print("Client local impact cosmetics played on target:", victimModel)
end

local function PlayShapeVisual(shapeType: string, targetCFrame: CFrame?)
	if not targetCFrame then
		return
	end

	print("Client hitbox visual:", shapeType, targetCFrame)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function HitboxClient.Init()
	HitboxNetwork.SetVisualHandler(function(payload: any)
		if type(payload) ~= "table" then
			return
		end

		if payload.ActionType == "Impact" then
			local victimModel = if typeof(payload.VictimModel) == "Instance" and payload.VictimModel:IsA("Model")
				then payload.VictimModel
				else nil
			PlayHitImpactVisual(victimModel)
			return
		end

		local shapeType = payload.ShapeType
		local targetCFrame = payload.TargetCFrame
		if type(shapeType) == "string" and typeof(targetCFrame) == "CFrame" then
			PlayShapeVisual(shapeType, targetCFrame)
		end
	end)

	HitboxNetwork.Init()
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(HitboxClient)
