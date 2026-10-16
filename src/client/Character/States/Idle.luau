--!strict
-- Standing still. Turns to face the lock-on target when locked.

local Context = require(script.Parent.Context)
local StateMachine = require(game:GetService("ReplicatedStorage").Shared.StateMachine)

type Context = Context.Context

local Idle: StateMachine.State<Context> = {
	Enter = function(context: Context)
		context.Animation:SetLocomotion("Ground")
		context.Tilt:SetEnabled(true)
	end,

	Update = function(context: Context): string?
		local transition = Context.CheckGroundedTransitions(context)
		if transition then
			return transition
		end

		Context.ApplyGroundMovement(context, context.Config.WalkSpeed, true)

		local locomotion = Context.GetLocomotionState(context)
		return if locomotion ~= "Idle" then locomotion else nil
	end,
}

return Idle
