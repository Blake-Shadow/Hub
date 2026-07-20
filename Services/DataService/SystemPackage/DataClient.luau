--!strict
--@author: Shadow
--@date:
--[[@description:
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local DataNetwork = require("./DataNetwork")

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local DataClient = {}

local localCache: any = nil
local changeListeners: { (newData: any) -> () } = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Instantly returns the locally cached data profile (or requests it from the server if empty)
function DataClient.GetData(): any
	if not localCache then
		-- Fire request up the network line
		DataNetwork.DataRequestRemote:FireServer()

		-- Yield thread processing temporarily until replication clears
		local start = os.time()
		while not localCache do
			task.wait()
			if os.time() - start > 5 then
				warn("[DataClient] Data request timed out waiting for server replication.")
				break
			end
		end
	end
	return localCache
end

-- Safely resolves deep nested values via path strings on the client side (Read-Only)
function DataClient.GetPath(path: string): any
	local data = DataClient.GetData()
	if type(data) ~= "table" then
		return nil
	end

	for segment in string.gmatch(path, "([^%.]+)") do
		data = data[segment]
		if data == nil then
			return nil
		end
	end
	return data
end

-- Registers a custom callback triggered whenever client data structure updates are replicated
function DataClient.OnChanged(listener: (newData: any) -> ())
	table.insert(changeListeners, listener)
end

-- Lifecycle Initializer
function DataClient.Init()
	-- Connect structural updates routed down from the server runtime clusters
	DataNetwork.DataUpdateRemote.OnClientEvent:Connect(function(newData: any)
		localCache = newData

		-- Disperse state alerts across client microservices / UI frames
		for _, listener in ipairs(changeListeners) do
			task.spawn(listener, newData)
		end
	end)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(DataClient)
