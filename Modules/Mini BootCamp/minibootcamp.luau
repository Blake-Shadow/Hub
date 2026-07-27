--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassService = require(ReplicatedStorage.Services.ClassService.SystemPackage.ClassService)
local EntityService = require(ReplicatedStorage.Services.EntityService.SystemPackage.EntityService)



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
    local syncData = ClassService.GetSyncData(instance)
    local model = ResolveEntityModel(instance)

    if type(syncData) ~= "table" then
        return
    end

    if not model then 
        return
    end

    EntityService.Apply(model, syncData)
end

local function UnBindPlayer(player: Player)
end

function BindPlayer(player: Player)
end