local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local WalkingState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Idle = true,
		Rolling = true,
	},
}

export type Context = {
	WalkForward: AnimationTrack?,
	WalkBackward: AnimationTrack?,
	WalkLeft: AnimationTrack?,
	WalkRight: AnimationTrack?,
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
}

function WalkingState:OnEnter(context)
	context.CharacterController:SetCapability("Movement", true)
	context.CharacterController:SetCapability("Rotation", true)

	context.WalkForward = context.CharacterController:LoadAnimation("rbxassetid://138931819291565")
	context.WalkBackward = context.CharacterController:LoadAnimation("rbxassetid://83837749541337")
	context.WalkLeft = context.CharacterController:LoadAnimation("rbxassetid://122445318045440")
	context.WalkRight = context.CharacterController:LoadAnimation("rbxassetid://83644651265136")

	if not context.WalkForward then
		warn("Failed to load walkForward animation")
	else
		context.WalkForward:Play(nil, 0)
	end
	if not context.WalkBackward then
		warn("Failed to load walkBackward animation")
	else
		context.WalkBackward:Play(nil, 0)
	end
	if not context.WalkLeft then
		warn("Failed to load walkLeft animation")
	else
		context.WalkLeft:Play(nil, 0)
	end
	if not context.WalkRight then
		warn("Failed to load walkRight animation")
	else
		context.WalkRight:Play(nil, 0)
	end
end

local function CalculateAnimationWeight(moveAngle: number, referenceAngle: number)
	local pi2 = math.pi * 2
	local pi = math.pi
	local diff = moveAngle - referenceAngle
	local wrap = (diff % pi2 + pi2) % pi2
	local short = math.min(wrap, pi2 - wrap)
	local weight = 1 - (short / (pi / 2))
	return math.clamp(weight, 0, 1)
end

function WalkingState:OnUpdate(context)
	local moving = UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.S)
		or UserInputService:IsKeyDown(Enum.KeyCode.D)
		or context.CharacterController.Movement.CurrentSpeed > 0.5

	if not moving then
		self:Switch("Idle")
		return
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		self:Switch("Rolling")
		return
	end

	local movementDirection = context.CharacterController.Movement.MoveDirection
	local lookVector = context.CharacterController.Root.CFrame.LookVector
	local dotProduct = movementDirection:Dot(lookVector)
	local angle = math.atan2(movementDirection:Cross(lookVector).Y, dotProduct)

	local forwardWeight = CalculateAnimationWeight(angle, 0)
	local backwardWeight = CalculateAnimationWeight(angle, math.pi)
	local leftWeight = CalculateAnimationWeight(angle, -math.pi / 2)
	local rightWeight = CalculateAnimationWeight(angle, math.pi / 2)

	if context.WalkForward then
		context.WalkForward:AdjustWeight(forwardWeight)
	end
	if context.WalkBackward then
		context.WalkBackward:AdjustWeight(backwardWeight)
	end
	if context.WalkLeft then
		context.WalkLeft:AdjustWeight(leftWeight)
	end
	if context.WalkRight then
		context.WalkRight:AdjustWeight(rightWeight)
	end
end

function WalkingState:OnExit(context)
	context.CharacterController:StopAnimations()
end

return WalkingState
