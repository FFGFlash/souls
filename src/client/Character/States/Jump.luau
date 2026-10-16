--!strict
-- Rising part of a jump. Hands over to Fall once the character starts coming down.

local Context = require(script.Parent.Context)
local StateMachine = require(game:GetService("ReplicatedStorage").Shared.StateMachine)

type Context = Context.Context

local Jump: StateMachine.State<Context> = {
	Enter = function(context: Context)
		Context.CaptureAirSpeed(context)
		context.Motor:Jump(context.Config.Jump.Height)
		context.Animation:SetLocomotion("Air")
		context.Tilt:SetEnabled(false)
	end,

	Update = function(context: Context): string?
		Context.ApplyAirMovement(context)

		local motor = context.Motor
		if motor:IsGrounded() or motor:GetVelocity().Y <= 0 then
			return "Fall"
		end
		return nil
	end,
}

return Jump
