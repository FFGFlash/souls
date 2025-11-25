local RunService = game:GetService("RunService")

local StateMachineService = {
	CurrentState = "Idle",
	States = {},
	Context = {},
	Services = {},
}

function StateMachineService:AddState<T>(name: string, config: State<T>)
	self.States[name] = config
end

function StateMachineService:CanTransition(to: string)
	local current = self:GetActiveState()
	if not current then
		return true
	end
	if not current.AllowedTransitions then
		return true
	end
	return current.AllowedTransitions[to] == true
end

function StateMachineService:GetActiveState()
	return self.States[self.CurrentState]
end

function StateMachineService:AddServices(services: { [string]: any })
	for key, value in pairs(services) do
		self.Services[key] = value
	end
end

function StateMachineService:ClearContext()
	self.Context = {}
	self:LoadContext()
end

function StateMachineService:Switch(to: string)
	if not self.States[to] then
		warn("Unknown State: ", to)
		return false
	end

	if not self:CanTransition(to) then
		return false
	end

	local old = self:GetActiveState()
	if old and old.OnExit then
		old.OnExit(self, self.Context)
	end

	self.CurrentState = to
	self:ClearContext()

	local new = self:GetActiveState()
	if new and new.OnEnter then
		new.OnEnter(self, self.Context)
	end

	return true
end

function StateMachineService:LoadContext(context)
	if not context then
		context = self.Context
	end
	local currentState = self:GetActiveState()
	if currentState.Context then
		for key, value in pairs(currentState.Context) do
			context[key] = value
		end
	end
	for key, value in pairs(self.Services) do
		context[key] = value
	end
end

function StateMachineService:Init()
	self:ClearContext()

	for _, state in pairs(self.States) do
		if state.OnPreload then
			if not state.Context then
				state.Context = {}
			end
			self:LoadContext(state.Context)
			state.OnPreload(self, state.Context)
		end
	end

	local current = self:GetActiveState()
	if current then
		current.OnEnter(self, self.Context)
	end

	RunService.Heartbeat:Connect(function(dt)
		local state = self:GetActiveState()
		if state and state.OnUpdate then
			state.OnUpdate(self, self.Context, dt)
		end
	end)
end

export type StateMachineService = typeof(StateMachineService)

export type State<T> = {
	OnPreload: ((self: StateMachineService, context: T) -> ())?,
	OnEnter: ((self: StateMachineService, context: T) -> ())?,
	OnUpdate: ((self: StateMachineService, context: T, dt: number) -> ())?,
	OnExit: ((self: StateMachineService, context: T) -> ())?,
	Context: T?,
	AllowedTransitions: { [string]: boolean }?,
}

return StateMachineService
