local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local function CalculateAnimationWeight(moveAngle: number, referenceAngle: number)
	local pi2 = math.pi * 2
	local pi = math.pi
	local diff = moveAngle - referenceAngle
	local wrap = (diff % pi2 + pi2) % pi2
	local short = math.min(wrap, pi2 - wrap)
	local weight = 1 - (short / (pi / 2))
	return math.clamp(weight, 0, 1)
end

local WalkingState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Idle = true,
		Rolling = true,
		Falling = true,
	},
}

export type Context = {
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
	PlayerAnimationController: typeof(require(
		StarterPlayer.StarterPlayerScripts.Client.Services.PlayerAnimationControllerService
	)),
	AnimationTracks: { AnimationTrack },
}

function WalkingState:OnPreload(context)
	context.PlayerAnimationController:LoadAnimation("WalkForward", "rbxassetid://138931819291565")
	context.PlayerAnimationController:LoadAnimation("WalkBackward", "rbxassetid://83837749541337")
	context.PlayerAnimationController:LoadAnimation("WalkLeft", "rbxassetid://122445318045440")
	context.PlayerAnimationController:LoadAnimation("WalkRight", "rbxassetid://83644651265136")
end

function WalkingState:OnEnter(context)
	context.CharacterController:SetCapability("Movement", true)
	context.CharacterController:SetCapability("Rotation", true)

	context.AnimationTracks = {
		context.PlayerAnimationController:GetTrack("WalkForward"),
		context.PlayerAnimationController:GetTrack("WalkRight"),
		context.PlayerAnimationController:GetTrack("WalkBackward"),
		context.PlayerAnimationController:GetTrack("WalkLeft"),
	}

	for _, track in context.AnimationTracks do
		track:Play(nil, 0)
	end
end

function WalkingState:OnUpdate(context)
	if not context.CharacterController:IsGrounded() then
		self:Switch("Falling")
		return
	end

	local moving = context.CharacterController:IsMoving()

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

	for i, track in ipairs(context.AnimationTracks) do
		local weight = CalculateAnimationWeight(angle, (-math.pi / 2) + (math.pi / 2) * i)
		track:AdjustWeight(weight)
	end
end

function WalkingState:OnExit(context)
	context.PlayerAnimationController:StopAll()
end

return WalkingState
