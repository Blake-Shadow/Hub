--!strict
--@author: Shadow
--@date: 
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local GameMath = {}

local randomProvider = Random.new()

------------------------------------------------------------------------
-- I. LINEAR & MULTIPLICATIVE SCALING
------------------------------------------------------------------------

-- Combines a raw config value with a saved bonus modifier
function GameMath.CombineBaseValues(configValue: number?, savedBonusValue: number): number
	return (configValue or 0) + savedBonusValue
end

-- Linear Additive: Base + (Score * Factor)
function GameMath.ApplyLinearBonus(base: number, score: number, factor: number, minLimit: number?): number
	local result = base + (score * factor)
	return math.max(minLimit or 0, result)
end

-- Multiplier Scale: 1 + (Score * Factor)
function GameMath.ApplyMultiplier(score: number, factor: number, minLimit: number?): number
	local result = 1 + (score * factor)
	return math.max(minLimit or 0, result)
end

------------------------------------------------------------------------
-- II. BASELINE PROTECTIONS
------------------------------------------------------------------------

-- Amplified Integer: Rounded multiplication for whole numbers (e.g., Armor)
function GameMath.ApplyAmplifiedInteger(base: number, score: number, factor: number, minLimit: number?): number
	local multiplier = 1 + (score * factor)
	local result = math.round(base * multiplier)
	return math.max(minLimit or 0, result)
end

-- Clamped Amplification: Multiplies a value and bounds it strictly within a range
function GameMath.ApplyClampedAmplification(base: number, score: number, factor: number, minLimit: number, maxLimit: number): number
	local multiplier = 1 + (score * factor)
	return math.clamp(base * multiplier, minLimit, maxLimit)
end

-- Inverse Reduction: Drops a scale below 100% (e.g., Debuff / Cooldown durations)
function GameMath.ApplyInverseReduction(score: number, factor: number, minLimit: number?): number
	local result = 1 - (score * factor)
	return math.max(minLimit or 0, result)
end

------------------------------------------------------------------------
-- III. ADVANCED CURVE MATHEMATICS
------------------------------------------------------------------------

-- Diminishing Returns: Smoothly curves a stat towards a hard max ceiling
function GameMath.ApplyDiminishingReturns(score: number, ceiling: number, halfPoint: number): number
	if score <= 0 or halfPoint <= 0 then return 0 end
	return (score * ceiling) / (score + halfPoint)
end

-- Exponential Progression: Multiplier * (GrowthRate ^ Exponent)
function GameMath.ApplyExponentialGrowth(multiplier: number, growthRate: number, exponent: number, minLimit: number?): number
	local result = multiplier * math.pow(growthRate, exponent)
	return math.max(minLimit or 0, result)
end

------------------------------------------------------------------------
-- IV. SYSTEM TRANSLATORS
------------------------------------------------------------------------

-- Cross-Stat Conversion: Converts a portion of one stat into another
function GameMath.CalculateCrossConversion(sourceTotal: number, ratio: number): number
	return sourceTotal * ratio
end

-- Compound Reductions: Compounds percentage modifiers multiplicatively to keep them balanced
function GameMath.ApplyCompoundReduction(base: number, modifiers: { number }): number
	local currentMultiplier = 1
	for _, mod in ipairs(modifiers) do
		currentMultiplier *= (1 - mod)
	end
	return base * currentMultiplier
end

-- Resource Ratio: Returns a safe 0.0 to 1.0 decimal percentage for active UI bars
function GameMath.GetResourceRatio(current: number, max: number): number
	if max <= 0 then return 0 end
	return math.clamp(current / max, 0, 1)
end

------------------------------------------------------------------------
-- V. RUNTIME UTILITIES
------------------------------------------------------------------------

-- Percentage Modifier: Multiplies a value by an explicit percentage change
function GameMath.ApplyPercentageModifier(base: number, percentChange: number, minLimit: number?): number
	local result = base * (1 + percentChange)
	return math.max(minLimit or 0, result)
end

-- Statistical Jitter: Applies a randomized +/- variance percentage to a value
function GameMath.ApplyVariance(base: number, range: number): number
	local minFactor = 1 - range
	local maxFactor = 1 + range
	return base * randomProvider:NextNumber(minFactor, maxFactor)
end

-- Delta Lerp: Smoothly interpolates a value independent of a user's frame rate
function GameMath.DeltaLerp(current: number, target: number, speed: number, deltaTime: number): number
	local factor = 1 - math.exp(-speed * deltaTime)
	return current + (target - current) * factor
end

-- Precision Rounding: Rounds a number to a specific decimal place threshold
function GameMath.RoundToPlace(value: number, decimalPlaces: number): number
	local shift = math.pow(10, decimalPlaces)
	return math.round(value * shift) / shift
end

------------------------------------------------------------------------
-- 📖 FRAMEWORK ARCHITECTURE REFERENCE INDEX
------------------------------------------------------------------------
-- [[ I. LINEAR & MULTIPLICATIVE SCALING ]]
-- * StatsMath.CombineBaseValues(configValue, savedBonusValue)
-- * StatsMath.ApplyLinearBonus(base, score, factor, minLimit)
-- * StatsMath.ApplyMultiplier(score, factor, minLimit)

-- [[ II. BASELINE PROTECTIONS ]]
-- * StatsMath.ApplyAmplifiedInteger(base, score, factor, minLimit)
-- * StatsMath.ApplyClampedAmplification(base, score, factor, minLimit, maxLimit)
-- * StatsMath.ApplyInverseReduction(score, factor, minLimit)

-- [[ III. ADVANCED CURVE MATHEMATICS ]]
-- * StatsMath.ApplyDiminishingReturns(score, ceiling, halfPoint)
-- * StatsMath.ApplyExponentialGrowth(multiplier, growthRate, exponent, minLimit)

-- [[ IV. SYSTEM TRANSLATORS ]]
-- * StatsMath.CalculateCrossConversion(sourceTotal, ratio)
-- * StatsMath.ApplyCompoundReduction(base, modifiersTable)
-- * StatsMath.GetResourceRatio(current, max)

-- [[ V. RUNTIME UTILITIES ]]
-- * StatsMath.ApplyPercentageModifier(base, percentChange, minLimit)
-- * StatsMath.ApplyVariance(base, range)
-- * StatsMath.DeltaLerp(current, target, speed, deltaTime)
-- * StatsMath.RoundToPlace(value, decimalPlaces)
------------------------------------------------------------------------

return table.freeze(GameMath)