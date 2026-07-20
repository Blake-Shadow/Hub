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
-- The data structure used for syncing attributes/properties
export type EntityStats = {[string]: any}

-- The structure for the registry (using Instance keys for the weak table)
export type Registry = {[Instance]: boolean}

-- Helpful definition for the sync handler callback used in Network
export type SyncCallback = (model: Model, data: EntityStats) -> ()
-----------------------------
-- VARIABLES --
-----------------------------
local EntityTypes = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(EntityTypes)