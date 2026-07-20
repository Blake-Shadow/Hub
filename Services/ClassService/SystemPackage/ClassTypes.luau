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
export type Key = any

export type NodeCategory = "ActiveSkill" | "Passive"

export type IndividualSkillFile = {
	DisplayName: string,
	Description: string,
	BaseCooldown: number?,
	
	ResourceCost: {
		Type: string,
		Amount: number,
	}?,
	
	[string]: any 
}

export type ClassBehaviorFile = {
	FileMap: {[string]: {[string]: any}},
}

export type SkillTreeNode = {
	NodeName: string,
	Category: NodeCategory,
	MaxRank: number,
	RequiredLevel: number?,
	Dependencies: {string}?,
}

export type ClassConfig = {
	DisplayName: string,
	ParentClass: string?,
	
	-- Bases Stats for all classes
	BaseStats: {
		BaseMaxHealth: number,
		BaseWalkSpeed: number,
		[string]: number,
	},
	
	-- Resource config for different recourse usage for all classes
	PrimaryResource: {
		Type: string,
		BaseMaxAmount: number,
	},
	
	Behavior: ClassBehaviorFile?,
	Skills: {string},
	SkillTree: {SkillTreeNode},
}

export type ActiveEntityState = {
	ClassName: string,
	UnlockedSkills: {[string]: boolean},
	UnlockedSkillTree: {[string]: boolean},
}
-----------------------------
-- VARIABLES --
-----------------------------
local ClassTypes = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(ClassTypes)