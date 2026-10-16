--!strict
-- Loads the character's animation tracks and drives them.
--
--  * Locomotion (idle, 4-way walk, sprint, fall) is a set of looping tracks that always play; their weights are
--    blended every frame from the character's velocity.
--  * Actions (rolls, landing) are one-shots played on top at Action priority.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationsConfig = require(script.Parent.Parent.Config.Animations)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Rig = require(script.Parent.Rig)
local Trove = require(ReplicatedStorage.Shared.Trove)

export type LocomotionMode = "Ground" | "Sprint" | "Air" | "None"

export type Animation = {
	SetLocomotion: (self: Animation, mode: LocomotionMode) -> (),
	UpdateLocomotion: (self: Animation, dt: number) -> (),
	PlayAction: (self: Animation, name: string, fadeTime: number?, speed: number?) -> AnimationTrack?,
	-- Plays the roll animation(s) matching `localAngle` (radians, 0 = forward, +pi/2 = right) over `duration`.
	PlayRoll: (self: Animation, localAngle: number, duration: number) -> (),
	StopAction: (self: Animation, name: string, fadeTime: number?) -> (),
	StopActions: (self: Animation, fadeTime: number?) -> (),
	Destroy: (self: Animation) -> (),
}

type Impl = {
	Rig: Rig.Rig,
	Config: typeof(AnimationsConfig),
	Trove: Trove.Trove,
	Tracks: { [string]: AnimationTrack },
	Mode: LocomotionMode,
	-- Current blended weight per locomotion track.
	Weights: { [string]: number },
	ActiveActions: { [string]: AnimationTrack },
}

local LOCOMOTION_TRACKS = { "Idle", "WalkForward", "WalkBackward", "WalkLeft", "WalkRight", "Fall" }
-- Tracks can't play at exactly zero weight reliably, so "off" locomotion tracks idle at this weight.
local MIN_WEIGHT = 1e-3

local Animation = {}
Animation.__index = Animation

function Animation.new(rig: Rig.Rig): Animation
	local config = AnimationsConfig
	local trove = Trove.new()
	local tracks: { [string]: AnimationTrack } = {}
	local instances: { Instance } = {}

	for name, id in config.Ids do
		local animation = trove:Add(Instance.new("Animation"))
		animation.Name = name
		animation.AnimationId = id
		table.insert(instances, animation)

		local ok, result = pcall(function()
			return rig.Animator:LoadAnimation(animation)
		end)
		if ok then
			local track: AnimationTrack = result
			trove:Add(track)
			tracks[name] = track
		else
			warn(`[Animation] Failed to load "{name}" ({id}):`, result)
		end
	end

	-- Preload in the background so Length is known for duration scaling.
	trove:Add(task.spawn(function()
		ContentProvider:PreloadAsync(instances)
	end))

	local self: Impl = {
		Rig = rig,
		Config = config,
		Trove = trove,
		Tracks = tracks,
		Mode = "Ground",
		Weights = {},
		ActiveActions = {},
	}

	for _, name in LOCOMOTION_TRACKS do
		local track = tracks[name]
		if track then
			track.Priority = Enum.AnimationPriority.Movement
			track.Looped = true
			local weight = if name == "Idle" then 1 else MIN_WEIGHT
			self.Weights[name] = weight
			track:Play(0, weight, 1)
		end
	end

	return (setmetatable(self, Animation) :: any) :: Animation
end

function Animation.SetLocomotion(self: Impl, mode: LocomotionMode)
	self.Mode = mode
end

