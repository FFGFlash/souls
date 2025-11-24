local RunService = game:GetService("RunService")

local StateMachineService = {
	CurrentState = "Idle",
	States = {},
	Context = {},
}

function StateMachineService:AddState(name, config)
	self.States[name] = config
end

function StateMachineService:CanTransition(to)
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

function StateMachineService:Switch(to)
	if not self.States[to] then
		warn("Unknown State: ", to)
		return false
	end

	if not self:CanTransition(to) then
		return false
	end

	local old = self:GetActiveState()
	if old and old.OnExit then
		old.OnExit(self.Context)
	end

	self.CurrentState = to
	self.Context = {}

	local new = self:GetActiveState()
	if new and new.OnEnter then
		new.OnEnter(self.Context)
	end

	return true
end

function StateMachineService:Init()
	local current = self:GetActiveState()
	if current then
		current.OnEnter(self.Context)
	end

	RunService.Heartbeat:Connect(function(dt)
		local state = self:GetActiveState()
		if state and state.OnUpdate then
			state.OnUpdate(self.Context, dt)
		end
	end)
end

return StateMachineService
