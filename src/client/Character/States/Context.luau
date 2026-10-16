--!strict
-- Shared context handed to every character state, plus helpers the states have in common.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionBuffer = require(script.Parent.Parent.Parent.Input.ActionBuffer)
local Animation = require(script.Parent.Parent.Animation)
local CameraRig = require(script.Parent.Parent.Parent.Camera.CameraRig)
local GroundTilt = require(script.Parent.Parent.GroundTilt)
local InputTypes = require(script.Parent.Parent.Parent.Input.Types)
local LockOn = require(script.Parent.Parent.Parent.Targeting.LockOn)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Motor = require(script.Parent.Parent.Motor)
-- selene: allow(unused_variable)
local MovementConfig = require(script.Parent.Parent.Parent.Config.Movement)
local Rig = require(script.Parent.Parent.Rig)

export type RollKind = "Roll" | "Backstep"

export type RollData = {
	Kind: RollKind,
	-- Flat unit direction of travel.
	Direction: Vector3,
	Duration: number,
	PeakSpeed: number,
	Curve: { { number } },
	StartedAt: number,
	-- Keep facing the lock-on target instead of the roll direction.
	KeepFacing: boolean,
}

export type Context = {
	Rig: Rig.Rig,
	Motor: Motor.Motor,
	Animation: Animation.Animation,
	Camera: CameraRig.CameraRig,
	LockOn: LockOn.LockOn,
	Tilt: GroundTilt.GroundTilt,
	Buffer: ActionBuffer.ActionBuffer,
	Config: typeof(MovementConfig),

	-- Input for the current frame (replaced every frame by the session).
	Frame: InputTypes.InputFrame,
	-- Horizontal speed carried through a jump/fall for air control.
	AirSpeed: number,
	-- The roll in progress (Roll state only).
	Roll: RollData?,
}

local Context = {}

-- Camera-relative movement direction (flat, magnitude 0..1), or zero inside the deadzone.
function Context.GetMoveIntent(context: Context): Vector3
	local move = context.Frame.Move
	if move.Magnitude < context.Config.MoveInputDeadzone then
		return Vector3.zero
	end

	local forward, right = context.Camera:GetFlatBasis()
	local direction = forward * move.Y + right * move.X
	local magnitude = math.min(direction.Magnitude, 1)
	if magnitude < 1e-4 then
		return Vector3.zero
	end
	return direction.Unit * magnitude
end

function Context.HasMoveInput(context: Context): boolean
	return context.Frame.Move.Magnitude >= context.Config.MoveInputDeadzone
end

-- Flat direction from the character to its lock-on target, if locked on.
function Context.GetTargetDirection(context: Context): Vector3?
	local point = context.LockOn:GetTargetPoint()
	if not point then
		return nil
	end
	local direction = MathUtil.FlatUnit(point - context.Rig.Root.Position)
	return if direction.Magnitude > 0 then direction else nil
end

-- Slows movement that goes against the facing direction (walking backwards while locked on).
function Context.GetBackwardScale(context: Context, direction: Vector3, facing: Vector3): number
	local alignment = MathUtil.FlatUnit(direction):Dot(facing)
	if alignment >= 0 then
		return 1
	end
	return 1 + alignment * (1 - context.Config.StrafeBackwardMultiplier)
end

-- Ground locomotion shared by Idle/Walk/Sprint.
-- faceTarget: face the lock-on target when locked (strafing) instead of the movement direction.
function Context.ApplyGroundMovement(context: Context, speed: number, faceTarget: boolean)
	local intent = Context.GetMoveIntent(context)
	local targetDirection = if faceTarget then Context.GetTargetDirection(context) else nil

	if targetDirection then
		context.Motor:SetFacing(targetDirection)
		local scale = Context.GetBackwardScale(context, intent, targetDirection)
		context.Motor:SetMove(intent, speed * scale)
	else
		if intent.Magnitude > 0 then
			context.Motor:SetFacing(intent)
		end
		context.Motor:SetMove(intent, speed)
	end
end

-- Air control shared by Jump/Fall.
function Context.ApplyAirMovement(context: Context)
	local intent = Context.GetMoveIntent(context)
	local targetDirection = Context.GetTargetDirection(context)
	context.Motor:SetFacing(targetDirection or (if intent.Magnitude > 0 then intent else nil))
	context.Motor:SetMove(intent, context.AirSpeed)
end

function Context.TryRoll(context: Context): boolean
	return context.Buffer:Consume("Roll", context.Config.Buffer.Roll)
end

function Context.TryJump(context: Context): boolean
	local motor = context.Motor
	local canJump = motor:IsGrounded() or motor:GetTimeAirborne() <= context.Config.CoyoteTime
	return canJump and context.Buffer:Consume("Jump", context.Config.Buffer.Jump)
end

-- The grounded locomotion state matching the current input.
function Context.GetLocomotionState(context: Context): string
	if not Context.HasMoveInput(context) then
		return "Idle"
	end
	return if context.Frame.SprintHeld then "Sprint" else "Walk"
end

-- Transitions every grounded state checks first, in priority order.
function Context.CheckGroundedTransitions(context: Context): string?
	if context.Motor:GetTimeAirborne() > context.Config.FallGraceTime then
		return "Fall"
	end
	if Context.TryRoll(context) then
		return "Roll"
	end
	if Context.TryJump(context) then
		return "Jump"
	end
	return nil
end

-- Horizontal speed to carry into the air.
function Context.CaptureAirSpeed(context: Context)
	local horizontal = MathUtil.Flatten(context.Motor:GetVelocity()).Magnitude
	context.AirSpeed = math.max(horizontal, context.Config.WalkSpeed)
end

return Context
