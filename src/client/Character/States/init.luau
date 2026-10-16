--!strict
-- All character states, keyed by name.

local Context = require(script.Context)
local StateMachine = require(game:GetService("ReplicatedStorage").Shared.StateMachine)

local States: { [string]: StateMachine.State<Context.Context> } = {
	Idle = require(script.Idle),
	Walk = require(script.Walk),
	Sprint = require(script.Sprint),
	Roll = require(script.Roll),
	Jump = require(script.Jump),
	Fall = require(script.Fall),
	Land = require(script.Land),
	Dead = require(script.Dead),
}

return States
