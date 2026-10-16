--!strict
-- Terminal state. Hands the character back to the default Humanoid so Roblox's death handling runs.

local Context = require(script.Parent.Context)
local StateMachine = require(game:GetService("ReplicatedStorage").Shared.StateMachine)

type Context = Context.Context

local Dead: StateMachine.State<Context> = {
	Enter = function(context: Context)
		context.Tilt:SetEnabled(false)
		context.Animation:StopActions(0.1)
		context.Animation:SetLocomotion("None")
		context.Motor:Destroy()
	end,

	Update = function(): string?
		return nil
	end,
}

return Dead
