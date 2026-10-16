--!strict
-- Tracks things that need cleaning up (instances, connections, threads, callbacks, objects with :Destroy())
-- and cleans them all in reverse order of insertion.

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, handler: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

type TroveImpl = {
	Items: { any },
	Cleaning: boolean,
}

local function cleanup(item: any)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

local Trove = {}
Trove.__index = Trove

function Trove.new(): Trove
	local self: TroveImpl = { Items = {}, Cleaning = false }
	return (setmetatable(self, Trove) :: any) :: Trove
end

function Trove.Add(self: TroveImpl, item: any): any
	if self.Cleaning then
		-- Anything added while cleaning would leak, so clean it right away.
		cleanup(item)
		return item
	end
	table.insert(self.Items, item)
	return item
end

function Trove.Connect(self: TroveImpl, signal: RBXScriptSignal, handler: (...any) -> ()): RBXScriptConnection
	return Trove.Add(self, signal:Connect(handler))
end

function Trove.Clean(self: TroveImpl)
	if self.Cleaning then
		return
	end
	self.Cleaning = true

	local items = self.Items
	for index = #items, 1, -1 do
		local ok, err = pcall(cleanup :: (any) -> any, items[index])
		if not ok then
			warn("[Trove] cleanup failed:", err)
		end
	end
	table.clear(items)

	self.Cleaning = false
end

Trove.Destroy = Trove.Clean

return Trove
