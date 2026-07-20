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
export type StatProperty = {
	Base: number,
	Modifiers: {
		Flat: number,
		Percent: number,
	},
	Total: number,
}

export type ResourceProperty = {
	Current: number,
	MaxStatKey: string,
}

export type ActorStatsProfile = {
	Registry: { [string]: StatProperty },
	ResourcesPool: { [string]: ResourceProperty },
}

-- Backward-compatibility aliases
export type StatProprety = StatProperty
export type ResourceProprety = ResourceProperty
-----------------------------
-- VARIABLES --
-----------------------------
local StatsType = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StatsType)
