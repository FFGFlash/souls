local StarterPlayer = game:GetService("StarterPlayer")
local StateMachineService = require(StarterPlayer.StarterPlayerScripts.Client.Services.StateMachineService)

local LandingState: StateMachineService.State<Context> = {
	AllowedTransitions = {
		Idle = true,
	},
}

export type Context = {
	LandingAnimation: AnimationTrack,
	CharacterController: typeof(require(StarterPlayer.StarterPlayerScripts.Client.Services.CharacterControllerService)),
	StartTime: number,
	Duration: number,
}

function LandingState:OnPreload(context)
	context.LandingAnimation = context.CharacterController:LoadAnimation("rbxassetid://80044599499576")
	if not context.LandingAnimation then
		warn("Failed to load Falling animation")
	end
end

function LandingState:OnEnter(context)
	context.CharacterController:SetCapability("Movement", false)
	context.CharacterController:SetCapability("Rotation", false)

	context.StartTime = tick()
	context.Duration = 1

	if context.LandingAnimation then
		context.LandingAnimation:Play()
	end
end

function LandingState:OnUpdate(context)
	if tick() - context.StartTime >= context.Duration then
		self:Switch("Idle")
		return
	end
end

function LandingState:OnExit(context)
	context.CharacterController:SetCapability("Movement", true)
	context.CharacterController:SetCapability("Rotation", true)

	if context.LandingAnimation then
		context.LandingAnimation:Stop()
	end
end

return LandingState
