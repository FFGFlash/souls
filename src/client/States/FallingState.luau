local StarterPlayer = game:GetService("StarterPlayer")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local FallingState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Landing = true,
		Idle = true,
	},
}

export type Context = {
	PlayerAnimationController: typeof(require(
		StarterPlayer.StarterPlayerScripts.Client.Services.PlayerAnimationControllerService
	)),
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
	StartVector: Vector3,
}

function FallingState:OnPreload(context)
	context.PlayerAnimationController:LoadAnimation("Falling", "rbxassetid://127538891225329")
end

function FallingState:OnEnter(context)
	context.CharacterController:SetCapability("Movement", true)
	context.CharacterController:SetCapability("Rotation", true)

	context.StartVector = context.CharacterController.Root.Position

	context.PlayerAnimationController:GetTrack("Falling"):Play()
end

function FallingState:OnUpdate(context)
	if context.CharacterController:IsGrounded() then
		local distance = (context.StartVector.Y - context.CharacterController.Root.Position.Y)
		if distance < 10 then
			self:Switch("Idle")
			return
		end
		self:Switch("Landing")
		return
	end
end

function FallingState:OnExit(context)
	context.PlayerAnimationController:StopAll()
end

return FallingState
