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
local HealerConfig: ClassTypes.ClassConfig = {
	DisplayName = "Healer",
	ParentClass = nil,
	BaseStats = {
		BaseMaxHealth = 140,
		BaseWalkSpeed = 14,
		BasePower = 22,
		BaseDefense = 8,
	},
	PrimaryResource = {
		Type = "Mana",
		BaseMaxAmount = 120,
	},
	Behavior = nil,
	Skills = {},
	SkillTree = {},
}

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(HealerConfig)
