--!strict
--@author: Shadow
--@date: 2026-07-19
--[[@description:
	Agnostic combat damage resolver that can be reused across action systems.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local GameMath = require(ReplicatedStorage.Modules.Helpers.GameMath.GameMath)

-----------------------------
-- TYPES --
-----------------------------
-----------------------------
-- VARIABLES --
-----------------------------
local DamageFormula = {}

local randomProvider = Random.new()

local DEFAULT_BASE_POWER = 10
local DEFAULT_SKILL_POWER = 0
local DEFAULT_MIN_DAMAGE = 1

local DEFAULT_DEFENSE_HALF_POINT = 100
local DEFAULT_MAX_MITIGATION = 0.85

local DEFAULT_CRIT_CHANCE = 0
local DEFAULT_CRIT_MULTIPLIER = 1.5

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function Clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function GetNumberAttribute(model: Model?, key: string, fallback: number): number
	if not model then
		return fallback
	end

	local value = model:GetAttribute(key)
	if type(value) == "number" then
		return value
	end

	return fallback
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function DamageFormula.CalculateMitigationPercent(
	defenseValue: number,
	halfPoint: number?,
	maxMitigation: number?
): number
	local resolvedHalfPoint = math.max(1, halfPoint or DEFAULT_DEFENSE_HALF_POINT)
	local resolvedMaxMitigation = Clamp01(maxMitigation or DEFAULT_MAX_MITIGATION)
	return GameMath.ApplyDiminishingReturns(math.max(0, defenseValue), resolvedMaxMitigation, resolvedHalfPoint)
end

function DamageFormula.RollCritical(critChance: number, forceCritical: boolean?): boolean
	if forceCritical == true then
		return true
	end

	if critChance <= 0 then
		return false
	end

	return randomProvider:NextNumber() <= Clamp01(critChance)
end

function DamageFormula.Calculate(
	basePower: number?,
	skillPower: number?,
	flatBonus: number?,
	percentBonus: number?,
	defenseValue: number?,
	armorPenetration: number?,
	critChance: number?,
	critMultiplier: number?,
	variance: number?,
	minDamage: number?,
	forceCritical: boolean?,
	defenseHalfPoint: number?,
	maxMitigationPercent: number?
): (number, boolean, number, number, number)
	local resolvedBasePower = basePower or DEFAULT_BASE_POWER
	local resolvedSkillPower = skillPower or DEFAULT_SKILL_POWER
	local resolvedFlatBonus = flatBonus or 0
	local resolvedPercentBonus = percentBonus or 0
	local resolvedVariance = math.max(0, variance or 0)
	local resolvedMinDamage = minDamage or DEFAULT_MIN_DAMAGE

	local rawDamage = GameMath.CombineBaseValues(resolvedBasePower, resolvedSkillPower)
	rawDamage = GameMath.CombineBaseValues(rawDamage, resolvedFlatBonus)
	rawDamage = GameMath.ApplyPercentageModifier(rawDamage, resolvedPercentBonus)

	local effectiveDefense = math.max(0, (defenseValue or 0) - (armorPenetration or 0))

	local mitigationPercent =
		DamageFormula.CalculateMitigationPercent(effectiveDefense, defenseHalfPoint, maxMitigationPercent)

	local postMitigationDamage = rawDamage * (1 - mitigationPercent)

	local resolvedCritChance = critChance or DEFAULT_CRIT_CHANCE
	local resolvedCritMultiplier = math.max(1, critMultiplier or DEFAULT_CRIT_MULTIPLIER)
	local isCritical = DamageFormula.RollCritical(resolvedCritChance, forceCritical)
	if isCritical then
		postMitigationDamage *= resolvedCritMultiplier
	end

	if resolvedVariance > 0 then
		postMitigationDamage = GameMath.ApplyVariance(postMitigationDamage, resolvedVariance)
	end

	local finalDamage = math.max(resolvedMinDamage, math.round(postMitigationDamage))
	return finalDamage, isCritical, rawDamage, postMitigationDamage, mitigationPercent
end

function DamageFormula.CalculateFromCharacters(
	attackerCharacter: Model?,
	defenderCharacter: Model?,
	attackAttributeKey: string?,
	defenseAttributeKey: string?,
	skillPower: number?,
	flatBonus: number?,
	percentBonus: number?,
	armorPenetration: number?,
	critChance: number?,
	critMultiplier: number?,
	variance: number?,
	minDamage: number?,
	forceCritical: boolean?,
	defenseHalfPoint: number?,
	maxMitigationPercent: number?
): (number, boolean, number, number, number)
	local resolvedAttackKey = attackAttributeKey or "BasePower"
	local resolvedDefenseKey = defenseAttributeKey or "BaseDefense"

	local basePower = GetNumberAttribute(attackerCharacter, resolvedAttackKey, DEFAULT_BASE_POWER)
	local defenseValue = GetNumberAttribute(defenderCharacter, resolvedDefenseKey, 0)

	return DamageFormula.Calculate(
		basePower,
		skillPower,
		flatBonus,
		percentBonus,
		defenseValue,
		armorPenetration,
		critChance,
		critMultiplier,
		variance,
		minDamage,
		forceCritical,
		defenseHalfPoint,
		maxMitigationPercent
	)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(DamageFormula)
