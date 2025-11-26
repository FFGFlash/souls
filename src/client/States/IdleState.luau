local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local IdleState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Walking = true,
		Rolling = true,
		Falling = true,
	},
}

export type Context = {
	IdleAnimation: AnimationTrack,
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
	PlayerAnimationController: typeof(require(
		StarterPlayer.StarterPlayerScripts.Client.Services.PlayerAnimationControllerService
	)),
}

function IdleState:OnPreload(context)
	context.PlayerAnimationController:LoadAnimation("Idle", "rbxassetid://76157679289795")
end

function IdleState:OnEnter(context)
	context.CharacterController:SetCapability("Movement", false)
	context.CharacterController:SetCapability("Rotation", false)

	context.PlayerAnimationController:GetTrack("Idle"):Play()
end

function IdleState:OnUpdate(context)
	if not context.CharacterController:IsGrounded() then
		self:Switch("Falling")
		return
	end

	local moving = UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.S)
		or UserInputService:IsKeyDown(Enum.KeyCode.D)

	if moving then
		self:Switch("Walking")
		return
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		self:Switch("Rolling")
		return
	end
end

function IdleState:OnExit(context)
	context.PlayerAnimationController:StopAll()
end

return IdleState
