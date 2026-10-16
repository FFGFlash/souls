--!strict
-- Small finite state machine. A state's Update receives the frame's dt and the seconds spent in the state, and
-- returns the name of the next state (or nil to stay).
-- The machine is driven explicitly by its owner; it never connects to RunService itself.

local Signal = require(script.Parent.Signal)

export type State<C> = {
	Enter: ((context: C, previous: string?) -> ())?,
	Update: (context: C, dt: number, elapsed: number) -> string?,
	Exit: ((context: C, nextState: string) -> ())?,
}

export type StateMachine<C> = {
	Context: C,
	Current: string?,
	EnteredAt: number,
	Changed: Signal.Signal<string, string?>,

	Start: (self: StateMachine<C>, initial: string) -> (),
	Update: (self: StateMachine<C>, dt: number) -> (),
	Transition: (self: StateMachine<C>, nextState: string) -> (),
	GetState: (self: StateMachine<C>) -> string?,
	GetTimeInState: (self: StateMachine<C>) -> number,
	Destroy: (self: StateMachine<C>) -> (),
}

type Impl = {
	States: { [string]: State<any> },
	Context: any,
	Current: string?,
	EnteredAt: number,
	Changed: Signal.Signal<string, string?>,
	Destroyed: boolean,
}

-- Guards against two states bouncing between each other forever within a single frame.
local MAX_TRANSITIONS_PER_UPDATE = 4

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new<C>(states: { [string]: State<C> }, context: C): StateMachine<C>
	local self: Impl = {
		States = states :: any,
		Context = context,
		Current = nil,
		EnteredAt = os.clock(),
		Changed = Signal.new(),
		Destroyed = false,
	}
	return (setmetatable(self, StateMachine) :: any) :: StateMachine<C>
end

function StateMachine.Transition(self: Impl, nextState: string)
	local state = self.States[nextState]
	assert(state, `Unknown state "{nextState}"`)

	local previous = self.Current
	if previous then
		local exit = self.States[previous].Exit
		if exit then
			exit(self.Context, nextState)
		end
	end

	self.Current = nextState
	self.EnteredAt = os.clock()

	if state.Enter then
		state.Enter(self.Context, previous)
	end

	self.Changed:Fire(nextState, previous)
end

function StateMachine.Start(self: Impl, initial: string)
	StateMachine.Transition(self, initial)
end

function StateMachine.Update(self: Impl, dt: number)
	for _ = 1, MAX_TRANSITIONS_PER_UPDATE do
		local current = self.Current
		if not current or self.Destroyed then
			return
		end

		local nextState = self.States[current].Update(self.Context, dt, os.clock() - self.EnteredAt)
		if not nextState or nextState == current then
			return
		end

		StateMachine.Transition(self, nextState)
		-- The new state gets a zero-dt update this frame so it can react immediately (or chain onwards).
		dt = 0
	end
end

function StateMachine.GetState(self: Impl): string?
	return self.Current
end

function StateMachine.GetTimeInState(self: Impl): number
	return os.clock() - self.EnteredAt
end

function StateMachine.Destroy(self: Impl)
	if self.Destroyed then
		return
	end
	self.Destroyed = true

	local current = self.Current
	if current then
		local exit = self.States[current].Exit
		if exit then
			exit(self.Context, "")
		end
	end
	self.Current = nil
	self.Changed:Destroy()
end

return StateMachine
