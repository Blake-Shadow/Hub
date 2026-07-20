--!strict
--@author: Shadow
--@date: 2026/07/18
--[[@description:
	Shared contracts for unified movement + parkour runtime.
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
export type MovementMode = "Core" | "Parkour"

export type CoreAction = "RunToggle" | "Dodge"
export type ParkourAction = "Vault" | "WallRun" | "Climb" | "Slide"
export type MovementAction = CoreAction | ParkourAction

export type ModeFlags = {
	Core: boolean,
	Parkour: boolean,
}

export type ActionCooldownMap = {
	[MovementAction]: number,
}

export type CoreConfig = {
	BaseFallbackWalkSpeed: number,
	BaseWalkSpeedAttributeKey: string,
	RunMultiplier: number,
	RunFlatBonus: number,
	DodgeImpulse: number,
	DodgeDuration: number,
	DodgeCooldown: number,
}

export type ParkourConfig = {
	VaultEnabled: boolean,
	WallRunEnabled: boolean,
	ClimbEnabled: boolean,
	SlideEnabled: boolean,
	VaultImpulse: number,
	WallRunSpeed: number,
	ClimbSpeed: number,
	SlideImpulse: number,
}

export type MovementConfig = {
	ModesDefault: ModeFlags,
	Core: CoreConfig,
	Parkour: ParkourConfig,
	Cooldowns: ActionCooldownMap,
}

export type ActionRequestPayload = {
	Action: MovementAction,
	Direction: Vector3?,
	Meta: { [string]: any }?,
}

export type RunToggleRequestPayload = {
	Enabled: boolean,
}

export type ActorMovementProfile = {
	EnabledModes: ModeFlags,
	IsRunning: boolean,
	ActiveAction: MovementAction?,
	CooldownEndsAt: ActionCooldownMap,
	LastDirection: Vector3,
}

export type NetworkMovementSnapshot = {
	EnabledModes: ModeFlags,
	IsRunning: boolean,
	ActiveAction: MovementAction?,
	CooldownEndsAt: ActionCooldownMap,
}

-----------------------------
-- VARIABLES --
-----------------------------
local MovementTypes = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(MovementTypes)
