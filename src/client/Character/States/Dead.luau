--!strict
-- Terminal state. Ragdolls the body and hands the character back to the default Humanoid so Roblox's death
-- handling (and respawning) runs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local StateMachine = require(ReplicatedStorage.Shared.StateMachine)

type Context = Context.Context

local Dead: StateMachine.State<Context> = {
	Enter = function(context: Context)
		context.Tilt:SetEnabled(false)
		context.Animation:StopActions(0.1)
		context.Animation:SetLocomotion("None")
		-- Re-enables Humanoid.EvaluateStateMachine.
		context.Motor:Destroy()
		-- Locally first for an instant response; the server repeats it when it sees the death. This client
		-- simulates its own body, so it adds the colliders.
		Ragdoll.Activate(context.Rig.Character, true)

		-- The Humanoid doesn't re-check Health when its state machine is re-enabled, and the client owns its
		-- state: the server only learns of the death (and respawns the player) once the state replicates as Dead.
		-- This matters most for the reset button, whose Health = 0 is set locally and never replicates.
		local humanoid = context.Rig.Humanoid
		if humanoid.Parent and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end
	end,

	Update = function(context: Context): string?
		Ragdoll.KeepRootAttached(context.Rig.Character)
		return nil
	end,
}

return Dead
