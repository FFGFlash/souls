--!strict
-- Third-person orbit camera with shoulder offset, zoom, collision, occlusion fading, recentering and lock-on
-- framing.
--
-- Anti-jitter rules: rotation comes straight from Yaw/Pitch and is never lerped; only the focus point is
-- damped. The camera reads the root's current physics pose every frame and is the only writer of
-- CurrentCamera.CFrame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CameraConfig = require(script.Parent.Parent.Config.Camera)
local InputTypes = require(script.Parent.Parent.Input.Types)
local LockOn = require(script.Parent.Parent.Targeting.LockOn)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Occlusion = require(script.Parent.Occlusion)
local Rig = require(script.Parent.Parent.Character.Rig)

type InputFrame = InputTypes.InputFrame

export type CameraRig = {
	UpdateOrientation: (self: CameraRig, frame: InputFrame, dt: number, characterMoving: boolean) -> (),
	UpdateTransform: (self: CameraRig, frame: InputFrame, dt: number) -> (),

	-- Flat forward/right vectors of the camera's yaw (for camera-relative movement).
	GetFlatBasis: (self: CameraRig) -> (Vector3, Vector3),
	GetFocus: (self: CameraRig) -> Vector3,
	GetCFrame: (self: CameraRig) -> CFrame,
	Recenter: (self: CameraRig) -> (),
	SwapShoulder: (self: CameraRig) -> (),
	AdjustZoom: (self: CameraRig, delta: number) -> (),
	Destroy: (self: CameraRig) -> (),
}

type Impl = {
	Rig: Rig.Rig,
	LockOn: LockOn.LockOn,
	Config: typeof(CameraConfig),
	Occlusion: Occlusion.Occlusion,
	CollisionParams: RaycastParams,

	Yaw: number,
	Pitch: number,
	Focus: Vector3,
	Zoom: number,
	ZoomTarget: number,
	Distance: number,
	Shoulder: number,
	ShoulderTarget: number,
	LastLookInputAt: number,
	Recentering: boolean,
	CFrame: CFrame,
}

local CameraRig = {}
CameraRig.__index = CameraRig

local function getRawFocus(self: Impl): Vector3
	return self.Rig.Root.Position + Vector3.new(0, self.Config.FocusHeight, 0)
end

function CameraRig.new(rig: Rig.Rig, lockOn: LockOn.LockOn): CameraRig
	local config = CameraConfig

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { rig.Character }
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local self: Impl = {
		Rig = rig,
		LockOn = lockOn,
		Config = config,
		Occlusion = Occlusion.new(rig),
		CollisionParams = params,

		Yaw = MathUtil.YawFromDirection(rig.Root.CFrame.LookVector),
		Pitch = config.DefaultPitch,
		Focus = Vector3.zero,
		Zoom = config.Zoom.Default,
		ZoomTarget = config.Zoom.Default,
		Distance = config.Zoom.Default,
		Shoulder = 1,
		ShoulderTarget = 1,
		LastLookInputAt = os.clock(),
		Recentering = false,
		CFrame = CFrame.identity,
	}
	self.Focus = getRawFocus(self)

	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = config.FieldOfView
	end

	return (setmetatable(self, CameraRig) :: any) :: CameraRig
end

local function getCharacterYaw(self: Impl): number
	return MathUtil.YawFromDirection(self.Rig.Root.CFrame.LookVector)
end

local function updateLockedOrientation(self: Impl, targetPoint: Vector3, dt: number)
	local config = self.Config.LockOn
	local offset = targetPoint - self.Focus
	local horizontal = math.max(MathUtil.Flatten(offset).Magnitude, config.MinHorizontalDistance)

	local desiredYaw = if MathUtil.Flatten(offset).Magnitude > 1e-3 then MathUtil.YawFromDirection(offset) else self.Yaw
	local desiredPitch =
		math.clamp(math.atan2(offset.Y, horizontal) + config.PitchBias, config.MinPitch, config.MaxPitch)

	self.Yaw = MathUtil.DampAngle(self.Yaw, desiredYaw, config.YawRate, dt)
	self.Pitch = MathUtil.Damp(self.Pitch, desiredPitch, config.PitchRate, dt)
end

function CameraRig.UpdateOrientation(self: Impl, frame: InputFrame, dt: number, characterMoving: boolean)
	local config = self.Config
	local now = os.clock()

	local targetPoint = self.LockOn:GetTargetPoint()
	if targetPoint then
		self.Recentering = false
		self.LastLookInputAt = now
		updateLockedOrientation(self, targetPoint, dt)
		return
	end

	if frame.LookActive then
		self.Yaw = MathUtil.WrapAngle(self.Yaw - frame.LookDelta.X)
		self.Pitch = math.clamp(self.Pitch + frame.LookDelta.Y, config.MinPitch, config.MaxPitch)
		self.LastLookInputAt = now
		self.Recentering = false
	end

	local recenter = config.Recenter
	if self.Recentering then
		local targetYaw = getCharacterYaw(self)
		self.Yaw = MathUtil.DampAngle(self.Yaw, targetYaw, recenter.Rate, dt)
		self.Pitch = MathUtil.Damp(self.Pitch, config.DefaultPitch, recenter.Rate, dt)
		if math.abs(MathUtil.WrapAngle(targetYaw - self.Yaw)) < 0.01 then
			self.Recentering = false
		end
	elseif recenter.AutoWhenIdle and not characterMoving and now - self.LastLookInputAt > recenter.IdleDelay then
		-- Only while standing still: recentering while moving would steer camera-relative movement in circles.
		self.Yaw = MathUtil.DampAngle(self.Yaw, getCharacterYaw(self), recenter.IdleRate, dt)
	end
