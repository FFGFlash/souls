--!strict
-- Rolling (with move input) or backstepping (without). Velocity follows a speed curve through the motor's
-- override, so the distance is the same at any frame rate. While locked on the character keeps facing the
-- target and plays the directional roll animation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local StateMachine = require(ReplicatedStorage.Shared.StateMachine)

type Context = Context.Context

local function beginRoll(context: Context)
	local config = context.Config
	local motor = context.Motor

	local intent = Context.GetMoveIntent(context)
	local facing = motor:GetFacing()
	local targetDirection = Context.GetTargetDirection(context)
	local keepFacing = targetDirection ~= nil and config.LockedRollKeepsFacing

	local isRoll = intent.Magnitude > 0
	local settings = if isRoll then config.Roll else config.Backstep
	local direction = if isRoll then intent.Unit else -(targetDirection or facing)

	-- Rolls turn to face their direction instantly; backsteps (and locked-on rolls) keep the current facing.
	local faceDirection = facing
	if keepFacing and targetDirection then
		faceDirection = targetDirection
	elseif isRoll then
		faceDirection = direction
	end
	motor:SetFacing(faceDirection)
	motor:SetTurnSpeed(config.SnapTurnSpeed)

	context.Roll = {
		Kind = if isRoll then "Roll" else "Backstep",
		Direction = direction,
		Duration = settings.Duration,
		PeakSpeed = settings.PeakSpeed,
		Curve = settings.Curve,
		StartedAt = os.clock(),
		KeepFacing = keepFacing,
	}

	local animation = context.Animation
	animation:StopActions(0.05)
	animation:SetLocomotion("None")
	animation:PlayRoll(MathUtil.SignedAngleY(faceDirection, direction), settings.Duration)

	motor:SetOverrideVelocity(direction * settings.PeakSpeed * MathUtil.SampleCurve(settings.Curve, 0))
end

local Roll: StateMachine.State<Context> = {
	Enter = function(context: Context)
		context.Tilt:SetEnabled(false)
		beginRoll(context)
	end,

	Update = function(context: Context): string?
		local roll = context.Roll
		if not roll then
			return "Idle"
		end

		local config = context.Config
		local motor = context.Motor
		local elapsed = os.clock() - roll.StartedAt
		local progress = elapsed / roll.Duration

		if elapsed >= config.SnapTurnTime then
			motor:SetTurnSpeed(nil)
		end
		if roll.KeepFacing then
			motor:SetFacing(Context.GetTargetDirection(context))
		end

		if motor:GetTimeAirborne() > config.Roll.AirborneGrace then
			-- Rolled off a ledge: the fall keeps the roll's momentum.
			return "Fall"
		end
		if progress >= 1 then
			return Context.GetLocomotionState(context)
		end
		if progress >= config.Roll.ChainAfter and Context.TryRoll(context) then
			beginRoll(context)
			return nil
		end
		if progress >= config.Roll.JumpCancelAfter and Context.TryJump(context) then
			return "Jump"
		end

		motor:SetOverrideVelocity(roll.Direction * roll.PeakSpeed * MathUtil.SampleCurve(roll.Curve, progress))
		return nil
	end,

	Exit = function(context: Context)
		context.Motor:SetOverrideVelocity(nil)
		context.Motor:SetTurnSpeed(nil)
		context.Animation:StopActions(0.15)
		context.Animation:SetLocomotion("Ground")
		context.Roll = nil
	end,
}

return Roll
