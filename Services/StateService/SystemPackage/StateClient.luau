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
local StateNetwork = require("./StateNetwork") :: any
local StateTypes = require("./StateTypes")
-----------------------------
-- TYPES --
-----------------------------
type NetworkStatePayload = StateTypes.NetworkStatePayload
-----------------------------
-- VARIABLES --
-----------------------------
local StateClient = {}

-- Local mirror of the server's state profile
local activeStates: NetworkStatePayload = {}
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-- Callback triggered when the server pushes a new state update
local function OnStateReplicated(payload: NetworkStatePayload)
	activeStates = payload
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
--[[ Checks if a specific state is currently active ]]
function StateClient:IsStateActive(stateName: string): boolean
	local data = activeStates[stateName]
	return data ~= nil and data.Active == true
end

--[[ Returns the number of stacks for a state ]]
function StateClient:GetStackCount(stateName: string): number
	local data = activeStates[stateName]
	return data and data.StackCount or 0
end

--[[ Dispatches an action request to the server (e.g., triggering a custom Ability) ]]
function StateClient:RequestAction(actionName: string, data: any)
	StateNetwork:RequestAction(actionName, data)
end

function StateClient:Init()
	-- Register the replication handler with the Network layer
	StateNetwork:RegisterReplicationHandler(function(payload: NetworkStatePayload)
		OnStateReplicated(payload)
	end)

	StateNetwork:Init()
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StateClient)