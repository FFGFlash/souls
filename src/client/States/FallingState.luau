local StarterPlayer = game:GetService("StarterPlayer")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local FallingState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Idle = true,
	},
}

export type Context = {
	FallingAnimation: AnimationTrack,
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
}

function FallingState:OnPreload(context)
	context.FallingAnimation = context.CharacterController:LoadAnimation("rbxassetid://127538891225329")
	if not context.FallingAnimation then
		warn("Failed to load Falling animation")
	end
end

function FallingState:OnEnter(context)
	context.CharacterController:SetCapability("Movement", true)
	context.CharacterController:SetCapability("Rotation", true)

	if context.FallingAnimation then
		context.FallingAnimation:Play()
	end
end

function FallingState:OnUpdate(context)
	if context.CharacterController:IsGrounded() then
		self:Switch("Idle")
		return
	end
end

function FallingState:OnExit(context)
	if context.FallingAnimation then
		context.FallingAnimation:Stop()
	end
end

return FallingState
