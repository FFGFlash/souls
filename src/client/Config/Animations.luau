--!strict
-- Animation assets (R15) and blending settings.

local Animations = {
	Ids = {
		Idle = "rbxassetid://76157679289795",
		WalkForward = "rbxassetid://138931819291565",
		WalkBackward = "rbxassetid://83837749541337",
		WalkLeft = "rbxassetid://122445318045440",
		WalkRight = "rbxassetid://83644651265136",
		RollForward = "rbxassetid://77858067445742",
		RollBackward = "rbxassetid://132546627104511",
		RollLeft = "rbxassetid://111645930805390",
		RollRight = "rbxassetid://79227688280429",
		Land = "rbxassetid://80044599499576",
		Fall = "rbxassetid://127538891225329",
	},

	-- Movement speed the walk cycle was authored for; playback speed scales with actual speed.
	WalkReferenceSpeed = 16,
	MinPlaybackSpeed = 0.5,
	MaxPlaybackSpeed = 2,
	-- Horizontal speed at which locomotion has fully blended from idle to walking.
	IdleBlendSpeed = 6,
	-- How quickly locomotion weights follow their targets.
	BlendRate = 12,
	-- Placeholder: sprint plays WalkForward faster until a sprint animation exists.
	SprintTrack = "WalkForward",
	-- Placeholder: jumping uses the fall animation until a jump animation exists.
	JumpTrack = "Fall",
	ActionFadeTime = 0.1,
}

return Animations
