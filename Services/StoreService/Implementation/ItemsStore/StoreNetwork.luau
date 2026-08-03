--!strict
--@author: Shadow
--@date:
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-----------------------------
-- DEPENDENCIES --
-----------------------------
local StoreCodecs = require(ReplicatedStorage.Services.StoreService.SystemPackage.Codecs.StoreCodecs)
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

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------

return table.freeze(StoreNetwork)
