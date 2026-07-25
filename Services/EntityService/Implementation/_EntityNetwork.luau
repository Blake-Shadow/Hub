--!strict
--@author: Shadow
--@date:
--[[@description:
    Temporary bridge that applies class sync data to an entity model.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-----------------------------
-- DEPENDENCIES --
-----------------------------

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local _EntityNetwork = {}

local isInitialized = false
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function BuildNetworkDirectory()
    local remotesFolder = ReplicatedStorage.Assets:FindFirstChild("Remotes") :: Folder
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        if remotesFolder then
            remotesFolder.Name = "Remotes"
            remotesFolder.Parent = ReplicatedStorage.Assets
        end
    end

    local _entityFolder = remotesFolder:FindFirstChild("_Entity") :: Folder
    if not _entityFolder then
        _entityFolder = Instance.new("Folder")
        if _entityFolder then
            _entityFolder.Name = "_Entity"
            _entityFolder.Parent = remotesFolder
        end
    end
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------



-----------------------------
-- MAIN --
-----------------------------


return table.freeze(_EntityNetwork)