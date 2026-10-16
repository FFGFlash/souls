--!strict
-- Minimal typed signal. Handlers run immediately (via task.spawn so one failing handler can't break the caller),
-- and it is safe to connect/disconnect while firing.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

type ConnectionImpl = {
	Connected: boolean,
	Handler: (...any) -> (),
	Owner: SignalImpl,
}

type SignalImpl = {
	Connections: { ConnectionImpl },
}

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: ConnectionImpl)
	if not self.Connected then
		return
	end
	self.Connected = false

	local connections = self.Owner.Connections
	local index = table.find(connections, self)
	if index then
		table.remove(connections, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self: SignalImpl = { Connections = {} }
	return (setmetatable(self, Signal) :: any) :: Signal<T...>
end

function Signal.Connect(self: SignalImpl, handler: (...any) -> ())
	local connection: ConnectionImpl = {
		Connected = true,
		Handler = handler,
		Owner = self,
	}
	table.insert(self.Connections, connection)
	return setmetatable(connection, Connection)
end

function Signal.Once(self: SignalImpl, handler: (...any) -> ())
	local connection: any
	connection = Signal.Connect(self, function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Fire(self: SignalImpl, ...: any)
	-- Iterate a snapshot so handlers can freely connect/disconnect.
	for _, connection in table.clone(self.Connections) do
		if connection.Connected then
			task.spawn(connection.Handler, ...)
		end
	end
end

function Signal.DisconnectAll(self: SignalImpl)
	for _, connection in self.Connections do
		connection.Connected = false
	end
	table.clear(self.Connections)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
