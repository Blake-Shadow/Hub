--!strict
--@author: Shadow
--@date:
--[[@description:
    The core engine for managing entity data, persistence, and synchronization.
    Handles agnostic property/attribute application, registry lifecycle,
    and data inspection.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local EntityNetwork = require("./EntityNetwork")
local EntityTypes = require("./EntityTypes")
-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local EntityService = {}
local DEBUG_PRINT_ON_APPLY = true

-- Registry: Weak-valued table for automatic memory management.
-- If a Model is destroyed, it is removed from the registry automatically.
local activeEntities: EntityTypes.Registry = {}
setmetatable(activeEntities, { __mode = "k" })
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function ToStringValue(value: any): string
	local valueType = typeof(value)
	if valueType == "Vector3" or valueType == "Color3" or valueType == "CFrame" then
		return tostring(value)
	end

	if valueType == "table" then
		return "<table>"
	end

	return tostring(value)
end

local function PrintDictionary(prefix: string, dictionary: { [string]: any })
	local keys = {}
	for key in pairs(dictionary) do
		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in ipairs(keys) do
		print(string.format("[EntityService] %s %s = %s", prefix, key, ToStringValue(dictionary[key])))
	end
end

local function PrintEntityDebug(model: Model, appliedData: EntityTypes.EntityStats)
	print(string.format("[EntityService] ===== Entity Debug: %s =====", model:GetFullName()))
	PrintDictionary("AppliedStat", appliedData)
	PrintDictionary("Attribute", model:GetAttributes())
	print("[EntityService] =================================")
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
-- Applies a data dictionary to a model.
-- Agnostic: Tries to set Humanoid properties, falls back to Attributes.
function EntityService.Apply(model: Model, data: EntityTypes.EntityStats)
	if not model then
		return
	end
	activeEntities[model] = true

	local humanoid = model:FindFirstChildOfClass("Humanoid")

	for key, value in pairs(data) do
		local isProperty = false

		if humanoid then
			-- Safely attempt to assign the property on the Humanoid
			local success = pcall(function()
				(humanoid :: any)[key] = value
			end)
			isProperty = success
		end
		-- If it's not a valid/writable Humanoid property, write it as a Model Attribute
		if not isProperty then
			model:SetAttribute(key, value)
		end
	end
	-- Sync the state to the network
	EntityNetwork.SyncEntity(model, data)

	if DEBUG_PRINT_ON_APPLY then
		PrintEntityDebug(model, data)
	end
end

-- Safely retrieves data from a model without knowing if it's a property or attribute
function EntityService.Get(model: Model, key: string): any
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local success, result = pcall(function()
			return (humanoid :: any)[key]
		end)
		if success and result ~= nil then
			return result
		end
	end

	return model:GetAttribute(key)
end

-- Manually remove an entity from the tracking system
function EntityService.Destroy(model: Model)
	activeEntities[model] = nil
end

-- Check if an entity is currently being managed
function EntityService.Has(model: Model): boolean
	return activeEntities[model] ~= nil
end

-- Returns a copy of all attributes on the model
function EntityService.Snapshot(model: Model): { [string]: any }
	return model:GetAttributes()
end

function EntityService.DebugPrint(model: Model)
	PrintEntityDebug(model, EntityService.Snapshot(model))
end

-- Returns the full registry for batch operations
function EntityService.GetRegistry(): EntityTypes.Registry
	return (activeEntities :: any) :: EntityTypes.Registry
end

-- Initializes the service, prepares the network, and starts lifecycle monitoring
function EntityService.Init()
	-- Lifecycle hook: Automatic removal of destroyed entities
	game.DescendantRemoving:Connect(function(descendant)
		if not descendant:IsA("Model") then
			return
		end

		local model = descendant :: Model
		if activeEntities[model] then
			EntityService.Destroy(model)
		end
	end)
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(EntityService)
