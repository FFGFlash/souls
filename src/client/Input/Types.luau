--!strict

-- One-shot presses, true only on the frame they happened on.
export type Presses = {
	LockOn: boolean,
	ShoulderSwap: boolean,
	SwitchLeft: boolean,
	SwitchRight: boolean,
}

-- Actions that are buffered so they can be honoured slightly after the press (see ActionBuffer).
export type BufferedAction = "Roll" | "Jump"

-- Snapshot of the player's input for a single frame.
export type InputFrame = {
	Time: number,
	-- X = right, Y = forward. Magnitude is 0..1 (analog on gamepad).
	Move: Vector2,
	-- Camera rotation requested this frame in radians. +X = turn right, +Y = look up.
	LookDelta: Vector2,
	LookActive: boolean,
	SprintHeld: boolean,
	FreeCursor: boolean,
	-- Accumulated mouse wheel movement this frame (+ = wheel up).
	Wheel: number,
	Pressed: Presses,
}

return nil
