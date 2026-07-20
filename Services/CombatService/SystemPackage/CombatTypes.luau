--!strict
--@author: Shadow
--@date: 2026-07-19
--[[@description:
	Shared contracts for agnostic combat action execution.
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
export type CombatActionId = string

export type CombatActionRequestPayload = {
	ActionId: CombatActionId,
	Direction: Vector3?,
	Meta: { [string]: any }?,
}

export type CombatFeedbackPayload = {
	ActionId: CombatActionId,
	HitCount: number,
	TotalDamage: number,
	CriticalHits: number,
	Timestamp: number,
}

export type CombatActionConfig = {
	Cooldown: number,
	HitboxRadius: number,
	SkillPower: number,
	Variance: number,
	MinDamage: number,
	CritChance: number,
	CritMultiplier: number,
	AttackAttributeKey: string,
	DefenseAttributeKey: string,
}

export type CombatProfile = {
	CooldownEndsAt: { [CombatActionId]: number },
}

export type CombatAttributeKeys = {
	Attack: string,
	Defense: string,
	CurrentHealth: string,
	LastDamage: string,
	LastDamageCritical: string,
}

export type CombatNetworkConfig = {
	AssetsFolderName: string?,
	RemotesFolderName: string?,
	CombatFolderName: string?,
	ActionRequestRemoteName: string?,
	FeedbackRemoteName: string?,
}

export type HitboxTargetResolver = (attackerCharacter: Model, radius: number, direction: Vector3?) -> { Model }

export type CombatServiceInitConfig = {
	Actions: { [CombatActionId]: CombatActionConfig }?,
	AttributeKeys: CombatAttributeKeys?,
	HitboxTargetResolver: HitboxTargetResolver?,
	NetworkConfig: CombatNetworkConfig?,
}

-----------------------------
-- VARIABLES --
-----------------------------
local CombatTypes = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(CombatTypes)
