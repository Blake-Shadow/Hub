--!strict
--@author: Shadow
--@date: CREATION_DATE_HERE
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
export type Key = Player | string | number

export type CacheEntry = {
    Data: any,
    IsLocked: boolean,
    IsDirty: boolean,
    LastUpdated: number,
    SessionToken: string?,
    HistoryLedger: {any},
}

export type RateLimitTracker = {
    RequestThisWindow: number,
    WindowStart: number,
}

export type SessionCache = {
    [number]: PlayerData,
}
-----------------------------
-- VARIABLES --
-----------------------------
local DataTypes = {}
-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- HANDLERS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(DataTypes)