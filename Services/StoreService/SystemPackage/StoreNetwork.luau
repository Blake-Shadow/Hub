--!strict
--@author: Shadow
--@date:
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferNetwork = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferNetwork) :: any
local StoreCodecs = require("./Codecs/StoreCodecs")
local StoreTypes = require("./StoreTypes")
-----------------------------
-- TYPES --
-----------------------------
type StoreCatalog = StoreTypes.StoreCatalog
type PurchaseResult = StoreTypes.PurchaseResult

-----------------------------
-- VARIABLES --
-----------------------------
local StoreNetwork = {}

StoreNetwork.RequestCatalogRemote = nil :: any
StoreNetwork.RequestPurchaseRemote = nil :: any

local activeCatalogProvider: (() -> StoreCatalog)? = nil
local activePurchaseHandler: ((player: Player, itemId: string, quantity: number) -> PurchaseResult)? = nil
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildNetworkDirectory(): (RemoteFunction, RemoteFunction)
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		assetsFolder = Instance.new("Folder")
		assetsFolder.Name = "Assets"
		assetsFolder.Parent = ReplicatedStorage
	end
	local resolvedAssets = assetsFolder :: Folder

	local remotesFolder = resolvedAssets:FindFirstChild("Remotes")
	if not remotesFolder then
		local createdRemotesFolder = Instance.new("Folder")
		createdRemotesFolder.Name = "Remotes"
		createdRemotesFolder.Parent = resolvedAssets
		remotesFolder = createdRemotesFolder
	end
	local resolvedRemotes = remotesFolder :: Folder

	local storeFolder = resolvedRemotes:FindFirstChild("Store")
	if not storeFolder then
		local createdStoreFolder = Instance.new("Folder")
		createdStoreFolder.Name = "Store"
		createdStoreFolder.Parent = resolvedRemotes
		storeFolder = createdStoreFolder
	end
	local resolvedStoreFolder = storeFolder :: Folder

	local requestCatalog = resolvedStoreFolder:FindFirstChild("RequestCatalog")
	if not requestCatalog then
		local createdRequestCatalog = Instance.new("RemoteFunction")
		createdRequestCatalog.Name = "RequestCatalog"
		createdRequestCatalog.Parent = resolvedStoreFolder
		requestCatalog = createdRequestCatalog
	end
	local resolvedRequestCatalog = requestCatalog :: RemoteFunction

	local requestPurchase = resolvedStoreFolder:FindFirstChild("RequestPurchase")
	if not requestPurchase then
		local createdRequestPurchase = Instance.new("RemoteFunction")
		createdRequestPurchase.Name = "RequestPurchase"
		createdRequestPurchase.Parent = resolvedStoreFolder
		requestPurchase = createdRequestPurchase
	end
	local resolvedRequestPurchase = requestPurchase :: RemoteFunction

	if RunService:IsClient() then
		return resolvedStoreFolder:WaitForChild("RequestCatalog") :: RemoteFunction,
			resolvedStoreFolder:WaitForChild("RequestPurchase") :: RemoteFunction
	end

	return resolvedRequestCatalog, resolvedRequestPurchase
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function StoreNetwork.SetCatalogProvider(provider: () -> StoreCatalog)
	activeCatalogProvider = provider
end

function StoreNetwork.SetPurchaseHandler(handler: (player: Player, itemId: string, quantity: number) -> PurchaseResult)
	activePurchaseHandler = handler
end

function StoreNetwork.RequestCatalog(): StoreCatalog
	StoreCodecs.EnsureRegistered()
	local ok, responsePayload = BufferNetwork.InvokeServer(
		StoreNetwork.RequestCatalogRemote,
		StoreCodecs.RequestCatalogRequestCodecName,
		StoreCodecs.RequestCatalogResponseCodecName,
		StoreCodecs.BuildCatalogRequestPayload()
	)

	if not ok then
		return {}
	end

	return (StoreCodecs.UnwrapCatalogPayload(responsePayload) :: any) :: StoreCatalog
end

function StoreNetwork.RequestPurchase(itemId: string, quantity: number): PurchaseResult
	StoreCodecs.EnsureRegistered()
	local ok, responsePayload = BufferNetwork.InvokeServer(
		StoreNetwork.RequestPurchaseRemote,
		StoreCodecs.RequestPurchaseRequestCodecName,
		StoreCodecs.RequestPurchaseResponseCodecName,
		StoreCodecs.BuildPurchaseRequestPayload(itemId, quantity)
	)

	if not ok then
		return {
			Success = false,
			Message = "Store purchase request failed.",
			ItemId = itemId,
			Quantity = quantity,
		}
	end

	return (StoreCodecs.UnwrapPurchaseResponse(responsePayload) :: any) :: PurchaseResult
end

function StoreNetwork.Init()
	StoreCodecs.EnsureRegistered()

	if RunService:IsServer() then
		BufferNetwork.BindServerInvoke(
			StoreNetwork.RequestCatalogRemote,
			StoreCodecs.RequestCatalogRequestCodecName,
			StoreCodecs.RequestCatalogResponseCodecName,
			function(_player: Player, _payload: any)
				if not activeCatalogProvider then
					return StoreCodecs.WrapCatalogPayload({})
				end

				return StoreCodecs.WrapCatalogPayload(activeCatalogProvider())
			end,
			StoreCodecs.WrapCatalogPayload({})
		)

		BufferNetwork.BindServerInvoke(
			StoreNetwork.RequestPurchaseRemote,
			StoreCodecs.RequestPurchaseRequestCodecName,
			StoreCodecs.RequestPurchaseResponseCodecName,
			function(player: Player, payload: any)
				local itemId, requestedQuantity = StoreCodecs.ExtractPurchaseRequestPayload(payload)
				if not itemId or not requestedQuantity then
					return StoreCodecs.WrapPurchaseResponse({
						Success = false,
						Message = "Invalid store purchase payload.",
					})
				end

				if not activePurchaseHandler then
					return StoreCodecs.WrapPurchaseResponse({
						Success = false,
						Message = "No store purchase handler configured.",
						ItemId = itemId,
						Quantity = requestedQuantity,
					})
				end

				return StoreCodecs.WrapPurchaseResponse(activePurchaseHandler(player, itemId, requestedQuantity))
			end,
			StoreCodecs.WrapPurchaseResponse({
				Success = false,
				Message = "Store purchase request failed.",
			})
		)
	end
end
-----------------------------
-- MAIN --
-----------------------------
local requestCatalog, requestPurchase = BuildNetworkDirectory()

StoreNetwork.RequestCatalogRemote = requestCatalog
StoreNetwork.RequestPurchaseRemote = requestPurchase

return table.freeze(StoreNetwork)
