local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local FindAllHitsOnRay = require(ReplicatedStorage.Shared.FindAllHitsOnRay)
local Signal = require(ReplicatedStorage.Shared.Classes.Signal)

local CameraController = {}
export type CameraController = typeof(CameraController)

-- ===========================
-- CAPABILITIES
-- ===========================
CameraController.Capabilities = {
	Rotation = true,
	Collision = true,
	TargetTracking = true,
	ShoulderSwap = true,
	ZoomControl = false,
	MotionSmoothing = true,
	LockOn = true,
	Debug = RunService:IsStudio(),
}

-- ===========================
-- BINDING PROPERTIES
-- ===========================
CameraController.Bindings = {
	ShoulderSwap = Enum.KeyCode.Q,
	LockOn = Enum.KeyCode.T,
	ZoomIn = Enum.KeyCode.E,
	ZoomOut = Enum.KeyCode.R,
}

-- ===========================
-- INPUT PROPERTIES
-- ===========================
CameraController.Input = {
	HorizontalSensitivity = 0.003,
	VerticalSensitivity = 0.003,
	InvertX = false,
	InvertY = false,
	MouseBehavior = Enum.MouseBehavior.LockCenter,
	MouseIconEnabled = false,
}

-- ===========================
-- POSITION PROPERTIES
-- ===========================
CameraController.Position = {
	-- Offset from target
	RightOffset = 2,
	UpOffset = 2.5,
	BackOffset = 15,

	-- Shoulder Swap Settings
	ShoulderSwapSpeed = 8,
	CurrentShoulderSide = 1,
	TargetShoulderSide = 1,

	-- Zoom Settings
	MinZoom = 5,
	MaxZoom = 25,
	ZoomSpeed = 5,
	ZoomIncrement = 2,
	CurrentZoom = 15,
	TargetZoom = 15,

	-- Smoothing
	Smoothing = 0.15,
	CurrentPosition = Vector3.zero,
	TargetPosition = Vector3.zero,
}

-- ===========================
-- ROTATION PROPERTIES
-- ===========================
CameraController.Rotation = {
	-- Pitch Constraints
	MinPitch = math.rad(-70),
	MaxPitch = math.rad(70),

	-- Smoothing
	Smoothing = 0.15,
	CurrentRotation = CFrame.identity,
	TargetRotation = CFrame.identity,

	-- Direction Vector (where camera is looking)
	Direction = Vector3.new(0, 0, -1),
	Yaw = 0,
	Pitch = 0,

	-- Auto-Rotation
	AutoRotateSpeed = math.rad(45),
	AutoRotateDelay = 3,
	LastInputTime = 0,
	AutoRotateEnabled = false,
}

-- ===========================
-- COLLISION PROPERTIES
-- ===========================
CameraController.Collision = {
	-- Occlussion Handling
	MinDistance = 2,
	CollisionBuffer = 0.5,
	OcclusionTransparency = 0.5,

	-- Raycast Parameters
	RaycastParams = nil :: RaycastParams?,

	-- Occluded Parts Tracking
	OccludedParts = {} :: { [BasePart]: number },
	OccludedPartsThisFrame = {} :: { BasePart },
}

-- ===========================
-- LOCK-ON PROPERTIES
-- ===========================
CameraController.LockOn = {
	Enabled = false,
	Target = nil :: Model?,
	MaxDistance = 50,
	BreakDistance = 60,
	TransitionSpeed = 10,

	-- Lock-On Search Settings
	SearchRadius = 40,
	MaxSearchAngle = math.rad(60),
	PreferredHeight = Vector3.new(0, 5, 0),
}

-- ===========================
-- REFERENCES
-- ===========================
CameraController.Target = nil :: Model?
CameraController.Root = nil :: Part?
CameraController.Camera = workspace.CurrentCamera

-- ===========================
-- SIGNALS
-- ===========================
CameraController.LockOnTargetChanged = Signal.new()

-- ===========================
-- PRIVATE FUNCTIONS
-- ===========================

local function getTargetPosition(target: Part, upOffset: number): Vector3
	return target.Position + Vector3.new(0, upOffset, 0)
end