-- Target weights and playback speeds for the locomotion tracks this frame.
local function computeLocomotionTargets(self: Impl): ({ [string]: number }, number)
	local config = self.Config
	local root = self.Rig.Root
	local velocity = MathUtil.Flatten(root.AssemblyLinearVelocity)
	local speed = velocity.Magnitude

	local targets: { [string]: number } = {}
	for _, name in LOCOMOTION_TRACKS do
		targets[name] = 0
	end

	local playbackSpeed =
		math.clamp(speed / config.WalkReferenceSpeed, config.MinPlaybackSpeed, config.MaxPlaybackSpeed)

	local mode = self.Mode
	if mode == "Air" then
		targets.Fall = 1
	elseif mode == "Sprint" then
		local moving = math.clamp(speed / config.IdleBlendSpeed, 0, 1)
		targets.Idle = 1 - moving
		targets[config.SprintTrack] = moving
	elseif mode == "Ground" then
		local moving = math.clamp(speed / config.IdleBlendSpeed, 0, 1)
		targets.Idle = 1 - moving

		if moving > 0 then
			-- Angle of travel relative to facing: 0 = forward, +pi/2 = right, pi = backward.
			local localVelocity = root.CFrame:VectorToObjectSpace(velocity)
			local angle = math.atan2(localVelocity.X, -localVelocity.Z)
			targets.WalkForward = MathUtil.DirectionalWeight(angle, 0) * moving
			targets.WalkRight = MathUtil.DirectionalWeight(angle, math.pi / 2) * moving
			targets.WalkBackward = MathUtil.DirectionalWeight(angle, math.pi) * moving
			targets.WalkLeft = MathUtil.DirectionalWeight(angle, -math.pi / 2) * moving
		end
	end

	return targets, playbackSpeed
end

function Animation.UpdateLocomotion(self: Impl, dt: number)
	local targets, playbackSpeed = computeLocomotionTargets(self)
	local alpha = MathUtil.ExpAlpha(self.Config.BlendRate, dt)

	for _, name in LOCOMOTION_TRACKS do
		local track = self.Tracks[name]
		if not track then
			continue
		end

		local current = self.Weights[name] or 0
		local weight = math.max(current + (targets[name] - current) * alpha, MIN_WEIGHT)
		self.Weights[name] = weight
		track:AdjustWeight(weight, 0)

		if name ~= "Idle" and name ~= "Fall" then
			track:AdjustSpeed(playbackSpeed)
		end
	end
end

function Animation.PlayAction(self: Impl, name: string, fadeTime: number?, speed: number?): AnimationTrack?
	local track = self.Tracks[name]
	if not track then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play(fadeTime or self.Config.ActionFadeTime, 1, speed or 1)
	self.ActiveActions[name] = track
	return track
end

local function speedForDuration(track: AnimationTrack?, duration: number): number
	if track and track.Length > 0 and duration > 0 then
		return track.Length / duration
	end
	return 1
end

function Animation.PlayRoll(self: Impl, localAngle: number, duration: number)
	local backward = MathUtil.DirectionalWeight(localAngle, math.pi)
	local fade = self.Config.ActionFadeTime

	if backward > 0.4 then
		local track = self.Tracks.RollBackward
		Animation.PlayAction(self, "RollBackward", fade, speedForDuration(track, duration))
		return
	end

	local weights: { [string]: number } = {
		RollForward = MathUtil.DirectionalWeight(localAngle, 0),
		RollRight = MathUtil.DirectionalWeight(localAngle, math.pi / 2),
		RollLeft = MathUtil.DirectionalWeight(localAngle, -math.pi / 2),
	}
	for name, weight in weights do
		local track = self.Tracks[name]
		if track and weight > 0.01 then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			track:Play(fade, weight, speedForDuration(track, duration))
			self.ActiveActions[name] = track
		end
	end
end

function Animation.StopAction(self: Impl, name: string, fadeTime: number?)
	local track = self.ActiveActions[name]
	if track then
		track:Stop(fadeTime or self.Config.ActionFadeTime)
		self.ActiveActions[name] = nil
	end
end

function Animation.StopActions(self: Impl, fadeTime: number?)
	for name, track in self.ActiveActions do
		track:Stop(fadeTime or self.Config.ActionFadeTime)
		self.ActiveActions[name] = nil
	end
end

function Animation.Destroy(self: Impl)
	for _, track in self.Tracks do
		track:Stop(0)
	end
	self.Trove:Destroy()
end

return Animation
