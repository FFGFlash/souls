--!strict
-- Lock-on target selection and upkeep: acquiring the best target in view, switching left/right, and breaking
-- the lock when the target dies, gets too far away or stays out of sight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraConfig = require(script.Parent.Parent.Config.Camera)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Rig = require(script.Parent.Parent.Character.Rig)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tags = require(ReplicatedStorage.Shared.Tags)
local TargetRegistry = require(script.Parent.TargetRegistry)

export type LockOn = {
	-- Fires with the new target (nil when the lock is released).
	Changed: Signal.Signal<Model?>,

	TryAcquire: (self: LockOn, camera: CFrame) -> boolean,
	-- direction: 1 = right, -1 = left (relative to the camera).
	Switch: (self: LockOn, direction: number, camera: CFrame) -> boolean,
	Release: (self: LockOn) -> (),
	Update: (self: LockOn, dt: number, eye: Vector3) -> (),

	IsLocked: (self: LockOn) -> boolean,
	GetTarget: (self: LockOn) -> Model?,
	GetTargetPoint: (self: LockOn) -> Vector3?,
	Destroy: (self: LockOn) -> (),
}

type Impl = {
	Changed: Signal.Signal<Model?>,
	Rig: Rig.Rig,
	Registry: TargetRegistry.TargetRegistry,
	Config: typeof(CameraConfig.LockOn),

	Target: Model?,
	OutOfSightSince: number?,
	LastSwitchAt: number,
}

local LockOn = {}
LockOn.__index = LockOn

local function getTargetRoot(model: Model): BasePart?
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and root.Parent then
		return root
	end
	return nil
end

local function isAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function getAimPoint(self: Impl, model: Model): Vector3?
	local point = model:FindFirstChild("LockOnPoint", true)
	if point and point:IsA("Attachment") then
		return point.WorldPosition
	end

	local root = getTargetRoot(model)
	return root and root.Position + Vector3.new(0, self.Config.PointHeight, 0)
end

local function isValidTarget(self: Impl, model: Model): boolean
	return model ~= self.Rig.Character
		and model.Parent ~= nil
		and model:HasTag(Tags.LockOnTarget)
		and isAlive(model)
		and getTargetRoot(model) ~= nil
end

local function hasLineOfSight(self: Impl, from: Vector3, to: Vector3, target: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.Rig.Character, target }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	return workspace:Raycast(from, to - from, params) == nil
end

local function setTarget(self: Impl, target: Model?)
	if self.Target == target then
		return
	end
	self.Target = target
	self.OutOfSightSince = nil
	self.Changed:Fire(target)
end

function LockOn.new(rig: Rig.Rig, registry: TargetRegistry.TargetRegistry): LockOn
	local self: Impl = {
		Changed = Signal.new(),
		Rig = rig,
		Registry = registry,
		Config = CameraConfig.LockOn,
		Target = nil,
		OutOfSightSince = nil,
		LastSwitchAt = 0,
	}
	return (setmetatable(self, LockOn) :: any) :: LockOn
end

function LockOn.TryAcquire(self: Impl, camera: CFrame): boolean
	local config = self.Config
	local currentCamera = workspace.CurrentCamera
	local origin = self.Rig.Root.Position

	local best: Model? = nil
	local bestScore = math.huge

	for model in self.Registry:GetTargets() do
		if not isValidTarget(self, model) then
			continue
		end
		local point = getAimPoint(self, model)
		if not point then
			continue
		end

		local distance = (point - origin).Magnitude
		if distance > config.AcquireDistance then
			continue
		end

		local toTarget = point - camera.Position
		local angle = math.acos(math.clamp(camera.LookVector:Dot(toTarget.Unit), -1, 1))
		if angle > config.MaxAngle then
			continue
		end

		if currentCamera then
			local _, onScreen = currentCamera:WorldToViewportPoint(point)
			if not onScreen then
				continue
			end
		end

		if not hasLineOfSight(self, camera.Position, point, model) then
			continue
		end

		local score = math.deg(angle) + distance * 0.5
		if score < bestScore then
			best, bestScore = model, score
		end
	end

	if best then
		setTarget(self, best)
		return true
	end
	return false
end

function LockOn.Switch(self: Impl, direction: number, camera: CFrame): boolean
	local current = self.Target
	local now = os.clock()
	if not current or now - self.LastSwitchAt < self.Config.SwitchCooldown then
		return false
	end

	local currentPoint = getAimPoint(self, current)
	if not currentPoint then
		return false
	end

	local origin = self.Rig.Root.Position
	local toCurrent = currentPoint - camera.Position

	local best: Model? = nil
	local bestAngle = math.huge

	for model in self.Registry:GetTargets() do
		if model == current or not isValidTarget(self, model) then
			continue
		end
		local point = getAimPoint(self, model)
		if not point or (point - origin).Magnitude > self.Config.AcquireDistance then
			continue
		end

		-- Positive = to the right of the current target from the camera's point of view.
		local angle = MathUtil.SignedAngleY(toCurrent, point - camera.Position) * direction
		if angle <= 0 or angle >= bestAngle then
			continue
		end
		if not hasLineOfSight(self, camera.Position, point, model) then
			continue
		end

		best, bestAngle = model, angle
	end

	if best then
		self.LastSwitchAt = now
		setTarget(self, best)
		return true
	end
	return false
end

function LockOn.Release(self: Impl)
	setTarget(self, nil)
end

function LockOn.Update(self: Impl, _dt: number, eye: Vector3)
	local target = self.Target
	if not target then
		return
	end

	local point = getAimPoint(self, target)
	if not point or not isValidTarget(self, target) then
		setTarget(self, nil)
		return
	end

	if (point - self.Rig.Root.Position).Magnitude > self.Config.BreakDistance then
		setTarget(self, nil)
		return
	end

	if hasLineOfSight(self, eye, point, target) then
		self.OutOfSightSince = nil
	else
		local since = self.OutOfSightSince or os.clock()
		self.OutOfSightSince = since
		if os.clock() - since > self.Config.LoseSightTime then
			setTarget(self, nil)
		end
	end
end

function LockOn.IsLocked(self: Impl): boolean
	return self.Target ~= nil
end

function LockOn.GetTarget(self: Impl): Model?
	return self.Target
end

function LockOn.GetTargetPoint(self: Impl): Vector3?
	local target = self.Target
	return target and getAimPoint(self, target)
end

function LockOn.Destroy(self: Impl)
	self.Target = nil
	self.Changed:Destroy()
end

return LockOn
