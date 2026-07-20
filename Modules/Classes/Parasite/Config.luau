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
local ClassTypes = require(ReplicatedStorage.Services.ClassService.SystemPackage.ClassTypes)
-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local ParasiteConfig: ClassTypes.ClassConfig = {
	DisplayName = "Parasite",
	ParentClass = nil,
	BaseStats = {
		BaseMaxHealth = 2000,
		BaseWalkSpeed = 16,
		
		
	},
	PrimaryResource = {
		Type = "None",
		BaseMaxAmount = 0,
	},
	Skills = {}, 
	SkillTree = {},
	Behavior = nil :: any,
}
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(ParasiteConfig)