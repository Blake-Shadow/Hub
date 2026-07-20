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
local SporesConfig: ClassTypes.ClassConfig = {
	DisplayName = "Spores",
	ParentClass = nil,
	BaseStats = {
		BaseMaxHealth = 180,
		BaseWalkSpeed = 13,
		BasePower = 24,
		BaseDefense = 12,
	},
	PrimaryResource = {
		Type = "Spores",
		BaseMaxAmount = 130,
	},
	Behavior = nil,
	Skills = {},
	SkillTree = {},
}

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(SporesConfig)
