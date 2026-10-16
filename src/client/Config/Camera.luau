--!strict
-- Camera tuning. Distances are studs, angles radians, rates are exponential damping rates (1/s; higher = snappier).

local Camera = {
	FieldOfView = 70,

	-- Point the camera orbits, above the root part.
	FocusHeight = 2.5,
	-- The focus follows the character with light damping (vertical is softer to hide stair steps).
	FocusRateHorizontal = 30,
	FocusRateVertical = 12,
	-- Teleports beyond this distance snap the focus instead of smoothing.
	FocusSnapDistance = 12,

	DefaultPitch = math.rad(-12),
	MinPitch = math.rad(-70),
	MaxPitch = math.rad(70),

	Zoom = {
		Default = 12,
		Min = 6,
		Max = 20,
		Step = 2,
		Rate = 8,
		-- Fixed distance while locked on.
		Locked = 11,
	},

	Shoulder = {
		Offset = 2,
		Rate = 8,
		-- Shoulder offset multiplier while locked on.
		LockedScale = 0.5,
	},

	Collision = {
		Radius = 0.5,
		Buffer = 0.1,
		MinDistance = 1,
		-- Collisions pull the camera in instantly; this is how quickly it moves back out.
		RecoverRate = 6,
	},

	Recenter = {
		-- Recenter behind the character when lock-on is pressed with no target.
		Rate = 12,
		-- Slowly swing behind the character after this long without look input while standing still.
		AutoWhenIdle = true,
		IdleDelay = 3,
		IdleRate = 1.5,
	},

	Occlusion = {
		Enabled = true,
		MaxHits = 6,
		-- LocalTransparencyModifier applied to parts between the camera and the character.
		Transparency = 0.75,
		Rate = 10,
		-- Fade the character out when the camera gets this close to the focus point.
		CharacterFadeStart = 3,
		CharacterFadeEnd = 1.5,
	},

	LockOn = {
		AcquireDistance = 40,
		BreakDistance = 60,
		-- Maximum angle from the camera's view direction for a new target.
		MaxAngle = math.rad(60),
		-- Lock breaks after the target has been out of sight for this long.
		LoseSightTime = 2,
		SwitchCooldown = 0.25,
		-- Aim point above the target's root part (used unless the target has a "LockOnPoint" attachment).
		PointHeight = 1.5,
		YawRate = 10,
		PitchRate = 10,
		-- Extra downward pitch so the player character stays in frame.
		PitchBias = math.rad(-8),
		MinPitch = math.rad(-35),
		MaxPitch = math.rad(20),
		-- Prevents the camera flipping when the target is right next to the player.
		MinHorizontalDistance = 3,
		-- Mouse wheel switches targets while locked; wheel up switches right when true.
		WheelUpSwitchesRight = false,
	},
}

return Camera
