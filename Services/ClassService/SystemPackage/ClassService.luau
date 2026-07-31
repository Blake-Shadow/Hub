--!strict
--@author: Shadow
--@date: 2026-07-13
--[[@description:
	The main orchestration hub for the agnostic character class framework.
	Manages player progression profiles, talent allocation validation, data-driven 
	directory scraping registration, and network state synchronization pipelines.
]]
-----------------------------
-- SERVICES --
-----------------------------
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-----------------------------
-- DEPENDENCIES --
-----------------------------
local DataService = require(ReplicatedStorage.Services.DataService.SystemPackage.DataService)
local ClassNetwork = require("./ClassNetwork")
local ClassTypes = require("./ClassTypes")
-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local ClassService = {}
-- Static runtime schema configuration database
local classRegistry: { [string]: ClassTypes.ClassConfig } = {}
local activeEntityProfiles: { [Instance]: ClassTypes.ActiveEntityState } = {}
local entityDataKeys: { [Instance]: string } = {}
local classChangedHandlers: { (instance: Instance, className: string) -> () } = {}
local DEBUG_PRINT_SYNC_DATA = false
local hasInitialized = false

setmetatable(activeEntityProfiles, { __mode = "k" })
setmetatable(entityDataKeys, { __mode = "k" })

-- Constant data path keys used inside DataService mutations
local PROFILE_DATA_PATH = "ClassProfile"
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-- Recursively deep freezes tables to optimize memory allocation frames
local function DeepFreeze(target: any)
	if type(target) ~= "table" then
		return
	end
	if table.isfrozen(target) then
		return
	end

	for _, value in pairs(target) do
		if type(value) == "table" then
			DeepFreeze(value)
		end
	end
	table.freeze(target)
end

local function PrintStatTable(prefix: string, stats: { [string]: any })
	local keys = {}
	for key in pairs(stats) do
		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in ipairs(keys) do
		print(string.format("[ClassService] %s %s = %s", prefix, key, tostring(stats[key])))
	end
end

local function GetBaseStats(className: string): { [string]: any }?
	local config = classRegistry[className]
	if not config then
		return nil
	end

	local rawConfig = config :: any
	if rawConfig and rawConfig.BaseStats then
		return rawConfig.BaseStats
	end

	return nil
end

local function BuildSyncData(instance: Instance): { [string]: any }
	local state = activeEntityProfiles[instance]
	local className = if state then state.ClassName else "None"
	local baseStats = GetBaseStats(className)
	local skillsCount = 0

	if state then
		for _ in state.UnlockedSkills do
			skillsCount += 1
		end
	end

	return {
		ClassName = className,
		ActiveSkillsCount = skillsCount,
		BaseMaxHealth = if baseStats and baseStats.BaseMaxHealth then baseStats.BaseMaxHealth else 100,
		BaseWalkSpeed = if baseStats and baseStats.BaseWalkSpeed then baseStats.BaseWalkSpeed else 16,
	}
end

local function DebugPrintSyncData(instance: Instance, syncData: { [string]: any })
	if not DEBUG_PRINT_SYNC_DATA then
		return
	end

	local state = activeEntityProfiles[instance]
	local className = if state then state.ClassName else "None"
	print(string.format("[ClassService] SyncData for %s (%s)", instance.Name, className))
	PrintStatTable("SyncStat", syncData)
end

local function DebugPrintClassStats(className: string, config: ClassTypes.ClassConfig)
	if not DEBUG_PRINT_SYNC_DATA then
		return
	end

	local baseStats = config.BaseStats
	print(string.format("[ClassService] Loaded class stats for %s", className))
	PrintStatTable("BaseStat", {
		ClassName = className,
		BaseMaxHealth = baseStats.BaseMaxHealth,
		BaseWalkSpeed = baseStats.BaseWalkSpeed,
	})
end

