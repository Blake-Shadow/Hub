--!strict
--@author: Shadow
--@date: 2026-07-13
--[[@description:
	The ultimate data-agnostic server runtime infrastructure.
	Features structural proxy auto-replication, ironclad rate-limiting,
	multi-server session locking, pointer-path mutation convenience wrappers,
	automated background autosave loops, active dirty-flag tracking,
	expandable schema migrations, rolling ledger rollbacks, a cluster shutdown 
	flushing routine, automated player character attribute mirroring, and driver-agnostic 
	data profile destruction routines.
]]
-----------------------------
-- SERVICES --
-----------------------------
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local DataNetwork = require("./DataNetwork")
local DataTypes = require("./DataTypes")

-----------------------------
-- TYPES --
-----------------------------
type CacheEntry = {
	Data: any,
	IsLocked: boolean,
	IsDirty: boolean,
	LastUpdated: number,
	SessionToken: string?,
	HistoryLedger: { any },
}

type RateLimitTracker = {
	RequestsThisWindow: number,
	WindowStart: number,
}

type MigrationJob = (oldData: any) -> any

-----------------------------
-- VARIABLES --
-----------------------------
local DataService = {}

-- Main internal structures
local sessionCache: { [DataTypes.Key]: CacheEntry } = {}
local rateLimits: { [Player]: RateLimitTracker } = {}
local changeListeners: { (key: DataTypes.Key, newData: any) -> () } = {}
local migrationPipeline: { [number]: MigrationJob } = {}

-- Injected configurations
local storageProvider: any = nil
local defaultDataTemplate: any = nil
-- Track maximum configuration version registered
local currentSchemaVersion: number = 1
local characterAttributesMap: { string } = {} -- List of dot-paths to sync to characters

-- Unique Identifier for this specific Server Session instance
local SERVER_SESSION_ID = HttpService:GenerateGUID(false)

-- Control States
local isAutosaveLoopRunning = false
local isServerShuttingDown = false

-- Tuning Constants
local MAX_REQUESTS_PER_WINDOW = 12
local RATE_LIMIT_WINDOW = 4
local BACKEND_TIMEOUT = 10
local AUTOSAVE_INTERVAL = 120
local MAX_LEDGER_DEPTH = 5 -- Maximum undoable historical steps saved in memory

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Generates a deep clone of a table ensuring nested dictionaries are decoupled
local function DeepCopy(target: any): any
	if type(target) ~= "table" then
		return target
	end
	local clone = {}
	for key, value in pairs(target) do
		clone[key] = DeepCopy(value)
	end
	return clone
end

-- Splits a string path like "Stats.Coins" into individual key entries
local function ResolvePath(path: string): { string }
	local segments = {}
	for segment in string.gmatch(path, "([^%.]+)") do
		table.insert(segments, segment)
	end
	return segments
end

