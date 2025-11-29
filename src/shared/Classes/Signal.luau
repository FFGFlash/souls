local Task = require(script.Parent.Task)
export type Signal<A... = ()> = {
	Type: "Signal",
	Previous: Connection<A...>,
	Next: Connection<A...>,
	Fire: (self: Signal<A...>, A...) -> (),
	Connect: (self: Signal<A...>, func: (A...) -> ()) -> Connection<A...>,
	Once: (self: Signal<A...>, func: (A...) -> ()) -> Connection<A...>,
	Wait: (self: Signal<A...>) -> A...,
}

export type Connection<A... = ()> = {
	Type: "Connection",
	Previous: Connection<A...>,
	Next: Connection<A...>,
	Once: boolean,
	Function: (player: Player, A...) -> (),
	Thread: thread,
	Disconnect: (self: Connection<A...>) -> (),
}

local Signal = {} :: Signal<...any>
Signal.__index = Signal
Signal.Type = "Signal"

local Connection = {} :: Connection<...any>
Connection.__index = Connection
Connection.Type = "Connection"

local function Constructor<A...>()
	local signal = (setmetatable({}, Signal) :: any) :: Signal<A...>
	signal.Previous = signal
	signal.Next = signal
	return signal
end

function Signal:Connect(func)
	local conn = (setmetatable({}, Connection) :: any) :: Connection
	conn.Previous = self.Previous
	conn.Next = self
	conn.Once = false
	conn.Function = func
	self.Previous.Next = conn
	self.Previous = conn
	return conn
end

function Signal:Once(func)
	local conn = (setmetatable({}, Connection) :: any) :: Connection
	conn.Previous = self.Previous
	conn.Next = self
	conn.Once = true
	conn.Function = func
	self.Previous.Next = conn
	self.Previous = conn
	return conn
end

function Signal:Wait()
	local conn = (setmetatable({}, Connection) :: any) :: Connection
	conn.Previous = self.Previous
	conn.Next = self
	conn.Once = true
	conn.Thread = coroutine.running()
	self.Previous.Next = conn
	self.Previous = conn
	return coroutine.yield()
end

function Signal:Fire(...)
	local conn = self.Next
	while conn.Type == "Connection" do
		if conn.Function then
			Task:Defer(conn.Function, ...)
		else
			task.defer(conn.Thread, ...)
		end
		if conn.Once then
			conn.Previous.Next = conn.Next
			conn.Next.Previous = conn.Previous
		end
		conn = conn.Next
	end
end

function Connection:Disconnect()
	self.Previous.Next = self.Next
	self.Next.Previous = self.Previous
end

return {
	new = Constructor,
}