local function findNearestLockOnTarget(
	playerPosition: Vector3,
	cameraDirection: Vector3,
	maxDistance: number,
	maxAngle: number,
	currentTarget: Model?
): Model?
	local character = CameraController.Target
	if not character then
		return nil
	end

	local bestTarget: Model? = nil
	local bestScore = math.huge

	for _, model in workspace:GetDescendants() do
		if not model:IsA("Model") or model == character or model == currentTarget then
			continue
		end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local rootPart = model:FindFirstChild("HumanoidRootPart")

		if not humanoid or not rootPart or humanoid.Health <= 0 or not rootPart:IsA("BasePart") then
			continue
		end

		local targetPos = rootPart.Position + CameraController.LockOn.PreferredHeight
		local dirToTarget = (targetPos - playerPosition).Unit
		local distance = (targetPos - playerPosition).Magnitude
		if distance > maxDistance then
			continue
		end

		local viewDirection = Vector3.new(-cameraDirection.X, 0, -cameraDirection.Z).Unit
		local targetDirection = Vector3.new(dirToTarget.X, 0, dirToTarget.Y).Unit

		local angle = math.acos(math.clamp(viewDirection:Dot(targetDirection), -1, 1))
		if angle > maxAngle then
			continue
		end

		local score = distance + (angle * 20)

		if score < bestScore then
			bestScore = score
			bestTarget = model
		end
	end

	return bestTarget
end

local function handleOcclusion(parts: { BasePart }, targetTransparency: number, dt: number)
	local fadeSpeed = 5

	for _, part in parts do
		if not part:IsA("BasePart") then
			continue
		end

		if CameraController.Collision.OccludedParts[part] == nil then
			CameraController.Collision.OccludedParts[part] = part.Transparency
		end

		part.Transparency = math.lerp(part.Transparency, targetTransparency, math.min(fadeSpeed * dt, 1))

		table.insert(CameraController.Collision.OccludedPartsThisFrame, part)
	end
end

local function clearOcclusion(dt: number)
	local partsToRemove = {}

	for part, originalTransparency in CameraController.Collision.OccludedParts do
		if not part or not part.Parent then
			table.insert(partsToRemove, part)
			continue
		end

		local isOccluded = false
		for _, occludedPart in CameraController.Collision.OccludedPartsThisFrame do
			if occludedPart == part then
				isOccluded = true
				break
			end
		end

		if not isOccluded then
			local fadeSpeed = 5

			part.Transparency = math.lerp(part.Transparency, originalTransparency, math.min(fadeSpeed * dt, 1))

			if math.abs(part.Transparency - originalTransparency) < 0.01 then
				part.Transparency = originalTransparency
				table.insert(partsToRemove, part)
			end
		end
	end

	for _, part in partsToRemove do
		CameraController.Collision.OccludedParts[part] = nil
	end

	CameraController.Collision.OccludedPartsThisFrame = {}
end

local function normalizeAngle(angle: number): number
	while angle > math.pi do
		angle -= 2 * math.pi
	end
	while angle < -math.pi do
		angle += 2 * math.pi
	end
	return angle
end

local function updateDirection()
	local cy = math.cos(CameraController.Rotation.Yaw)
	local sy = math.sin(CameraController.Rotation.Yaw)
	local cp = math.cos(CameraController.Rotation.Pitch)
	local sp = math.sin(CameraController.Rotation.Pitch)

	CameraController.Rotation.Direction = Vector3.new(sy * cp, -sp, cy * cp).Unit
end

local function rotateTowards(yaw: number?, pitch: number?, speed: number, dt: number)
	local alpha = math.min(speed * dt, 1)
	if yaw ~= nil then
		local deltaYaw = normalizeAngle(yaw - CameraController.Rotation.Yaw)
		CameraController.Rotation.Yaw += deltaYaw * alpha
	end
	if pitch ~= nil then
		CameraController.Rotation.Pitch = math.lerp(CameraController.Rotation.Pitch, pitch, alpha)
	end
	updateDirection()
end

-- ===========================
-- PUBLIC API
-- ===========================

function CameraController.Init(self: CameraController)
	self.Camera.CameraType = Enum.CameraType.Scriptable

	UserInputService.MouseBehavior = self.Input.MouseBehavior
	UserInputService.MouseIconEnabled = self.Input.MouseIconEnabled

	self.Collision.RaycastParams = RaycastParams.new()
	self.Collision.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.Collision.RaycastParams.IgnoreWater = true

	self:SetTarget(Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait())
end

function CameraController.Start(self: CameraController)
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		self:SetTarget(character)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if input.KeyCode == self.Bindings.ShoulderSwap and self.Capabilities.ShoulderSwap then
			self:SwapShoulder()
		elseif input.KeyCode == self.Bindings.LockOn and self.Capabilities.LockOn then
			self:ToggleLockOn()
		elseif input.KeyCode == self.Bindings.ZoomIn and self.Capabilities.ZoomControl then
			self:AdjustZoom(self.Position.ZoomIncrement)
		elseif input.KeyCode == self.Bindings.ZoomOut and self.Capabilities.ZoomControl then
			self:AdjustZoom(-self.Position.ZoomIncrement)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end)
