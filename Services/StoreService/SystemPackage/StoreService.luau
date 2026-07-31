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
local StoreNetwork = require("./StoreNetwork")
local StoreTypes = require("./StoreTypes")

-----------------------------
-- TYPES --
-----------------------------
type StoreItem = StoreTypes.StoreItem
type StoreCatalog = StoreTypes.StoreCatalog
type PurchaseResult = StoreTypes.PurchaseResult

-----------------------------
-- VARIABLES --
-----------------------------
local StoreService = {}
local catalog: StoreCatalog = {}
local purchaseHandler: ((Player, StoreItem, number) -> PurchaseResult)? = nil
local hasInitialized = false
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function CloneCatalog(source: StoreCatalog): StoreCatalog
	local clone: StoreCatalog = {}
	for itemId, item in pairs(source) do
		clone[itemId] = table.clone(item)
	end

	return clone
end

local function ResolveCatalogItem(itemId: string): StoreItem?
	local item = catalog[itemId]
	if not item then
		return nil
	end

	return item
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function StoreService.SetCatalog(nextCatalog: StoreCatalog)
	catalog = CloneCatalog(nextCatalog)
end

function StoreService.RegisterItem(item: StoreItem)
	if not item.Id or item.Id == "" then
		error("[StoreService] Cannot register a store item without an Id.")
	end

	catalog[item.Id] = table.clone(item)
end

function StoreService.GetCatalog(): StoreCatalog
	return CloneCatalog(catalog)
end

function StoreService.SetPurchaseHandler(handler: (Player, StoreItem, number) -> PurchaseResult)
	purchaseHandler = handler
end

function StoreService.HandlePurchaseRequest(player: Player, itemId: string, quantity: number): PurchaseResult
	local item = ResolveCatalogItem(itemId)
	if not item then
		return {
			Success = false,
			Message = string.format("Unknown store item: %s", itemId),
			ItemId = itemId,
			Quantity = quantity,
		}
	end

	if not purchaseHandler then
		return {
			Success = false,
			Message = "No store purchase handler has been configured.",
			ItemId = itemId,
			Quantity = quantity,
		}
	end

	return purchaseHandler(player, item, math.max(1, quantity))
end

function StoreService.Init()
	if hasInitialized then
		return
	end

	hasInitialized = true

	StoreNetwork.SetCatalogProvider(StoreService.GetCatalog)
	StoreNetwork.SetPurchaseHandler(StoreService.HandlePurchaseRequest)
	StoreNetwork.Init()
end

-----------------------------
-- MAIN --
-----------------------------
StoreService.Init()

return table.freeze(StoreService)