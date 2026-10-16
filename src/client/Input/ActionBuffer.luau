--!strict
-- Remembers when buffered actions were last pressed so states can honour a press that happened slightly
-- before they were able to act on it (e.g. pressing roll just before a landing ends).

local Types = require(script.Parent.Types)

type BufferedAction = Types.BufferedAction

export type ActionBuffer = {
	Push: (self: ActionBuffer, action: BufferedAction) -> (),
	Peek: (self: ActionBuffer, action: BufferedAction, window: number) -> boolean,
	Consume: (self: ActionBuffer, action: BufferedAction, window: number) -> boolean,
	Clear: (self: ActionBuffer, action: BufferedAction?) -> (),
}

type Impl = {
	PressedAt: { [BufferedAction]: number },
}

local ActionBuffer = {}
ActionBuffer.__index = ActionBuffer

function ActionBuffer.new(): ActionBuffer
	local self: Impl = { PressedAt = {} }
	return (setmetatable(self, ActionBuffer) :: any) :: ActionBuffer
end

function ActionBuffer.Push(self: Impl, action: BufferedAction)
	self.PressedAt[action] = os.clock()
end

function ActionBuffer.Peek(self: Impl, action: BufferedAction, window: number): boolean
	local pressedAt = self.PressedAt[action]
	return pressedAt ~= nil and os.clock() - pressedAt <= window
end

function ActionBuffer.Consume(self: Impl, action: BufferedAction, window: number): boolean
	if ActionBuffer.Peek(self, action, window) then
		self.PressedAt[action] = nil
		return true
	end
	return false
end

function ActionBuffer.Clear(self: Impl, action: BufferedAction?)
	if action then
		self.PressedAt[action] = nil
	else
		table.clear(self.PressedAt)
	end
end

return ActionBuffer
