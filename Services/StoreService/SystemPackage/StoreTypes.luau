--!strict
--@author: Shadow
--@date:
--[[@description:
    Shared store data contracts for catalog entries and purchase results.
]]
-----------------------------
-- TYPES --
-----------------------------
export type StoreItem = {
	Id: string,
	Name: string,
	Price: number,
	Description: string?,
	Currency: string?,
	ProductId: number?,
}

export type StoreCatalog = { [string]: StoreItem }

export type PurchaseResult = {
	Success: boolean,
	Message: string?,
	ItemId: string?,
	Quantity: number?,
	Granted: { [string]: any }?,
}

return {}
