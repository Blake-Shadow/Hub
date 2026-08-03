--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Codec registry for StoreService transport.
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
-- VARIABLES --
-----------------------------
local StoreCodecs = {}

StoreCodecs.RequestCatalogRequestCodecName = "StoreRequestCatalogRequest"
StoreCodecs.RequestCatalogResponseCodecName = "StoreRequestCatalogResponse"
StoreCodecs.RequestPurchaseRequestCodecName = "StoreRequestPurchaseRequest"
StoreCodecs.RequestPurchaseResponseCodecName = "StoreRequestPurchaseResponse"

local codecsRegistered = false
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildRequestCatalogRequestCodec()
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
		if payload.RequestType ~= "GetCatalog" then
			return false, "RequestType must be 'GetCatalog'"
		end
		return true, nil
	end
	return codec
end

local function BuildRequestCatalogResponseCodec()
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
		if type(payload.Catalog) ~= "table" then
			return false, "Catalog must be a table"
		end
		return true, nil
	end
	return codec
end

local function BuildRequestPurchaseRequestCodec()
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
		if type(payload.ItemId) ~= "string" or payload.ItemId == "" then
			return false, "ItemId must be a non-empty string"
		end
		if type(payload.Quantity) ~= "number" then
			return false, "Quantity must be a number"
		end
		return true, nil
	end
	return codec
end

local function BuildRequestPurchaseResponseCodec()
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
		if type(payload.Result) ~= "table" then
			return false, "Result must be a table"
		end
		if type(payload.Result.Success) ~= "boolean" then
			return false, "Result.Success must be a boolean"
		end
		return true, nil
	end
	return codec
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function StoreCodecs.BuildCatalogRequestPayload(): { [string]: any }
	return {
		RequestType = "GetCatalog",
	}
end

function StoreCodecs.WrapCatalogPayload(catalog: { [string]: any }): { [string]: any }
	return {
		Catalog = catalog,
	}
end

function StoreCodecs.UnwrapCatalogPayload(payload: any): { [string]: any }
	if type(payload) == "table" and type(payload.Catalog) == "table" then
		return payload.Catalog
	end

	return {}
end

function StoreCodecs.BuildPurchaseRequestPayload(itemId: string, quantity: number): { [string]: any }
	return {
		ItemId = itemId,
		Quantity = math.max(1, quantity),
	}
end

function StoreCodecs.ExtractPurchaseRequestPayload(payload: any): (string?, number?)
	if type(payload) ~= "table" then
		return nil, nil
	end

	local itemId = payload.ItemId
	local quantity = payload.Quantity
	if type(itemId) ~= "string" or itemId == "" then
		return nil, nil
	end
	if type(quantity) ~= "number" then
		return nil, nil
	end

	return itemId, math.max(1, quantity)
end

function StoreCodecs.WrapPurchaseResponse(result: { [string]: any }): { [string]: any }
	return {
		Result = result,
	}
end

function StoreCodecs.UnwrapPurchaseResponse(payload: any): { [string]: any }
	if type(payload) == "table" and type(payload.Result) == "table" then
		return payload.Result
	end

	return {
		Success = false,
		Message = "Invalid purchase response payload.",
	}
end

function StoreCodecs.EnsureRegistered()
	if codecsRegistered then
		return
	end

	BufferService:RegisterCodec(StoreCodecs.RequestCatalogRequestCodecName, BuildRequestCatalogRequestCodec())
	BufferService:RegisterCodec(StoreCodecs.RequestCatalogResponseCodecName, BuildRequestCatalogResponseCodec())
	BufferService:RegisterCodec(StoreCodecs.RequestPurchaseRequestCodecName, BuildRequestPurchaseRequestCodec())
	BufferService:RegisterCodec(StoreCodecs.RequestPurchaseResponseCodecName, BuildRequestPurchaseResponseCodec())
	codecsRegistered = true
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StoreCodecs)
