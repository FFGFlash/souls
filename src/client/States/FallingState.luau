local StarterPlayer = game:GetService("StarterPlayer")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local FallingState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Landing = true,
		Idle = true,
	},
}

export type Context = {
	FallingAnimation: AnimationTrack,
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
	StartVector: Vector3,
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

	context.StartVector = context.CharacterController.Root.Position

	if context.FallingAnimation then
		context.FallingAnimation:Play()
	end
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
	if context.FallingAnimation then
		context.FallingAnimation:Stop()
	end
end

return FallingState
