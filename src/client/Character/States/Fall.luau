--!strict
-- Airborne. Keeps momentum with limited air control, and picks the landing state on touchdown.

local Context = require(script.Parent.Context)
local StateMachine = require(game:GetService("ReplicatedStorage").Shared.StateMachine)

type Context = Context.Context

local Fall: StateMachine.State<Context> = {
	Enter = function(context: Context, previous: string?)
		if previous ~= "Jump" then
			Context.CaptureAirSpeed(context)
		end
		context.Animation:SetLocomotion("Air")
		context.Tilt:SetEnabled(false)
	end,

	Update = function(context: Context): string?
		local motor = context.Motor
		if not motor:IsGrounded() then
			-- Late jump just after walking off a ledge.
			if Context.TryJump(context) then
				return "Jump"
			end
			Context.ApplyAirMovement(context)
			return nil
		end

		if motor:GetFallHeight() > context.Config.HardLandingHeight then
			return "Land"
		end
		-- Honour a roll/jump pressed just before touching down.
		if Context.TryRoll(context) then
			return "Roll"
		end
		if Context.TryJump(context) then
			return "Jump"
		end
		return Context.GetLocomotionState(context)
	end,

	Exit = function(context: Context)
		context.Animation:SetLocomotion("Ground")
	end,
}

return Fall