end

-- Moves from `origin` along `offset`, stopping short of anything in the way. Returns the distance travelled.
local function castDistance(self: Impl, origin: Vector3, offset: Vector3): number
	local length = offset.Magnitude
	if length < 1e-3 then
		return 0
	end

	local collision = self.Config.Collision
	for _ = 1, 4 do
		local result = workspace:Spherecast(origin, collision.Radius, offset, self.CollisionParams)
		if not result then
			break
		end

		-- Characters (NPCs, other players) shouldn't shove the camera around; ignore them from now on.
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			self.CollisionParams:AddToFilter(model)
			continue
		end

		return math.max(result.Distance - collision.Buffer, 0)
	end
	return length
end

function CameraRig.UpdateTransform(self: Impl, frame: InputFrame, dt: number)
	local config = self.Config
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- Focus: lightly damped (softer vertically to hide stair steps), snapping on teleports.
	local rawFocus = getRawFocus(self)
	if (rawFocus - self.Focus).Magnitude > config.FocusSnapDistance then
		self.Focus = rawFocus
	else
		local focus = self.Focus
		local horizontalAlpha = MathUtil.ExpAlpha(config.FocusRateHorizontal, dt)
		self.Focus = Vector3.new(
			focus.X + (rawFocus.X - focus.X) * horizontalAlpha,
			MathUtil.Damp(focus.Y, rawFocus.Y, config.FocusRateVertical, dt),
			focus.Z + (rawFocus.Z - focus.Z) * horizontalAlpha
		)
	end
	local focus = self.Focus

	local locked = self.LockOn:IsLocked()
	local rotation = CFrame.fromEulerAnglesYXZ(self.Pitch, self.Yaw, 0)

	-- Shoulder offset, shortened if there's a wall beside the character.
	self.Shoulder = MathUtil.Damp(self.Shoulder, self.ShoulderTarget, config.Shoulder.Rate, dt)
	local shoulderOffset = rotation.RightVector
		* config.Shoulder.Offset
		* self.Shoulder
		* (if locked then config.Shoulder.LockedScale else 1)
	local pivot = focus
	if shoulderOffset.Magnitude > 1e-3 then
		pivot = focus + shoulderOffset.Unit * castDistance(self, focus, shoulderOffset)
	end

	-- Zoom and collision: pull in instantly, ease back out.
	local zoomTarget = if locked then config.Zoom.Locked else self.ZoomTarget
	self.Zoom = MathUtil.Damp(self.Zoom, zoomTarget, config.Zoom.Rate, dt)

	local back = -rotation.LookVector
	local allowed = math.max(castDistance(self, pivot, back * self.Zoom), config.Collision.MinDistance)
	if allowed < self.Distance then
		self.Distance = allowed
	else
		self.Distance = MathUtil.Damp(self.Distance, allowed, config.Collision.RecoverRate, dt)
	end

	local position = pivot + back * self.Distance
	local cameraCFrame = CFrame.new(position) * rotation
	self.CFrame = cameraCFrame
	camera.CFrame = cameraCFrame
	camera.Focus = CFrame.new(focus)

	-- Only write these when they change: re-assigning the mouse lock every frame can cause mouse delta spikes.
	local mouseBehavior = if frame.FreeCursor then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	if UserInputService.MouseBehavior ~= mouseBehavior then
		UserInputService.MouseBehavior = mouseBehavior
	end
	if UserInputService.MouseIconEnabled ~= frame.FreeCursor then
		UserInputService.MouseIconEnabled = frame.FreeCursor
	end

	self.Occlusion:Update(dt, position, focus)
end

function CameraRig.GetFlatBasis(self: Impl): (Vector3, Vector3)
	local forward = MathUtil.DirectionFromYaw(self.Yaw)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	return forward, right
end

function CameraRig.GetFocus(self: Impl): Vector3
	return self.Focus
end

function CameraRig.GetCFrame(self: Impl): CFrame
	return self.CFrame
end

function CameraRig.Recenter(self: Impl)
	self.Recentering = true
end

function CameraRig.SwapShoulder(self: Impl)
	self.ShoulderTarget = -self.ShoulderTarget
end

function CameraRig.AdjustZoom(self: Impl, delta: number)
	local zoom = self.Config.Zoom
	self.ZoomTarget = math.clamp(self.ZoomTarget + delta, zoom.Min, zoom.Max)
end

function CameraRig.Destroy(self: Impl)
	self.Occlusion:Destroy()
end

return CameraRig
