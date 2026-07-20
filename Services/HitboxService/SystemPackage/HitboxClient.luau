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
	-- Clean listener hook using our streamlined network layer
	HitboxNetwork.VisualRemote.OnClientEvent:Connect(function(actionType: string, ...)
		local args = { ... }

		if actionType == "HitImpactVisual" then
			local victimModel = args[1] :: Model?
			PlayHitImpactVisual(victimModel)
		else
			local shapeType = actionType
			local targetCFrame = args[1] :: CFrame?
			PlayShapeVisual(shapeType, targetCFrame)
		end
	end)
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(HitboxClient)
