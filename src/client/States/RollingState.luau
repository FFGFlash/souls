local StarterPlayer = game:GetService("StarterPlayer")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local RollingState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Idle = true,
	},
}

export type Context = {
	StartTime: number,
	Duration: number,
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
	RollForward: AnimationTrack?,
	RollBackward: AnimationTrack?,
	RollLeft: AnimationTrack?,
	RollRight: AnimationTrack?,
}

local function CalculateAnimationWeight(moveAngle: number, referenceAngle: number)
	local pi2 = math.pi * 2
	local pi = math.pi
	local diff = moveAngle - referenceAngle
	local wrap = (diff % pi2 + pi2) % pi2
	local short = math.min(wrap, pi2 - wrap)
	local weight = 1 - (short / (pi / 2))
	return math.clamp(weight, 0, 1)
end

function RollingState:OnPreload(context)
	context.RollForward = context.CharacterController:LoadAnimation("rbxassetid://77858067445742")
	context.RollBackward = context.CharacterController:LoadAnimation("rbxassetid://132546627104511")
	context.RollLeft = context.CharacterController:LoadAnimation("rbxassetid://111645930805390")
	context.RollRight = context.CharacterController:LoadAnimation("rbxassetid://79227688280429")

	if not context.RollForward then
		warn("Failed to load RollForward animation")
	end
	if not context.RollBackward then
		warn("Failed to load RollBackward animation")
	end
	if not context.RollLeft then
		warn("Failed to load RollLeft animation")
	end
	if not context.RollRight then
		warn("Failed to load RollRight animation")
	end
end

function RollingState:OnEnter(context)
	context.CharacterController:SetCapability("Movement", false)
	context.CharacterController:SetCapability("Rotation", false)
	context.CharacterController:SetCapability("GroundAlignment", false)

	local moveDirection = context.CharacterController.Movement.MoveDirection
	local lookDirection = context.CharacterController.Root.CFrame.LookVector
	local dashDirection = moveDirection.Magnitude > 0 and moveDirection or -lookDirection

	context.CharacterController:SetForcedVelocity(dashDirection * 100)

	context.StartTime = tick()
	context.Duration = 0.5

	local dotProduct = dashDirection:Dot(lookDirection)
	local angle = math.atan2(dashDirection:Cross(lookDirection).Y, dotProduct)

	local forwardWeight = CalculateAnimationWeight(angle, 0)
	local backwardWeight = CalculateAnimationWeight(angle, math.pi)
	local leftWeight = CalculateAnimationWeight(angle, -math.pi / 2)
	local rightWeight = CalculateAnimationWeight(angle, math.pi / 2)

	-- Backward animation doesn't play nice with the other animations
	if backwardWeight > 0.4 then
		if context.RollBackward then
			context.RollBackward:Play(nil, backwardWeight)
		end
	else
		if context.RollForward then
			context.RollForward:Play(nil, forwardWeight)
		end
		if context.RollLeft then
			context.RollLeft:Play(nil, leftWeight)
		end
		if context.RollRight then
			context.RollRight:Play(nil, rightWeight)
		end
	end
end

function RollingState:OnUpdate(context)
	if tick() - context.StartTime >= context.Duration then
		self:Switch("Idle")
	end
end

function RollingState:OnExit(context)
	context.CharacterController:StopAnimations()
	context.CharacterController:SetCapability("Movement", true)
	context.CharacterController:SetCapability("Rotation", true)
	context.CharacterController:SetCapability("GroundAlignment", true)
	context.CharacterController:SetForcedVelocity(nil)
end

return RollingState
