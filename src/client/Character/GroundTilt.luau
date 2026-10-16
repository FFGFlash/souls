--!strict
-- Visual-only slope tilt. The physics root always stays upright (stable collisions, no tipping over edges),
-- and the body is leaned to match the ground by adjusting the LowerTorso "Root" Motor6D's Transform.
--
-- Transform is overwritten by the Animator every frame before PreSimulation, so this runs in PreSimulation
-- and layers the tilt on top of the animated pose.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Motor = require(script.Parent.Motor)
local MovementConfig = require(script.Parent.Parent.Config.Movement)
local Rig = require(script.Parent.Rig)

export type GroundTilt = {
	SetEnabled: (self: GroundTilt, enabled: boolean) -> (),
	PreSimulation: (self: GroundTilt, dt: number) -> (),
	GetTilt: (self: GroundTilt) -> (number, number),
	Destroy: (self: GroundTilt) -> (),
}

type Impl = {
	Rig: Rig.Rig,
	Motor: Motor.Motor,
	Config: typeof(MovementConfig.Tilt),
	Enabled: boolean,

	Pitch: number,
	Roll: number,
	-- The last Transform we wrote, and the animated pose it was built from (see PreSimulation).
	LastWritten: CFrame?,
	LastBase: CFrame,
}

local GroundTilt = {}
GroundTilt.__index = GroundTilt

function GroundTilt.new(rig: Rig.Rig, motor: Motor.Motor): GroundTilt
	local self: Impl = {
		Rig = rig,
		Motor = motor,
		Config = MovementConfig.Tilt,
		Enabled = MovementConfig.Tilt.Enabled,
		Pitch = 0,
		Roll = 0,
		LastWritten = nil,
		LastBase = CFrame.identity,
	}
	return (setmetatable(self, GroundTilt) :: any) :: GroundTilt
end

function GroundTilt.SetEnabled(self: Impl, enabled: boolean)
	self.Enabled = enabled and self.Config.Enabled
end

function GroundTilt.GetTilt(self: Impl): (number, number)
	return self.Pitch, self.Roll
end

-- Height of the ground under `origin`, or nil if nothing is in range.
local function probe(self: Impl, origin: Vector3, depth: number): number?
	local result = workspace:Raycast(origin, Vector3.new(0, -depth, 0), self.Rig.RaycastParams)
	return result and result.Position.Y
end

-- Target (pitch, roll) in the root's local space that aligns the body with the ground.
local function computeTarget(self: Impl): (number, number)
	if not self.Enabled or not self.Motor:IsGrounded() then
		return 0, 0
	end

	local config = self.Config
	local root = self.Rig.Root
	local forward = MathUtil.FlatUnit(root.CFrame.LookVector)
	local right = MathUtil.FlatUnit(root.CFrame.RightVector)
	if forward.Magnitude == 0 or right.Magnitude == 0 then
		return 0, 0
	end

	local origin = root.Position
	local offset = config.ProbeOffset
	local depth = self.Rig:GetStandingHeight() + config.ProbeDepth

	local center = probe(self, origin, depth)
	local front = probe(self, origin + forward * offset, depth)
	local back = probe(self, origin - forward * offset, depth)
	local rightHeight = probe(self, origin + right * offset, depth)
	local leftHeight = probe(self, origin - right * offset, depth)
	if not (center and front and back and rightHeight and leftHeight) then
		-- At least one probe is over a drop: we're at an edge.
		return 0, 0
	end

	-- On a flat plane (any slope) the center sits halfway between opposite probes. If it doesn't, we're on
	-- stairs, a step, or the crest/foot of a slope, where tilting looks wrong.
	local tolerance = config.PlanarTolerance
	if
		math.abs(center - (front + back) / 2) > tolerance
		or math.abs(center - (rightHeight + leftHeight) / 2) > tolerance
	then
		return 0, 0
	end

	local span = offset * 2
	local frontToBack = front - back
	local rightToLeft = rightHeight - leftHeight
	local slope = math.atan2(math.sqrt(frontToBack * frontToBack + rightToLeft * rightToLeft), span)
	if slope > MovementConfig.MaxSlopeAngle then
		return 0, 0
	end

	-- Rotating +X tips the head backwards and +Z tips it to the left, which is what aligns "up" with the
	-- ground normal when the ground ahead / to the right is higher.
	local pitch = math.atan2(frontToBack, span) * config.LeanFactor
	local roll = math.atan2(rightToLeft, span) * config.LeanFactor

	local magnitude = math.sqrt(pitch * pitch + roll * roll)
	if magnitude > config.MaxAngle then
		local scale = config.MaxAngle / magnitude
		pitch *= scale
		roll *= scale
	end
	return pitch, roll
end

function GroundTilt.PreSimulation(self: Impl, dt: number)
	local joint = self.Rig:GetRootJoint()
	if not joint then
		return
	end

	local targetPitch, targetRoll = computeTarget(self)
	local rate = self.Config.Rate
	self.Pitch = MathUtil.Damp(self.Pitch, targetPitch, rate, dt)
	self.Roll = MathUtil.Damp(self.Roll, targetRoll, rate, dt)

	-- If no animation drives this joint, the Animator doesn't reset Transform and we'd read back our own
	-- previous write; reuse the pose we tilted last time so the tilt doesn't accumulate.
	local base = joint.Transform
	if self.LastWritten and base == self.LastWritten then
		base = self.LastBase
	end
	self.LastBase = base

	if math.abs(self.Pitch) < 1e-4 and math.abs(self.Roll) < 1e-4 then
		if self.LastWritten then
			joint.Transform = base
			self.LastWritten = nil
		end
		return
	end

	-- Rotate around the feet (in root space), then express that rotation in the joint's C0 frame:
	-- Part1 = Part0 * C0 * Transform * C1^-1, so a root-space change R becomes C0^-1 * R * C0 on Transform.
	local feet = Vector3.new(0, -self.Rig:GetStandingHeight(), 0)
	local tilt = CFrame.new(feet) * CFrame.Angles(self.Pitch, 0, self.Roll) * CFrame.new(-feet)
	local c0 = joint.C0
	local transform = c0:Inverse() * tilt * c0 * base

	joint.Transform = transform
	self.LastWritten = transform
end

function GroundTilt.Destroy(self: Impl)
	local joint = self.Rig:GetRootJoint()
	if joint and self.LastWritten then
		joint.Transform = self.LastBase
	end
	self.LastWritten = nil
end

return GroundTilt
