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
type CatalogUpdatedHandler = (catalog: StoreCatalog) -> ()

-----------------------------
-- VARIABLES --
-----------------------------
local StoreClient = {}
local cachedCatalog: StoreCatalog = {}
local hasInitialized = false
local catalogUpdatedHandlers: { CatalogUpdatedHandler } = {}

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

local function NotifyCatalogUpdated()
	local snapshot = CloneCatalog(cachedCatalog)
	for _, handler in ipairs(catalogUpdatedHandlers) do
		task.spawn(handler, snapshot)
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function StoreClient.RefreshCatalog(): StoreCatalog
	local latestCatalog = StoreNetwork.RequestCatalog()
	cachedCatalog = CloneCatalog(latestCatalog)
	NotifyCatalogUpdated()

	return CloneCatalog(cachedCatalog)
end

function StoreClient.GetCatalog(): StoreCatalog
	return CloneCatalog(cachedCatalog)
end

function StoreClient.GetItem(itemId: string): StoreItem?
	local item = cachedCatalog[itemId]
	if not item then
		return nil
	end

	return table.clone(item)
end

function StoreClient.Purchase(itemId: string, quantity: number): PurchaseResult
	return StoreNetwork.RequestPurchase(itemId, math.max(1, quantity))
end

function StoreClient.OnCatalogUpdated(handler: CatalogUpdatedHandler): () -> ()
	table.insert(catalogUpdatedHandlers, handler)

	return function()
		for index, existingHandler in ipairs(catalogUpdatedHandlers) do
			if existingHandler == handler then
				table.remove(catalogUpdatedHandlers, index)
				break
			end
		end
	end
end

function StoreClient.Init()
	if hasInitialized then
		return
	end

	hasInitialized = true
	StoreClient.RefreshCatalog()
end
-----------------------------
-- MAIN --
-----------------------------
StoreClient.Init()

return table.freeze(StoreClient)
