--!strict
-- Character movement tuning. Speeds are studs/second, times are seconds, angles are radians.

local Movement = {
	WalkSpeed = 16,
	SprintSpeed = 26,
	-- Speed multiplier when moving directly away from where the character faces (locked-on strafing).
	StrafeBackwardMultiplier = 0.6,
	-- Move input below this magnitude counts as no input.
	MoveInputDeadzone = 0.1,

	-- GroundController: time to reach full speed / to stop.
	AccelerationTime = 0.15,
	DecelerationTime = 0.1,
	-- AirController: steering acceleration while airborne (studs/s^2).
	AirAcceleration = 40,

	-- ControllerManager.BaseTurnSpeed while turning normally, and the near-instant turn used when a roll starts.
	TurnSpeed = 12,
	SnapTurnSpeed = 40,
	SnapTurnTime = 0.08,

	-- Ground detection.
	MaxSlopeAngle = math.rad(50),
	-- Added to Humanoid.HipHeight for GroundController.GroundOffset. Raise it if the character sinks into
	-- the floor, lower it if the character floats.
	GroundOffsetAdjust = 0,
	-- Extra distance below the feet that the ground sensor searches (used for stepping down / snapping).
	GroundSearchMargin = 1.5,
	-- When airborne, how close to standing height the character must be before it counts as landed.
	LandTolerance = 0.5,
	GroundSnap = {
		Enabled = true,
		-- Snap down when hovering more than this far above standing height while grounded.
		Threshold = 0.3,
		Speed = 25,
	},

	-- Acceleration the override LinearVelocity may use to hold its velocity (rolls, root motion, knockback).
	OverrideAcceleration = 1500,

	-- How long the character can be ungrounded before falling, and the late-jump window after leaving a ledge.
	FallGraceTime = 0.1,
	CoyoteTime = 0.1,

	Jump = {
		Height = 6,
		-- Ground detection is ignored for this long after a jump so the character isn't snapped back down.
		Lockout = 0.15,
	},

	-- Falling further than this triggers the hard landing state.
	HardLandingHeight = 14,

	Roll = {
		Duration = 0.7,
		PeakSpeed = 28,
		-- Speed multiplier over normalized roll time: { time, multiplier }.
		Curve = { { 0, 0.6 }, { 0.08, 1 }, { 0.45, 1 }, { 0.75, 0.25 }, { 1, 0 } },
		-- Fraction of the roll after which a buffered roll chains into another roll / a jump can cancel it.
		ChainAfter = 0.75,
		JumpCancelAfter = 0.8,
		-- Rolling off a ledge becomes a fall after this long in the air.
		AirborneGrace = 0.15,
	},

	-- Rolling with no move input.
	Backstep = {
		Duration = 0.45,
		PeakSpeed = 20,
		Curve = { { 0, 1 }, { 0.5, 0.8 }, { 1, 0 } },
	},

	-- When locked on, roll without turning and play the directional roll animations (souls behaviour).
	-- When false, the character always turns to face the roll direction.
	LockedRollKeepsFacing = true,

	Land = {
		Duration = 0.6,
		RollCancelAfter = 0.35,
	},

	-- How long a press stays buffered.
	Buffer = {
		Roll = 0.2,
		Jump = 0.15,
	},

	-- Visual-only body tilt to match the ground slope (see Character/GroundTilt.luau).
	Tilt = {
		Enabled = true,
		-- Distance of the four ground probes from the root, and how far below the feet they search.
		ProbeOffset = 0.9,
		ProbeDepth = 2,
		-- Height difference between opposite probes above which we assume an edge/stairs and stop tilting.
		MaxStepDelta = 1.2,
		-- Fraction of the slope angle to tilt by, and the maximum tilt.
		LeanFactor = 0.6,
		MaxAngle = math.rad(12),
		Rate = 8,
	},
}

return Movement
