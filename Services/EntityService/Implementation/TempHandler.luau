--!strict
--@author: Shadow
--@date:
--[[@description:
    Temporary bridge that applies class sync data to an entity model.
]]
-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local ClassService = require(ReplicatedStorage.Services.ClassService.SystemPackage.ClassService)
local EntityService = require(ReplicatedStorage.Services.EntityService.SystemPackage.EntityService)

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local TempHandler = {}
local isInitialized = false

local playerConnections: { [Player]: RBXScriptConnection } = {}

setmetatable(playerConnections, { __mode = "k" })

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function PrintAppliedData(instance: Instance, syncData: { [string]: any })
    print(string.format("[TempHandler] Applied class data to %s", instance.Name))

    local keys = {}
    for key in pairs(syncData) do
        table.insert(keys, key)
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        print(string.format("[TempHandler] %s = %s", key, tostring(syncData[key])))
    end
end

local function ResolveEntityModel(instance: Instance): Model?
    if instance:IsA("Player") then
        return instance.Character
    end

    if instance:IsA("Model") then
        return instance
    end

    return nil
end

local function ApplyClassSnapshot(instance: Instance)
    local model = ResolveEntityModel(instance)
    if not model then
        return
    end

    local syncData = ClassService.GetSyncData(instance)
    EntityService.Apply(model, syncData)
    PrintAppliedData(instance, syncData)
end

local function BindPlayer(player: Player)
    local existingConnection = playerConnections[player]
    if existingConnection then
        existingConnection:Disconnect()
        playerConnections[player] = nil
    end

    playerConnections[player] = player.CharacterAdded:Connect(function()
        ApplyClassSnapshot(player)
    end)

    ApplyClassSnapshot(player)
end

local function ApplyExistingEntities()
    for instance in pairs(EntityService.GetRegistry()) do
        ApplyClassSnapshot(instance)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        BindPlayer(player)
    end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function TempHandler.Init()
    if isInitialized then
        return
    end

    isInitialized = true

    ClassService.RegisterClassChangedHandler(function(instance: Instance, _className: string)
        ApplyClassSnapshot(instance)
    end)

    Players.PlayerAdded:Connect(BindPlayer)
    Players.PlayerRemoving:Connect(function(player: Player)
        local connection = playerConnections[player]
        if connection then
            connection:Disconnect()
            playerConnections[player] = nil
        end
    end)

    ApplyExistingEntities()
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(TempHandler)