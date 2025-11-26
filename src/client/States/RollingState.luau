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
	PlayerAnimationController: typeof(require(
		StarterPlayer.StarterPlayerScripts.Client.Services.PlayerAnimationControllerService
	)),
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
	context.PlayerAnimationController:LoadAnimation("RollForward", "rbxassetid://77858067445742")
	context.PlayerAnimationController:LoadAnimation("RollBackward", "rbxassetid://132546627104511")
	context.PlayerAnimationController:LoadAnimation("RollLeft", "rbxassetid://111645930805390")
	context.PlayerAnimationController:LoadAnimation("RollRight", "rbxassetid://79227688280429")
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
	context.Duration = context.PlayerAnimationController:GetTrack("RollForward").Length

	local dotProduct = dashDirection:Dot(lookDirection)
	local angle = math.atan2(dashDirection:Cross(lookDirection).Y, dotProduct)

	local forwardWeight = CalculateAnimationWeight(angle, 0)
	local backwardWeight = CalculateAnimationWeight(angle, math.pi)
	local leftWeight = CalculateAnimationWeight(angle, -math.pi / 2)
	local rightWeight = CalculateAnimationWeight(angle, math.pi / 2)

	-- Backward animation doesn't play nice with the other animations
	if backwardWeight > 0.4 then
		context.PlayerAnimationController:GetTrack("RollBackward"):Play(nil, backwardWeight)
	else
		context.PlayerAnimationController:GetTrack("RollForward"):Play(nil, forwardWeight)
		context.PlayerAnimationController:GetTrack("RollLeft"):Play(nil, leftWeight)
		context.PlayerAnimationController:GetTrack("RollRight"):Play(nil, rightWeight)
	end
end

function RollingState:OnUpdate(context)
	if tick() - context.StartTime >= context.Duration then
		self:Switch("Idle")
	end
end

function RollingState:OnExit(context)
	context.PlayerAnimationController:StopAll()

	context.CharacterController:SetCapability("Movement", true)
	context.CharacterController:SetCapability("Rotation", true)
	context.CharacterController:SetCapability("GroundAlignment", true)
	context.CharacterController:SetForcedVelocity(nil)
end

return RollingState
