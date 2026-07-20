--!strict
--@author: Shadow
--@date: 2026-07-19
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
local RangerConfig: ClassTypes.ClassConfig = {
	DisplayName = "Ranger",
	ParentClass = nil,
	BaseStats = {
		BaseMaxHealth = 160,
		BaseWalkSpeed = 16,
		BasePower = 20,
		BaseDefense = 10,
	},
	PrimaryResource = {
		Type = "Stamina",
		BaseMaxAmount = 110,
	},
	Behavior = nil,
	Skills = {},
	SkillTree = {},
}

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(RangerConfig)
