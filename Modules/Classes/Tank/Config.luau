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
local TankConfig: ClassTypes.ClassConfig = {
	DisplayName = "Tank",
	ParentClass = nil,
	BaseStats = {
		BaseMaxHealth = 200,
		BaseWalkSpeed = 12,
	},
	PrimaryResource = {
		Type = "Spores",
		BaseMaxAmount = 100,
	},
	Behavior = nil,
	Skills = {},
	SkillTree = {},
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
return table.freeze(TankConfig)