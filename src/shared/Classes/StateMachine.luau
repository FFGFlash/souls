local RunService = game:GetService("RunService")
local StateMachine = {}
StateMachine.__index = StateMachine

export type State<T, C> = {
	Context: C,
	OnEnter: ((host: T, context: C, ...any) -> ())?,
	OnExit: ((host: T, context: C) -> ())?,
	OnUpdate: ((host: T, context: C, dt: number) -> ())?,
	CanTransitionTo: ((host: T, context: C, newStateName: string) -> boolean)?,
	CanTransitionFrom: ((host: T, context: C) -> boolean)?,
}

function StateMachine.new<T>(host: T, states: { [string]: State<T, any> })
	return setmetatable({
		Host = host,
		States = states,
		CurrentContext = nil :: any,
		CurrentState = nil :: State<T, any>?,
		CurrentStateName = nil :: string?,
	}, StateMachine)
end

export type StateMachine<T = any> = {
	Host: T,
	States: { [string]: State<T, any> },
	CurrentContext: any,
	CurrentState: State<T, any>?,
	CurrentStateName: string?,
	Start: (self: StateMachine<T>, initialStateName: string) -> (),
	Transition: (self: StateMachine<T>, newStateName: string, ...any) -> boolean,
	GetState: (self: StateMachine<T>) -> string?,
	Update: (self: StateMachine<T>, dt: number) -> (),
}

-- export type StateMachine<T = any> = typeof(StateMachine.new(({} :: any) :: T, {}))

function StateMachine.Start(self: StateMachine, initialStateName: string)
	local state = self.States[initialStateName]
	if state then
		self:Transition(initialStateName)
	end

	RunService.Heartbeat:Connect(function(dt)
		self:Update(dt)
	end)
end

function StateMachine.Transition(self: StateMachine, newStateName: string, ...: any)
	local newState = self.States[newStateName]

	if newState.CanTransitionFrom and not newState.CanTransitionFrom(self.Host) then
		return false
	end

	if self.CurrentState then
		if
			self.CurrentState.CanTransitionTo
			and not self.CurrentState.CanTransitionTo(self.Host, self.CurrentContext, newStateName)
		then
			return false
		end

		if self.CurrentState.OnExit then
			self.CurrentState.OnExit(self.Host, self.CurrentContext)
		end
	end

	self.CurrentContext = {}
	self.CurrentState = newState
	self.CurrentStateName = newStateName

	if self.CurrentState then
		if self.CurrentState.Context then
			for key, value in pairs(self.CurrentState.Context) do
				self.CurrentContext[key] = value
			end
		end

		if self.CurrentState.OnEnter then
			self.CurrentState.OnEnter(self.Host, self.CurrentContext, ...)
		end
	end

	return true
end

function StateMachine.Update(self: StateMachine, dt: number)
	if self.CurrentState and self.CurrentState.OnUpdate then
		self.CurrentState.OnUpdate(self.Host, self.CurrentContext, dt)
	end
end

function StateMachine.GetState(self: StateMachine)
	return self.CurrentStateName
end

return StateMachine