end

function CameraController.SetTarget(self: CameraController, target: Model)
	self.Target = target
	self.Root = target.PrimaryPart

	if not self.Root then
		return
	end

	if self.Collision.RaycastParams then
		self.Collision.RaycastParams.FilterDescendantsInstances = { self.Target }
	end

	local startPosition = self.Root.Position
	self.Position.CurrentPosition = startPosition
	self.Position.TargetPosition = startPosition
	self.Rotation.CurrentRotation = CFrame.lookAt(startPosition, startPosition + self.Rotation.Direction)
	self.Rotation.TargetRotation = self.Rotation.CurrentRotation

	self.Rotation.Yaw = math.atan2(self.Rotation.Direction.X, self.Rotation.Direction.Z)
	self.Rotation.Pitch = math.asin(-self.Rotation.Direction.Y)
end

function CameraController.Update(self: CameraController, dt: number)
	if not self.Root then
		return
	end

	local positionSmoothing, rotationSmoothing = self.Position.Smoothing, self.Rotation.Smoothing

	if self.Capabilities.Rotation and not self.LockOn.Enabled then
		local delta = UserInputService:GetMouseDelta()

		if delta.X ~= 0 or delta.Y ~= 0 then
			self.Rotation.LastInputTime = tick()
		end

		local mouseSpeed = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)

		if self.Capabilities.MotionSmoothing then
			local smoothingScale = 1 / (1 + mouseSpeed * 0.02)
			positionSmoothing *= smoothingScale
			rotationSmoothing *= smoothingScale
		end

		if delta.X ~= 0 then
			local xMultiplier = self.Input.InvertX and 1 or -1
			self.Rotation.Yaw += delta.X * self.Input.HorizontalSensitivity * xMultiplier
			self.Rotation.Yaw = self.Rotation.Yaw % (2 * math.pi)
		end

		if delta.Y ~= 0 then
			local yMultiplier = self.Input.InvertY and 1 or -1
			self.Rotation.Pitch += delta.Y * self.Input.VerticalSensitivity * yMultiplier
			self.Rotation.Pitch = math.clamp(self.Rotation.Pitch, self.Rotation.MinPitch, self.Rotation.MaxPitch)
		end

		updateDirection()
	end

	if self.Rotation.AutoRotateEnabled and self.Capabilities.Rotation then
		local timeSinceInput = tick() - self.Rotation.LastInputTime
		if timeSinceInput > self.Rotation.AutoRotateDelay then
			local characterForward = self.Root.CFrame.LookVector

			rotateTowards(math.atan2(-characterForward.X, -characterForward.Z), nil, self.Rotation.AutoRotateSpeed, dt)
		end
	end

	if self.LockOn.Enabled and self.LockOn.Target and self.Capabilities.LockOn then
		local lockTarget = self.LockOn.Target:FindFirstChild("HumanoidRootPart")
		if lockTarget and lockTarget:IsA("BasePart") then
			local targetPos = lockTarget.Position + self.LockOn.PreferredHeight
			local rootPosition = getTargetPosition(self.Root, self.Position.UpOffset)

			local dirToTarget = (targetPos - rootPosition).Unit
			local distance = (targetPos - rootPosition).Magnitude

			if distance > self.LockOn.BreakDistance then
				self:ToggleLockOn()
			else
				local targetYaw = math.atan2(-dirToTarget.X, -dirToTarget.Z)
				local targetPitch = math.asin(-dirToTarget.Y)

				rotateTowards(targetYaw, targetPitch, self.LockOn.TransitionSpeed, dt)
			end
		else
			self:ToggleLockOn()
		end
	end

	if self.Capabilities.ZoomControl then
		self.Position.CurrentZoom =
			math.lerp(self.Position.CurrentZoom, self.Position.TargetZoom, math.min(self.Position.ZoomSpeed * dt, 1))
	else
		self.Position.CurrentZoom = self.Position.BackOffset
	end

	if self.Capabilities.ShoulderSwap then
		self.Position.CurrentShoulderSide = math.lerp(
			self.Position.CurrentShoulderSide,
			self.Position.TargetShoulderSide,
			math.min(self.Position.ShoulderSwapSpeed * dt, 1)
		)
	else
		self.Position.CurrentShoulderSide = 1
	end

	local rootPosition = getTargetPosition(self.Root, self.Position.UpOffset)

	if self.Capabilities.TargetTracking then
		self.Position.TargetPosition = rootPosition
	end

	local right = -self.Rotation.Direction:Cross(Vector3.yAxis).Unit
	local desiredCameraPosition = self.Position.TargetPosition
		+ self.Rotation.Direction * self.Position.CurrentZoom
		+ right * (self.Position.RightOffset * self.Position.CurrentShoulderSide)

	if self.Capabilities.Collision then
		local rayOrigin = self.Position.TargetPosition
		local rayDirection = desiredCameraPosition - rayOrigin

		local results = FindAllHitsOnRay(rayOrigin, rayDirection, self.Collision.RaycastParams)

		local lastResult = results[#results]

		if lastResult then
			local hitDistance = (lastResult.Position - rayOrigin).Magnitude
			local safeDistance = math.max(hitDistance - self.Collision.CollisionBuffer, self.Collision.MinDistance)

			desiredCameraPosition = rayOrigin + rayDirection.Unit * safeDistance

			local instances = {}
			for _, result in results do
				table.insert(instances, result.Instance)
			end

			handleOcclusion(instances, self.Collision.OcclusionTransparency, dt)
		end

		clearOcclusion(dt)
	end

	local positionAlpha = 1 - math.exp(-dt / positionSmoothing)
	self.Position.CurrentPosition = self.Position.CurrentPosition:Lerp(desiredCameraPosition, positionAlpha)

	local lookTarget = rootPosition
	if self.Capabilities.ShoulderSwap and not self.LockOn.Enabled then
		local characterRight = self.Root.CFrame.RightVector
		lookTarget = rootPosition
			- characterRight * (self.Position.RightOffset * 0.3 * self.Position.CurrentShoulderSide)
	end

	local desiredRotation = CFrame.lookAt(self.Position.CurrentPosition, lookTarget)

	local rotationAlpha = 1 - math.exp(-dt / rotationSmoothing)
	self.Rotation.CurrentRotation = self.Rotation.CurrentRotation:Lerp(desiredRotation, rotationAlpha)

	self.Camera.CFrame = self.Rotation.CurrentRotation

	if self.Capabilities.Debug then
		self:RenderDebug()
	end
end

function CameraController.RenderDebug(_self: CameraController) end

-- ===========================
-- CAPABILITY CONTROLS
-- ===========================

function CameraController.SetCapability(self: CameraController, capability: string, enabled: boolean)
	if self.Capabilities[capability] == nil then
		error("Unknown capability: " .. capability)
	end
	self.Capabilities[capability] = enabled
end

function CameraController.IsCapabilityEnabled(self: CameraController, capability: string)
	return self.Capabilities[capability] == true
end

-- ===========================
-- CAMERA CONTROLS
-- ===========================

function CameraController.SetSensitivity(self: CameraController, horizontal: number?, vertical: number?)
	if horizontal then
		self.Input.HorizontalSensitivity = horizontal
	end
	if vertical then
		self.Input.VerticalSensitivity = vertical
	end
end

function CameraController.SetInversion(self: CameraController, invertX: boolean?, invertY: boolean?)
	if invertX ~= nil then
		self.Input.InvertX = invertX
	end
	if invertY ~= nil then
		self.Input.InvertY = invertY
	end
end

function CameraController.SetZoomLimits(self: CameraController, min: number?, max: number?)
	if min then
		self.Position.MinZoom = min
		self.Position.TargetZoom = math.max(self.Position.TargetZoom, min)
	end
	if max then
		self.Position.MaxZoom = max
		self.Position.TargetZoom = math.min(self.Position.TargetZoom, max)
	end
end

function CameraController.AdjustZoom(self: CameraController, delta: number)
	if not self.Capabilities.ZoomControl then
		return
	end

	self.Position.TargetZoom =
		math.clamp(self.Position.TargetZoom + delta, self.Position.MinZoom, self.Position.MaxZoom)
end

function CameraController.SetZoom(self: CameraController, zoom: number)
	if not self.Capabilities.ZoomControl then
		return
	end
	self.Position.TargetZoom = math.clamp(zoom, self.Position.MinZoom, self.Position.MaxZoom)
end

function CameraController.SwapShoulder(self: CameraController)
	if not self.Capabilities.ShoulderSwap then
		return
	end

	self.Position.TargetShoulderSide *= -1
end

function CameraController.SetShoulderSide(self: CameraController, side: number)
	if not self.Capabilities.ShoulderSwap then
		return
	end
	self.Position.TargetShoulderSide = side >= 0 and 1 or -1
end

function CameraController.ToggleLockOn(self: CameraController)
	if not self.Capabilities.LockOn then
		return
	end

	if self.LockOn.Enabled then
		self:SetLockOnTarget(nil)
	else
		local playerPosition = self.Root and self.Root.Position or self.Position.CurrentPosition
		local target = findNearestLockOnTarget(
			playerPosition,
			self.Rotation.Direction,
			self.LockOn.SearchRadius,
			self.LockOn.MaxSearchAngle,
			nil
		)

		print("Target: ", target)

		if target then
			self:SetLockOnTarget(target)
		end
	end
end

function CameraController.SetLockOnTarget(self: CameraController, target: Model?)
	if not self.Capabilities.LockOn then
		return
	end

	self.LockOn.Target = target
	self.LockOn.Enabled = target ~= nil

	self.LockOnTargetChanged:Fire(self.LockOn.Enabled, self.LockOn.Target)
end

function CameraController.CycleLockOnTarget(self: CameraController)
	if not self.Capabilities.LockOn or not self.LockOn.Enabled then
		return
	end

	local playerPosition = self.Root and self.Root.Position or self.Position.CurrentPosition
	local nextTarget = findNearestLockOnTarget(
		playerPosition,
		self.Rotation.Direction,
		self.LockOn.SearchRadius,
		self.LockOn.MaxSearchAngle,
		self.LockOn.Target
	)

	if nextTarget then
		self:SetLockOnTarget(nextTarget)
	end
end

function CameraController.EnableAutoRotate(self: CameraController, enabled: boolean)
	self.Rotation.AutoRotateEnabled = enabled
end

function CameraController.SetOffset(self: CameraController, right: number?, up: number?, back: number?)
	if right then
		self.Position.RightOffset = right
	end
	if up then
		self.Position.UpOffset = up
	end
	if back then
		self.Position.BackOffset = back
		if not self.Capabilities.ZoomControl then
			self.Position.CurrentZoom = back
		end
	end
end

function CameraController.SetPitchLimits(self: CameraController, min: number?, max: number?)
	if min then
		self.Rotation.MinPitch = min
		self.Rotation.Pitch = math.max(self.Rotation.Pitch, min)
	end
	if max then
		self.Rotation.MaxPitch = max
		self.Rotation.Pitch = math.min(self.Rotation.Pitch, max)
	end
end

function CameraController.SetSmoothing(self: CameraController, position: number?, rotation: number?)
	if position then
		self.Position.Smoothing = position
	end
	if rotation then
		self.Rotation.Smoothing = rotation
	end
end

-- ===========================
-- BINDING CONTROLS
-- ===========================

function CameraController.SetBinding(self: CameraController, name: string, keycode: Enum.KeyCode)
	if not self.Bindings[name] then
		error("Unknown key binding: " .. name)
	end
	self.Bindings[name] = keycode
end

function CameraController.GetBinding(self: CameraController, name: string)
	if not self.Bindings[name] then
		error("Unknown key binding: " .. name)
	end
	return self.Bindings[name]
end

-- ===========================
-- UTILITY GETTERS
-- ===========================

function CameraController.GetDirection(self: CameraController): Vector3
	return self.Rotation.Direction
end

function CameraController.GetYaw(self: CameraController): number
	return self.Rotation.Yaw
end

function CameraController.GetPitch(self: CameraController): number
	return self.Rotation.Pitch
end

function CameraController.IsLockingOn(self: CameraController): boolean
	return self.LockOn.Enabled
end

function CameraController.GetLockOnTarget(self: CameraController): Model?
	return self.LockOn.Target
end

function CameraController.GetCharacterFacingDirection(self: CameraController): Vector3
	if self.LockOn.Enabled and self.LockOn.Target and self.Root then
		local lockTarget = self.LockOn.Target:FindFirstChild("HumanoidRootPart")
		if lockTarget and lockTarget:IsA("BasePart") then
			local targetPos = lockTarget.Position
			local playerPos = self.Root.Position
			local dirToTarget = -Vector3.new(targetPos.X - playerPos.X, 0, targetPos.Z - playerPos.Z)
			if dirToTarget.Magnitude > 0 then
				return dirToTarget.Unit
			end
		end
	end

	local yaw = self.Rotation.Yaw
	return Vector3.new(math.sin(yaw), 0, math.cos(yaw)).Unit
end

return CameraController
