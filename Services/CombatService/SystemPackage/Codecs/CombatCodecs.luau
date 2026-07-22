--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Small combat codec registry that delegates codec building.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local BufferService = require(ReplicatedStorage.Services.BufferService.SystemPackage.BufferService) :: any
local CombatActionRequestCodec = require("./CombatActionRequestCodec")
local CombatFeedbackCodec = require("./CombatFeedbackCodec")

-----------------------------
-- TYPES --
-----------------------------
-- VARIABLES --
-----------------------------
local CombatCodecs = {}

CombatCodecs.ActionRequestCodecName = "CombatActionRequest"
CombatCodecs.FeedbackCodecName = "CombatFeedback"

local codecsRegistered = false
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function CombatCodecs.EnsureRegistered()
	if codecsRegistered then
		return
	end

	BufferService:RegisterCodec(CombatCodecs.ActionRequestCodecName, CombatActionRequestCodec.Build())
	BufferService:RegisterCodec(CombatCodecs.FeedbackCodecName, CombatFeedbackCodec.Build())
	codecsRegistered = true
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(CombatCodecs)
