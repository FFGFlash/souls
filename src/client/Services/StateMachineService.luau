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
	for key, value in pairs(self.Services) do
		self.Context[key] = value
	end
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

function StateMachineService:Init()
	self:ClearContext()

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
	OnEnter: ((self: StateMachineService, context: T) -> ())?,
	OnUpdate: ((self: StateMachineService, context: T, dt: number) -> ())?,
	OnExit: ((self: StateMachineService, context: T) -> ())?,
	AllowedTransitions: { [string]: boolean }?,
}

return StateMachineService
