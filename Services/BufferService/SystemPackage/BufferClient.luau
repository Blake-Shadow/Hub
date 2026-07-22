--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Client-facing utility adapter for BufferService diagnostics.
]]
-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferService = require("./BufferService") :: any
local BufferTypes = require("./BufferTypes")

-----------------------------
-- TYPES --
-----------------------------
type TransportMode = BufferTypes.TransportMode

-----------------------------
-- VARIABLES --
-----------------------------
local BufferClient = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function BufferClient:SetDebugEnabled(enabled: boolean)
	BufferService:SetDebugEnabled(enabled)
end

function BufferClient:SetTransportMode(mode: TransportMode)
	BufferService:SetTransportMode(mode)
end

function BufferClient:GetTransportMode(): TransportMode
	return BufferService:GetTransportMode()
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(BufferClient)
