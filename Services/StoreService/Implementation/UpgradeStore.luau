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
local StoreService = require("../SystemPackage/StoreService")
local StoreClient = require("../SystemPackage/StoreClient")
local StoreTypes = require("../SystemPackage/StoreTypes")
-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local UpgradeStore = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(UpgradeStore)