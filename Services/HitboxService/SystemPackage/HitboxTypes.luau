--!strict
--@author: Shadow
--@date: 2026/07/01
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
export type ShapeType = "Block" | "Sphere" | "Cylinder" | "Raycast" | "Cone"
export type FilterFunction = (target: Model) -> boolean
export type HitCallback = (target: Model) -> ()

export type HitboxConfig = {
	_shape: ShapeType,
	_size: Vector3,              
	_radius: number,             
	_angle: number,              
	_source: Instance?,
	_offset: CFrame,
	_ignoreList: {Instance},
	_filterPredicate: FilterFunction?,
	_growthRate: number,         
}
-----------------------------
-- VARIABLES --
-----------------------------
local HitboxTypes = {}

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(HitboxTypes)