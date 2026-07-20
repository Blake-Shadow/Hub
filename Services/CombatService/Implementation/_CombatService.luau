--!strict
--@author: Shadow
--@date: 2026-07-19
--[[@description:
	Game-level implementation config for CombatService.
	Keeps SystemPackage combat core agnostic while this layer binds local hitbox behavior.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local CombatService = require(ReplicatedStorage.Services.CombatService.SystemPackage.CombatService) :: any
local CombatTypes = require(ReplicatedStorage.Services.CombatService.SystemPackage.CombatTypes)
local HitboxService = require(ReplicatedStorage.Services.HitboxService.SystemPackage.HitboxService)

-----------------------------
-- TYPES --
-----------------------------
type CombatServiceInitConfig = CombatTypes.CombatServiceInitConfig

-----------------------------
-- VARIABLES --
-----------------------------
local _CombatService = {}
local DEBUG_HITBOX_COLOR = Color3.fromRGB(255, 80, 80)
local DEBUG_HITBOX_DURATION = 0.5
local DEBUG_ENABLED = true
local PUNCH_FRONT_MARGIN = 1.5
local PUNCH_PULSE_COUNT = 3
local PUNCH_PULSE_DELAY = 0.04

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function ResolveTargetsWithHitbox(attackerCharacter: Model, radius: number, _direction: Vector3?): { Model }
	local blockSize = Vector3.new(radius * 1.2, radius * 1.4, radius * 1.2)
	local forwardDistance = (blockSize.Z / 2) + PUNCH_FRONT_MARGIN
	local targets: { Model } = {}
	local seenTargets: { [Model]: boolean } = {}

	for pulse = 1, PUNCH_PULSE_COUNT do
		local hitbox = (HitboxService.NewBlock(blockSize) :: any)
			:RelativeTo(attackerCharacter)
			:ForwardBox(forwardDistance)
			:Filter(function(targetCharacter: Model)
				return targetCharacter ~= attackerCharacter
			end)

		local pulseTargets = hitbox:DrawDebugVisual(DEBUG_HITBOX_COLOR, DEBUG_HITBOX_DURATION)
		for _, target in ipairs(pulseTargets) do
			if not seenTargets[target] then
				seenTargets[target] = true
				table.insert(targets, target)
			end
		end

		if pulse < PUNCH_PULSE_COUNT then
			task.wait(PUNCH_PULSE_DELAY)
		end
	end

	if DEBUG_ENABLED then
		print(
			string.format(
				"[_CombatService] Punch debug: %s hitbox found %d target(s) over %d pulse(s).",
				attackerCharacter.Name,
				#targets,
				PUNCH_PULSE_COUNT
			)
		)
	end
	return targets
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function _CombatService.BuildInitConfig(): CombatServiceInitConfig
	return {
		HitboxTargetResolver = ResolveTargetsWithHitbox,
	}
end

function _CombatService.Init()
	CombatService:Configure(_CombatService.BuildInitConfig())
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(_CombatService)
