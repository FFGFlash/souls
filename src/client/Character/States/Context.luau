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
	-- Distance to the lock-on target being held while strafing around it, and which target it belongs to.
	StrafeRadius: number?,
	StrafeTarget: Model?,
}

local Context = {}

-- Flat direction from the character to its lock-on target, if locked on.
function Context.GetTargetDirection(context: Context): Vector3?
	local point = context.LockOn:GetTargetPoint()
	if not point then
		return nil
	end
	local direction = MathUtil.FlatUnit(point - context.Rig.Root.Position)
	return if direction.Magnitude > 0 then direction else nil
end

-- Flat (forward, right) basis that move input is relative to. While locked on this is the direction to the
-- target rather than the camera, so "right" is always the tangent of a circle around the target (the camera's
-- yaw lags behind the target, which made strafing drift).
function Context.GetMoveBasis(context: Context): (Vector3, Vector3)
	local targetDirection = Context.GetTargetDirection(context)
	if targetDirection then
		return targetDirection, Vector3.new(-targetDirection.Z, 0, targetDirection.X)
	end
	return context.Camera:GetFlatBasis()
end

-- Movement direction relative to the move basis (flat, magnitude 0..1), or zero inside the deadzone.
function Context.GetMoveIntent(context: Context): Vector3
	local move = context.Frame.Move
	if move.Magnitude < context.Config.MoveInputDeadzone then
		return Vector3.zero
	end

	local forward, right = Context.GetMoveBasis(context)
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
		local velocity = intent * speed * Context.GetBackwardScale(context, intent, targetDirection)
		velocity += Context.GetStrafeCorrection(context, speed)

		local magnitude = velocity.Magnitude
		if magnitude > 1e-3 then
			context.Motor:SetMove(velocity / magnitude, magnitude)
		else
			context.Motor:SetMove(Vector3.zero, speed)
		end
	else
		context.StrafeRadius = nil
		if intent.Magnitude > 0 then
			context.Motor:SetFacing(intent)
		end
		context.Motor:SetMove(intent, speed)
	end
end

-- Velocity toward the lock-on target that keeps a pure strafe on a circle around it.
--
-- Moving along the tangent always carries the character slightly outwards, and the GroundController's
-- acceleration makes its velocity lag behind the turning tangent, which pushes it out further. This adds the
-- inward velocity that lag needs (feed-forward) plus a correction toward the distance held when strafing began.
-- Any forward/backward input re-captures the distance, so approaching and backing off work normally.
function Context.GetStrafeCorrection(context: Context, speed: number): Vector3
	local config = context.Config
	local point = context.LockOn:GetTargetPoint()
	local target = context.LockOn:GetTarget()
	local move = context.Frame.Move
	if not point or not target then
		context.StrafeRadius = nil
		return Vector3.zero
	end

	local toTarget = MathUtil.Flatten(point - context.Rig.Root.Position)
	local radius = toTarget.Magnitude
	local strafing = math.abs(move.X) >= config.MoveInputDeadzone and math.abs(move.Y) < config.StrafeRadialDeadzone
	if
		not strafing
		or radius < config.StrafeMinRadius
		or context.StrafeTarget ~= target
		or not context.StrafeRadius
	then
		context.StrafeRadius = radius
		context.StrafeTarget = target
		if not strafing or radius < config.StrafeMinRadius then
			return Vector3.zero
		end
	end

	local heldRadius = context.StrafeRadius :: number
	local lateralSpeed = math.abs(move.X) * speed
	local feedForward = lateralSpeed * lateralSpeed / radius * config.AccelerationTime
	local correction = (radius - heldRadius) * config.StrafeRadiusGain + feedForward
	correction = math.clamp(correction, -speed * 0.5, speed * 0.5)

	return toTarget / radius * correction
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