-- Programmatically gathers behavior variables from active folder instances
local function ScrapeClassDirectories(classFolder: Folder): ClassTypes.ClassBehaviorFile
	local behaviorFile: ClassTypes.ClassBehaviorFile = { FileMap = {} }

	local function ProcessFolder(folderName: string)
		local folder = classFolder:FindFirstChild(folderName)
		if not folder then
			return
		end

		for _, moduleScript in ipairs(folder:GetChildren()) do
			if not moduleScript:IsA("ModuleScript") then
				continue
			end

			local success, data = pcall(require, moduleScript)
			if success and type(data) == "table" then
				behaviorFile.FileMap[moduleScript.Name] = data
			else
				warn(string.format("[ClassService] Scraper dropped module: %s/%s", classFolder.Name, moduleScript.Name))
			end
		end
	end

	ProcessFolder("Skills")
	ProcessFolder("SkillTree")

	return behaviorFile
end

local function GetEntityDataKey(instance: Instance): string
	local existingKey = entityDataKeys[instance]
	if existingKey then
		return existingKey
	end

	local key: string
	if instance:IsA("Player") then
		key = "Player:" .. tostring(instance.UserId)
	else
		key = "NPC:" .. HttpService:GenerateGUID(false)
	end

	entityDataKeys[instance] = key
	return key
end

-- Synchronizes a player's progression state snapshot out across the pipeline
local function ReplicateProfileState(instance: Instance)
	local state = activeEntityProfiles[instance]
	if not state then
		return
	end

	-- ONLY sync network if the instance is a player
	if instance:IsA("Player") then
		ClassNetwork.SyncClassProfile(instance, state)
	end
end

local function NotifyClassChanged(instance: Instance, className: string)
	for _, handler in ipairs(classChangedHandlers) do
		task.spawn(handler, instance, className)
	end
end

-- Validates progression boundaries before allocating talent tree nodes
local function ProcessAllocationRequest(player: Player, _nodeName: string)
	-- This remains Player-specific because NPCs don't use DataService persistence
	local entityState = activeEntityProfiles[player]
	if not entityState then
		return
	end

	-- [Rest of your validation logic remains the same...]
	-- (Ensure you call ReplicateProfileState(player) at the end)
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
-- Retrieves the compiled dynamic behavior attributes of a class module
function ClassService.GetBehaviorMap(className: string): ClassTypes.ClassBehaviorFile?
	local config = classRegistry[className]
	return config and config.Behavior
end

-- Returns the active runtime progression state tracking a live player instance
function ClassService.GetEntityState(instance: Instance): ClassTypes.ActiveEntityState?
	return activeEntityProfiles[instance]
end

-- Setup and initialize entity session records
function ClassService.LoadEntity(instance: Instance)
	local classData: any
	local dataKey = GetEntityDataKey(instance)

	classData = DataService.GetPath(dataKey, PROFILE_DATA_PATH)
	if not classData then
		classData = { ClassName = "None", SpentPoints = 0, Nodes = {}, Skills = {} }
		DataService.SetPath(dataKey, PROFILE_DATA_PATH, classData)
	end

	local entityState: ClassTypes.ActiveEntityState = {
		ClassName = classData.ClassName,
		UnlockedSkills = {},
		UnlockedSkillTree = {},
	}

	-- [Mapping logic remains the same...]

	-- 3. Save to active cache
	activeEntityProfiles[instance] = entityState

	DebugPrintSyncData(instance, BuildSyncData(instance))

	-- 4. Replicate state
	ReplicateProfileState(instance)
	NotifyClassChanged(instance, entityState.ClassName)
end

-- Purges records cleanly upon session destruction
function ClassService.UnloadEntity(instance: Instance)
	activeEntityProfiles[instance] = nil
end

function ClassService.SetClass(instance: Instance, newClassName: string)
	local config = classRegistry[newClassName]
	if not config then
		return
	end

	local dataKey = GetEntityDataKey(instance)

	-- 1. Update DataService for both players and NPCs
	DataService.SetPath(dataKey, "ClassProfile.ClassName", newClassName)
	DataService.SetPath(dataKey, "ClassProfile.Nodes", {})
	DataService.SetPath(dataKey, "ClassProfile.Skills", {})
	DataService.SetPath(dataKey, "ClassProfile.SpentPoints", 0)

	-- 2. Update Local Cache (Works for both)
	local entityState = activeEntityProfiles[instance]
	if entityState then
		entityState.ClassName = newClassName
		entityState.UnlockedSkills = {}
		entityState.UnlockedSkillTree = {}
	end

	DebugPrintSyncData(instance, BuildSyncData(instance))

	-- 3. Trigger Sync (Only for players, handled by ReplicateProfileState check)
	ReplicateProfileState(instance)
	NotifyClassChanged(instance, newClassName)

	print(string.format("[ClassService] Instance %s changed class to %s", instance.Name, newClassName))
