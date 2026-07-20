--!strict
--@author: Shadow
--@date:
--[[@description:
    The client-side receiver for Entity synchronization.
    Provides a hook for UI/VFX updates and maintains a local cache of active entities.
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
local EntityClient = {}

-- Local registry: Keeps track of entities the client has received data for.
local activeEntities: EntityTypes.Registry = {}
setmetatable(activeEntities, { __mode = "k" })

-- The listener hook: Other scripts will define what happens when data arrives here
local onUpdateCallback: ((model: Model, data: EntityTypes.EntityStats) -> ())? = nil
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
-- Define the logic for when data is received from the server
function EntityClient.OnUpdate(callback: (model: Model, data: EntityTypes.EntityStats) -> ())
	onUpdateCallback = callback
end

-- Safely retrieves data from a model locally
-- (Useful for checking stats for UI rendering)
function EntityClient.Get(model: Model, key: string): any
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

-- Check if the client knows about this entity
function EntityClient.Has(model: Model): boolean
	return activeEntities[model] ~= nil
end

-- Returns the full registry of entities the client has synced with
function EntityClient.GetRegistry(): EntityTypes.Registry
	return (activeEntities :: any) :: EntityTypes.Registry
end

-- Initializes the network listener
function EntityClient.Init()
	-- The glue: Link the Network's callback to our client logic
	EntityNetwork.SetSyncHandler(function(model: Model, data: EntityTypes.EntityStats)
		-- Update our local registry
		activeEntities[model] = true

		-- Fire the custom logic provided by other scripts
		if onUpdateCallback then
			onUpdateCallback(model, data)
		end
	end)

	-- Lifecycle hook: Remove from local registry if the entity is destroyed
	game.DescendantRemoving:Connect(function(descendant)
		if activeEntities[descendant] then
			activeEntities[descendant] = nil
		end
	end)

	EntityNetwork.Init()
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(EntityClient)