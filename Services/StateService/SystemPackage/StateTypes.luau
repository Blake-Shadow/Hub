--!strict
--@author: Shadow
--@date: 
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------

-----------------------------
-- TYPES --
-----------------------------
-- Agnostic actions are represented by unique string identifiers
export type Action = string

-- Developer-friendly configuration structure for durations and limits
export type TimeConfig = {
	Hours: number?,
	Minutes: number?,
	Seconds: number?
}

-- Persistence behaviors for offline profiles
export type OfflinePolicy = "Paused" | "RealTime"

-- Agnostic stat modifiers: Key is the stat name (e.g., "WalkSpeed", "Gravity", "Defense")
-- and the value defines how the stat is modified (additive offset and/or multiplicative factor)
export type StatModifierInstruction = {
	Add: number?,       -- Value to add/subtract (e.g., +8, -5)
	Multiply: number?   -- Value to multiply by (e.g., 1.5 for a 50% buff, 0.5 for a 50% debuff)
}

export type StatModifier = { [string]: StatModifierInstruction }

-- Configuration structure for registering a state
export type StateConfig = {
	Priority: number,                     -- Higher priority states cancel/block lower ones
	Stackable: boolean,                   -- If false, new requests are ignored while active
	KeepOnDeath: boolean,                 -- Does this persist when the player respawns?
	SaveOnExit: boolean,                  -- Does this save to the database when logging off?
	-- Clashing Mechanics
	Impact: number?,                      -- 0 = Unstoppable, 1 = Light, 2 = Medium, 3 = Heavy
	-- Agnostic Action Restrictions
	Disables: {Action}?,                  -- Custom actions blocked while this state is active
	-- Offline Persistence
	OfflinePolicy: OfflinePolicy?,        -- Freeze buff timer vs. Real-world elapsed time calculations
	MaxOfflineDuration: (TimeConfig | number)?, -- Capped time limit for offline calculations
	-- Agnostic Stat Modifiers
	Modifiers: StatModifier?              -- Stat shifts compiled into the Modifier Stack
}

-- Registry template for the master StateSettings module
export type MasterConfig = {
	Actions: { [string]: Action },
	States: { [string]: StateConfig },
	ToSeconds: (timeConfig: (TimeConfig | number)?) -> number
}

-- Stack protection and tracking instance (Reference Counting)
export type ActiveStateInstance = {
	Source: string,                       -- Key identifier of the source (e.g., "Spider_Poison_01")
	StartTime: number,                    -- os.clock() timestamp when applied
	Duration: number?,                    -- Optional duration limit
}

-- Player state registry kept in the server's memory
export type PlayerStateProfile = {
	ActiveStates: { [string]: {ActiveStateInstance} }, -- Map of StateName to an array of active sources
	ActiveDisables: { [Action]: number },              -- Tracks how many active states are blocking an action
	BaseStats: { [string]: number }                    -- Dynamic baseline stats (e.g., ["WalkSpeed"] = 16, ["Gravity"] = 196.2)
}

-- Highly compressed network replication packet
export type NetworkStatePayload = {
	[string]: {
		Active: boolean,
		StackCount: number
	}
}
-----------------------------
-- VARIABLES --
-----------------------------
local StateTypes = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StateTypes)