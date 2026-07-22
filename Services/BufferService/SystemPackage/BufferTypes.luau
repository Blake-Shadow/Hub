--!strict
--@author: Shadow
--@date: 2026-07-22
--[[@description:
	Shared contracts for BufferService and BufferNetwork.
]]
-----------------------------
-- TYPES --
-----------------------------
export type CodecName = string
export type TransportMode = "Buffer" | "Table"

export type RegisteredCodec = {
	Version: number,
	TransportMode: TransportMode?,
	Encode: (payload: any) -> any,
	Decode: (payload: any) -> any,
	Validate: ((payload: any) -> (boolean, string?))?,
}

-----------------------------
-- VARIABLES --
-----------------------------
local BufferTypes = {}

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(BufferTypes)