end

function ClassService.RegisterClassChangedHandler(handler: (instance: Instance, className: string) -> ()): () -> ()
	for _, existingHandler in ipairs(classChangedHandlers) do
		if existingHandler == handler then
			return function()
				for index, targetHandler in ipairs(classChangedHandlers) do
					if targetHandler == handler then
						table.remove(classChangedHandlers, index)
						break
					end
				end
			end
		end
	end

	table.insert(classChangedHandlers, handler)

	return function()
		for index, existingHandler in ipairs(classChangedHandlers) do
			if existingHandler == handler then
				table.remove(classChangedHandlers, index)
				break
			end
		end
	end
end

-- Get Config from registry
function ClassService.GetConfig(className: string)
	-- This returns the frozen table from your registry
	return classRegistry[className]
end

-- Unified data provider used by EntityHandler to pull state safely
function ClassService.GetSyncData(instance: Instance)
	local syncData = BuildSyncData(instance)
	if DEBUG_PRINT_SYNC_DATA then
		DebugPrintSyncData(instance, syncData)
	end

	return syncData
end

function ClassService.Init()
	if hasInitialized then
		return
	end

	hasInitialized = true

	-- 1. Scan and scrape configuration structures matching your exact hierarchy path
	local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
	if not modulesFolder then
		warn("[ClassService] ReplicatedStorage.Modules missing.")
		return
	end

	local classesFolder = modulesFolder:FindFirstChild("Classes") :: Folder?
	if not classesFolder then
		warn("[ClassService] Classes folder missing from ReplicatedStorage.Modules.")
		return
	end

	if classesFolder then
		for _, classDir in ipairs(classesFolder:GetChildren()) do
			if not classDir:IsA("Folder") then
				continue
			end

			local configModule = classDir:FindFirstChild("Config")
			if configModule and configModule:IsA("ModuleScript") then
				-- SAFE TRAP: pcall catches compilation errors, missing variables, or runtime crashes inside the config file
				local success, rawConfig = pcall(require, configModule)

				if success and type(rawConfig) == "table" then
					-- Clone the table so we can safely mutate it even if it was frozen
					local config = table.clone(rawConfig) :: ClassTypes.ClassConfig

					-- Automatically scrape skill folders and attach them into the behavior map
					config.Behavior = ScrapeClassDirectories(classDir)

					-- Deep lock our cloned configuration copy to prevent cross-contamination
					DeepFreeze(config)
					classRegistry[classDir.Name] = config

					-- Clear success notification for your console logging pipeline
					print(string.format("[ClassService] Successfully loaded class: ✅ %s", classDir.Name))
					DebugPrintClassStats(classDir.Name, config)
				else
					-- High-visibility warning tracking exactly which module script broke and why
					warn(
						string.format(
							"[ClassService CRITICAL] Failed to load class structure: ❌ %s. Error: %s",
							classDir.Name,
							tostring(rawConfig)
						)
					)
				end
			else
				warn(
					string.format(
						"[ClassService] Missing 'Config' ModuleScript inside class folder: ⚠️ %s",
						classDir.Name
					)
				)
			end
		end
	else
		warn("[ClassService] Classes folder missing from ReplicatedStorage.Modules.")
	end

	-- 2. Bind communications across your ClassNetwork boundary layout
	if type(ClassNetwork.SetAllocationHandler) == "function" then
		ClassNetwork.SetAllocationHandler(function(player: Player, nodeName: string)
			ProcessAllocationRequest(player, nodeName)
		end)
	end
end

function ClassService.Destroy()
	table.clear(classRegistry)
	for instance in pairs(activeEntityProfiles) do
		activeEntityProfiles[instance] = nil
	end

	for instance in pairs(entityDataKeys) do
		entityDataKeys[instance] = nil
	end
	table.clear(classChangedHandlers)
	hasInitialized = false
end
-----------------------------
-- MAIN --
-----------------------------
return table.freeze(ClassService)