-- Traverses a table dynamically via a string path to get or modify a value
local function NavigateToPath(
	rootTable: { [string]: any },
	path: string,
	autoCreate: boolean?
): ({ [string]: any }, string)
	local segments = ResolvePath(path)
	local current = rootTable

	for i = 1, #segments - 1 do
		local segment = segments[i]
		if current[segment] == nil and autoCreate then
			current[segment] = {}
		end
		current = current[segment]
		assert(type(current) == "table", "[DataService] Invalid path resolution: " .. path)
	end

	return current, segments[#segments]
end

-- Security check to evaluate if a client is executing a remote exploit attempt
local function IsClientSpamming(player: Player): boolean
	local now = os.time()
	local tracker = rateLimits[player]

	if not tracker then
		rateLimits[player] = { RequestsThisWindow = 1, WindowStart = now }
		return false
	end

	if now - tracker.WindowStart > RATE_LIMIT_WINDOW then
		tracker.RequestsThisWindow = 1
		tracker.WindowStart = now
		return false
	end

	tracker.RequestsThisWindow += 1
	return tracker.RequestsThisWindow > MAX_REQUESTS_PER_WINDOW
end

-- Triggers hooks across internal server microservices and updates clients
local function DispatchUpdate(key: DataTypes.Key, newData: any)
	for _, listener in ipairs(changeListeners) do
		task.spawn(listener, key, newData)
	end

	if typeof(key) == "Instance" and key:IsA("Player") then
		DataNetwork.UpdateClientData(key, newData)
	end
end

-- Pushes a historical snapshot into the circular rolling undo buffer
local function PushToLedger(entry: CacheEntry)
	table.insert(entry.HistoryLedger, 1, DeepCopy(entry.Data))
	if #entry.HistoryLedger > MAX_LEDGER_DEPTH then
		table.remove(entry.HistoryLedger, #entry.HistoryLedger)
	end
end

-- Wraps a table in a strict proxy wrapper to auto-detect nested changes dynamically
local function CreateObservableProxy(key: DataTypes.Key, rawData: { [string]: any }): any
	local proxy = {}
	local metatable = {
		__index = function(_, idx)
			local val = rawData[idx]
			if type(val) == "table" then
				return CreateObservableProxy(key, val)
			end
			return val
		end,
		__newindex = function(_, idx, value)
			if rawData[idx] == value then
				return
			end

			local entry = sessionCache[key]
			if entry then
				if entry.IsLocked then
					warn("[DataService] Direct write dropped! Key state is locked: " .. tostring(key))
					return
				end
				PushToLedger(entry)
				rawData[idx] = value
				entry.IsDirty = true
				entry.LastUpdated = os.time()
				DispatchUpdate(key, entry.Data)
			else
				rawData[idx] = value
			end
		end,
		__metatable = "The state of this agnostic architecture is locked.",
	}
	return setmetatable(proxy, metatable)
end

-- Applies incremental structural upgrades if old data formats are loaded
local function RunSchemaMigrations(data: any): any
	if type(data) ~= "table" then
		return data
	end

	local storedVersion = data._SchemaVersion or 0
	while storedVersion < currentSchemaVersion do
		storedVersion += 1
		local migrationJob = migrationPipeline[storedVersion]
		if migrationJob then
			local success, migratedData = pcall(migrationJob, data)
			if success then
				data = migratedData
				data._SchemaVersion = storedVersion
			else
				warn("[DataService] Critical failure processing schema migration step v" .. storedVersion)
				break
			end
		else
			data._SchemaVersion = storedVersion
		end
	end
	return data
end

-- A secure background loop tracking dirty records and saving them on an interval
local function StartAutosaveLoop()
	if isAutosaveLoopRunning then
		return
	end
	isAutosaveLoopRunning = true

	task.spawn(function()
		while isAutosaveLoopRunning and not isServerShuttingDown do
			task.wait(AUTOSAVE_INTERVAL)
			if isServerShuttingDown then
				break
			end

			for key, entry in pairs(sessionCache) do
				if not entry.IsLocked and entry.IsDirty and storageProvider then
					entry.IsLocked = true

					task.spawn(function()
						if type(entry.Data) == "table" then
							entry.Data._SchemaVersion = currentSchemaVersion
						end

						local success = pcall(function()
							return storageProvider.Save(key, entry.Data)
						end)

						if success then
							entry.IsDirty = false
						end
						entry.IsLocked = false
					end)
				end
			end
		end
	end)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Returns a safe read/write proxy of the cached data structure
function DataService.GetData(key: DataTypes.Key): any
	local entry = sessionCache[key]
	if not entry then
		return defaultDataTemplate and CreateObservableProxy(key, DeepCopy(defaultDataTemplate)) or nil
	end

	if type(entry.Data) == "table" then
		return CreateObservableProxy(key, entry.Data)
	end
	return entry.Data
end

-- Overrides an active structural block entirely
function DataService.SetData(key: DataTypes.Key, newData: any)
	local entry = sessionCache[key]
	if entry and entry.IsLocked then
		return
	end

	if entry then
		PushToLedger(entry)
		entry.Data = DeepCopy(newData)
		entry.IsDirty = true
		entry.LastUpdated = os.time()
	else
		sessionCache[key] = {
			Data = DeepCopy(newData),
			IsLocked = false,
			IsDirty = true,
			LastUpdated = os.time(),
			SessionToken = SERVER_SESSION_ID,
			HistoryLedger = {},
		}
	end

	DispatchUpdate(key, sessionCache[key].Data)
end

-----------------------------
-- TRANSACTION MANIPULATION & CONVENIENCE --
-----------------------------

function DataService.SetPath(key: DataTypes.Key, path: string, value: any)
	local data = DataService.GetData(key)
	if type(data) ~= "table" then
		return
	end
	local targetTable, targetKey = NavigateToPath(data, path, true)
	targetTable[targetKey] = value
end

function DataService.GetPath(key: DataTypes.Key, path: string): any
	local data = DataService.GetData(key)
	if type(data) ~= "table" then
		return nil
	end
	local targetTable, targetKey = NavigateToPath(data, path, false)
	return targetTable[targetKey]
end

function DataService.Increment(key: DataTypes.Key, path: string, amount: number)
	local current = DataService.GetPath(key, path) or 0
	if type(current) == "number" then
		DataService.SetPath(key, path, current + amount)
	end
end

function DataService.ArrayPush(key: DataTypes.Key, path: string, value: any)
	local list = DataService.GetPath(key, path)
	if type(list) == "table" then
		table.insert(list, value)
		DataService.SetPath(key, path, list)
	end
end

-- Reverts the data object one state back via the History Ledger
function DataService.RollbackTransaction(key: DataTypes.Key): boolean
	local entry = sessionCache[key]
	if not entry or #entry.HistoryLedger == 0 or entry.IsLocked then
		return false
	end

	entry.Data = table.remove(entry.HistoryLedger, 1)
	entry.IsDirty = true
	DispatchUpdate(key, entry.Data)
	return true
end

-- Forcefully locks data modifications down (Useful during runtime events like player trades)
function DataService.SetStateLock(key: DataTypes.Key, locked: boolean)
	local entry = sessionCache[key]
	if entry then
		entry.IsLocked = locked
	end
end

-----------------------------
-- LIFECYCLE MANAGEMENT & LOCKING --
-----------------------------

-- Forcefully purges local cache states, clears transaction history, and fires the storage provider's decoupled data destruction routine
function DataService.DeleteEntry(key: DataTypes.Key): boolean
	local entry = sessionCache[key]

	-- Stop operation if data is currently mid-transaction or locked by the save pipeline
	if entry and entry.IsLocked then
		warn("[DataService] Destruction request denied. Entry state is locked: " .. tostring(key))
		return false
	end

	-- 1. Fire the driver-agnostic storage provider wipe callback if registered
	if storageProvider and typeof(storageProvider.WipeData) == "function" then
		local success, err = pcall(function()
			storageProvider.WipeData(key)
		end)
		if not success then
			warn("[DataService] Agnostic backend driver failed to process data destruction: " .. tostring(err))
			return false
		end
	else
		warn(
			"[DataService] Storage provider missing or lacks explicit 'WipeData' implementation. Local memory cache cleared only."
		)
	end

	-- 2. Contextual evaluation: Handle network / instance cleanup ONLY if the target is a Player
	if typeof(key) == "Instance" and key:IsA("Player") then
		local character = key.Character
		if character then
			for _, path in ipairs(characterAttributesMap) do
				local attributeName = string.gsub(path, "%.", "_")
				character:SetAttribute(attributeName, nil)
			end
		end

		-- Push down empty packet replication so the client drops structural states cleanly
		DataNetwork.UpdateClientData(key, nil)
		rateLimits[key] = nil
	end

	-- 3. Atomic purge of the memory allocation frame and its rolling history snapshots
	sessionCache[key] = nil

	return true
end

function DataService.LoadEntry(key: DataTypes.Key): boolean
	if sessionCache[key] then
		return true
	end

	sessionCache[key] = {
		Data = {},
		IsLocked = true,
		IsDirty = false,
		LastUpdated = os.time(),
		SessionToken = SERVER_SESSION_ID,
		HistoryLedger = {},
	}

	local loadedData: any = nil
	local remoteToken: string? = nil

	if storageProvider and typeof(storageProvider.LoadAndLock) == "function" then
		local success, resultData, activeToken = pcall(function()
			return storageProvider.LoadAndLock(key, SERVER_SESSION_ID)
		end)

		if success then
			loadedData = resultData
			remoteToken = activeToken
		end
	end

	if remoteToken and remoteToken ~= SERVER_SESSION_ID then
		sessionCache[key] = nil
		if typeof(key) == "Instance" and key:IsA("Player") then
			key:Kick("[DataService] Multi-Server Session Collision. Access Denied.")
		end
		return false
	end

	local entry = sessionCache[key]
	if entry then
		local workingData = loadedData or (defaultDataTemplate and DeepCopy(defaultDataTemplate)) or {}

		entry.Data = RunSchemaMigrations(workingData)
		entry.IsLocked = false
		entry.LastUpdated = os.time()
		return true
	end

	return false
end

-- Securely flushes state allocations back down to persistence databases
function DataService.UnloadEntry(key: DataTypes.Key)
	local entry = sessionCache[key]
	if not entry then
		return
	end

	local start = os.time()
	while entry.IsLocked do
		task.wait()
		if os.time() - start > BACKEND_TIMEOUT then
			break
		end
	end

	entry.IsLocked = true

	if type(entry.Data) == "table" then
		entry.Data._SchemaVersion = currentSchemaVersion
	end

	if storageProvider and typeof(storageProvider.SaveAndRelease) == "function" then
		pcall(function()
			storageProvider.SaveAndRelease(key, entry.Data, SERVER_SESSION_ID)
		end)
	end

	sessionCache[key] = nil

	if typeof(key) == "Instance" and key:IsA("Player") then
		rateLimits[key] = nil
	end
end

-----------------------------
-- CONFIGURATION & SHUTDOWN MANAGEMENT --
-----------------------------

function DataService.RegisterMigration(version: number, migrationJob: MigrationJob)
	migrationPipeline[version] = migrationJob
	if version > currentSchemaVersion then
		currentSchemaVersion = version
	end
end

-- Maps specific deep paths in your data profile to auto-sync to the player's Character attributes
function DataService.LinkCharacterAttributes(pathsList: { string })
	characterAttributesMap = pathsList
end

function DataService.OnChanged(listener: (key: DataTypes.Key, newData: any) -> ())
	table.insert(changeListeners, listener)
end

-- Sets the data template to fall back on if an entry is empty
function DataService.SetDefaultTemplate(template: any)
	defaultDataTemplate = template
end

-- Sets the data storage handler adapter
function DataService.SetStorageProvider(provider: any)
	storageProvider = provider
end

-- Lifecycle Initializer
function DataService.Init()
	if not RunService:IsServer() then
		return
	end

	StartAutosaveLoop()

	-- AUTOMATED CHARACTER ATTRIBUTE MIRROR ENGINE
	DataService.OnChanged(function(key: DataTypes.Key, _newData: any)
		if typeof(key) == "Instance" and key:IsA("Player") then
			local character = key.Character
			if not character then
				return
			end

			for _, path in ipairs(characterAttributesMap) do
				local value = DataService.GetPath(key, path)
				local valType = typeof(value)

				if
					valType == "number"
					or valType == "string"
					or valType == "boolean"
					or valType == "Vector3"
					or valType == "Color3"
				then
					local attributeName = string.gsub(path, "%.", "_")
					character:SetAttribute(attributeName, value)
				end
			end
		end
	end)

	-- Active Game Crash/Shutdown interceptor handling critical engine sweeps
	game:BindToClose(function()
		isServerShuttingDown = true
		local tasksPending = 0

		for key, entry in pairs(sessionCache) do
			if entry.IsDirty then
				tasksPending += 1
				task.spawn(function()
					DataService.UnloadEntry(key)
					tasksPending -= 1
				end)
			end
		end

		while tasksPending > 0 do
			task.wait(0.1)
		end
	end)

	-- Synchronized client profile data synchronization hook
	DataNetwork.SetRequestHandler(function(player: Player)
		if IsClientSpamming(player) then
			return nil
		end

		local entry = sessionCache[player]
		if not entry or entry.IsLocked then
			return nil
		end

		return entry.Data
	end)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(DataService)
