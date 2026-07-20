--!strict
--@author: Shadow
--@date: CREATION_DATE_HERE
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-----------------------------
-- DEPENDENCIES --
-----------------------------
local ClassTypes = require(ReplicatedStorage.Services.ClassService.SystemPackage.ClassTypes)
-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local Behavior: ClassTypes.ClassBehaviorFile = {
    FileMap = {},
}
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
return table.freeze(Behavior)