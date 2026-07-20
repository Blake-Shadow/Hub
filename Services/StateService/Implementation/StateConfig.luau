--!strict
--@author: Shadow
--@date: CREATION_DATE_HERE
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local StateTypes = require("../SystemPackage/StateTypes")
-----------------------------
-- TYPES --
-----------------------------
type MasterConfig = StateTypes.MasterConfig
-----------------------------
-- VARIABLES --
-----------------------------
local StateConfig: MasterConfig = {
    Actions = {
        ["Jump"] = "Jump",
        ["Attack"] = "Attack"
    },
    States = {
        ["Stunnned"] = {
            Priority = 1,
            Stackable = false,
            KeepOnDeath = false,
            SaveOnExit = false,
            Disables = {"Jump", "Attack",},
            Modifiers = {
                ["BaseWalkSpeed"] = {Multiply = 0}
            },
        },
    },
    	ToSeconds = function(timeConfig: (StateTypes.TimeConfig | number)?)
		if not timeConfig then return 0 end
		if typeof(timeConfig) == "number" then
			return timeConfig
		end
		local tc = timeConfig :: StateTypes.TimeConfig
		return (tc.Hours or 0) * 3600 + (tc.Minutes or 0) * 60 + (tc.Seconds or 0)
	end,
}


-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-----------------------------
-- HANDLERS --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(StateConfig)