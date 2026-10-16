--!strict
-- Walking. Faces the movement direction, or strafes around the lock-on target (slower when moving backwards).

local Context = require(script.Parent.Context)
local StateMachine = require(game:GetService("ReplicatedStorage").Shared.StateMachine)

type Context = Context.Context

local Walk: StateMachine.State<Context> = {
	Enter = function(context: Context)
		context.Animation:SetLocomotion("Ground")
		context.Tilt:SetEnabled(true)
	end,

	Update = function(context: Context): string?
		local transition = Context.CheckGroundedTransitions(context)
		if transition then
			return transition
		end

		local locomotion = Context.GetLocomotionState(context)
		if locomotion ~= "Walk" then
			return locomotion
		end

		Context.ApplyGroundMovement(context, context.Config.WalkSpeed, true)
		return nil
	end,
}

return Walk
