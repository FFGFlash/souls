--!strict
-- Hard landing after a long fall: briefly stuck in place, can be roll-cancelled near the end.

local Context = require(script.Parent.Context)
local StateMachine = require(game:GetService("ReplicatedStorage").Shared.StateMachine)

type Context = Context.Context

local Land: StateMachine.State<Context> = {
	Enter = function(context: Context)
		context.Motor:SetMove(Vector3.zero, 0)
		context.Animation:SetLocomotion("Ground")
		context.Animation:PlayAction("Land")
		context.Tilt:SetEnabled(true)
	end,

	Update = function(context: Context, _dt: number, elapsed: number): string?
		local config = context.Config.Land
		context.Motor:SetMove(Vector3.zero, 0)

		if context.Motor:GetTimeAirborne() > context.Config.FallGraceTime then
			return "Fall"
		end
		if elapsed >= config.RollCancelAfter and Context.TryRoll(context) then
			return "Roll"
		end
		if elapsed >= config.Duration then
			return Context.GetLocomotionState(context)
		end
		return nil
	end,

	Exit = function(context: Context)
		context.Animation:StopAction("Land", 0.2)
	end,
}

return Land
