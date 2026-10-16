--!strict
-- Sprinting while dodge is held. Always faces the movement direction, even when locked on.

local Context = require(script.Parent.Context)
local StateMachine = require(game:GetService("ReplicatedStorage").Shared.StateMachine)

type Context = Context.Context

local Sprint: StateMachine.State<Context> = {
	Enter = function(context: Context)
		context.Animation:SetLocomotion("Sprint")
		context.Tilt:SetEnabled(true)
	end,

	Update = function(context: Context): string?
		local transition = Context.CheckGroundedTransitions(context)
		if transition then
			return transition
		end

		local locomotion = Context.GetLocomotionState(context)
		if locomotion ~= "Sprint" then
			return locomotion
		end

		Context.ApplyGroundMovement(context, context.Config.SprintSpeed, false)
		return nil
	end,

	Exit = function(context: Context)
		context.Animation:SetLocomotion("Ground")
	end,
}

return Sprint
