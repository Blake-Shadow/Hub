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
local BufferNetwork = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService)
local StoreCodecs = require("Codec/StoreCodecs")
-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local StoreNetwork = {}


-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildNetworkDirectory()
    local remotesFolder = ReplicatedStorage.Assets:FindFirstChild("Remotes") :: Folder
    if not remotesFolder then
        remotesFolder = Instance.new("Folder") :: Folder
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage.Assets
    end

    local storeFolder = remotesFolder:FindFirstChild("Store")
    if not storeFolder then
        storeFolder = Instance.new("Folder") :: Folder
        storeFolder.Name = "Store"
        storeFolder.Parent = remotesFolder
    end

    local RequestCatalog = storeFolder:FindFirstChild("RequestCatalog")
    if not RequestCatalog then
        RequestCatalog = Instance.new("RemoteFunction") :: RemoteFunction
        RequestCatalog.Name = "RequestCatalog"
        RequestCatalog.Parent = storeFolder
    end

end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------


return table.freeze(StoreNetwork)