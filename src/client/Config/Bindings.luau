--!strict
-- Default input bindings and input-feel settings (Elden Ring style). Every binding list accepts any mix of
-- Enum.KeyCode (keyboard keys and gamepad buttons) and Enum.UserInputType (mouse buttons).

local Bindings = {
	Move = {
		Forward = { Enum.KeyCode.W } :: { EnumItem },
		Backward = { Enum.KeyCode.S } :: { EnumItem },
		Left = { Enum.KeyCode.A } :: { EnumItem },
		Right = { Enum.KeyCode.D } :: { EnumItem },
	},

	Actions = {
		-- Tap to roll (on release), hold to sprint.
		Dodge = { Enum.KeyCode.Space, Enum.KeyCode.ButtonB },
		Jump = { Enum.KeyCode.F, Enum.KeyCode.ButtonA },
		LockOn = { Enum.UserInputType.MouseButton3, Enum.KeyCode.Q, Enum.KeyCode.ButtonR3 },
		ShoulderSwap = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonL3 },
		-- Hold to release the mouse cursor (handy in Studio).
		FreeCursor = { Enum.KeyCode.LeftAlt },
	} :: { [string]: { EnumItem } },

	-- How long dodge must be held before it counts as sprinting instead of a roll.
	DodgeHoldTime = 0.22,

	Mouse = {
		-- Radians of camera rotation per pixel of mouse movement.
		Sensitivity = 0.003,
		InvertX = false,
		InvertY = false,
	},

	Gamepad = {
		MoveDeadzone = 0.15,
		MoveOuterDeadzone = 0.95,
		LookDeadzone = 0.12,
		-- Exponent applied to look stick magnitude; > 1 gives finer control near the center.
		LookResponseCurve = 1.8,
		-- Radians per second at full deflection.
		LookSpeedX = 3.5,
		LookSpeedY = 2.2,
		InvertX = false,
		InvertY = false,
		-- Right-stick flick used to switch lock-on targets: must cross FlickThreshold, then return below FlickReset.
		FlickThreshold = 0.8,
		FlickReset = 0.3,
	},
}

return Bindings
