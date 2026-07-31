--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Codec registry for ClassService transport.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferService = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService) :: any
-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local StoreCodecs = {}

StoreCodecs.RequestCatalogCodecName = "RequestCatalog"
StoreCodecs.RequestPurchaseCodecName = "RequestPurchase"

local codecsRegistered = false
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildAllocateNodeCodec()
	local codec = BufferService:CreateCodecTemplate(1)
	codec.TransportMode = "Table"
	codec.Encode = function(payload: any): any
		return payload
	end
	codec.Decode = function(payload: any): any
		return payload
	end
	codec.Validate = function(payload: any): (boolean, string?)
		if type(payload) ~= "table" then
			return false, "payload must be a table"
		end
		if type(payload.NodeName) ~= "string" or payload.NodeName == "" then
			return false, "NodeName must be a non-empty string"
		end
		return true, nil
	end
	return codec
end

local function BuildSyncProfileCodec()
	local codec = BufferService:CreateCodecTemplate(1)
	codec.TransportMode = "Table"
	codec.Encode = function(payload: any): any
		return payload
	end
	codec.Decode = function(payload: any): any
		return payload
	end
	codec.Validate = function(payload: any): (boolean, string?)
		if type(payload) ~= "table" then
			return false, "payload must be a table"
		end
		if type(payload.HasProfile) ~= "boolean" then
			return false, "HasProfile must be a boolean"
		end
		return true, nil
	end
	return codec
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StoreCodecs)
