local StarterPlayer = game:GetService("StarterPlayer")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local LandingState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Idle = true,
	},
}

export type Context = {
	PlayerAnimationController: typeof(require(
		StarterPlayer.StarterPlayerScripts.Client.Services.PlayerAnimationControllerService
	)),
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
	StartTime: number,
	Duration: number,
}

function LandingState:OnPreload(context)
	context.PlayerAnimationController:LoadAnimation("Landing", "rbxassetid://80044599499576")
end

function LandingState:OnEnter(context)
	context.CharacterController:SetCapability("Movement", false)
	context.CharacterController:SetCapability("Rotation", false)

	context.StartTime = tick()
	context.Duration = 1

	context.PlayerAnimationController:GetTrack("Landing"):Play()
end

function LandingState:OnUpdate(context)
	if tick() - context.StartTime >= context.Duration then
		self:Switch("Idle")
		return
	end
end

function LandingState:OnExit(context)
	context.PlayerAnimationController:StopAll()

	context.CharacterController:SetCapability("Movement", true)
	context.CharacterController:SetCapability("Rotation", true)
end

return LandingState
