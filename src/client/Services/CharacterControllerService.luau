local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Gizmo = require(ReplicatedStorage.Packages.Gizmo)

local CharacterControllerService = {}
export type CharacterControllerService = typeof(CharacterControllerService)

-- ===========================
-- CAPABILITIES
-- ===========================
CharacterControllerService.Capabilities = {
	Movement = true,
	Rotation = true,
	Gravity = true,
	GroundDetection = true,
	GroundAlignment = true,
	Debug = RunService:IsStudio(),
}

-- ===========================
-- MOVEMENT PROPERTIES
-- ===========================
CharacterControllerService.Movement = {
	InputVector = Vector3.zero,
	MoveDirection = Vector3.zero,
	LastMoveDirection = Vector3.zero,

	CurrentSpeed = 0,
	TargetSpeed = 16,

	Acceleration = 20,
	Deceleration = 15,
	AirAcceleration = 8,
	AirDeceleration = 5,

	BackwardsMultiplier = 0.6,

	ForcedVelocity = nil :: Vector3?,
	ForcedVelocityDecay = 0.92,
}

-- ===========================
-- ROTATION PROPERTIES
-- ===========================
CharacterControllerService.Rotation = {
	TurnSpeed = math.rad(360),
	FaceMovementDirection = true,
	LockToCamera = true,
	TargetYaw = nil :: number?,

	GroundAlignmentSpeed = 12,
	CurrentYaw = 0,
	CurrentTilt = CFrame.identity,
}

-- ===========================
-- PHYSICS PROPERTIES
-- ===========================
CharacterControllerService.Physics = {
	Gravity = 50,
	TerminalVelocity = 150,
	VerticalVelocity = 0,

	IsGrounded = false,
	GroundRayLength = 3.5,
	GroundRayOffset = -0.1,
	GroundNormal = Vector3.yAxis,

	HipHeight = 3.0,
	SuspensionStiffness = 15,
}

-- ===========================
-- REFERENCES
-- ===========================
CharacterControllerService.Character = nil :: Model?
CharacterControllerService.Humanoid = nil :: Humanoid?
CharacterControllerService.Root = nil :: Part?
CharacterControllerService.Animator = nil :: Animator?
CharacterControllerService.AntiGravity = nil :: VectorForce?

-- ===========================
-- PRIVATE FUNCTIONS
-- ===========================

local function getInputVector()
	local forward, right = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		forward += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		forward -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		right += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		right -= 1
	end
	return Vector3.new(right, 0, forward)
end

local function worldInputToCamera(input: Vector3): Vector3
	if input.Magnitude == 0 then
		return Vector3.zero
	end

	local camera = workspace.CurrentCamera
	local cameraCF = camera.CFrame
	local cameraForward = Vector3.new(cameraCF.LookVector.X, 0, cameraCF.LookVector.Z).Unit
	local cameraRight = cameraCF.RightVector

	local worldDirection = cameraForward * input.Z + cameraRight * input.X
	return worldDirection.Magnitude > 0 and worldDirection.Unit or Vector3.zero
end

local function shortestRotation(current: number, target: number): number
	local delta = (target - current) % (2 * math.pi)
	if delta > math.pi then
		delta -= 2 * math.pi
	end
	return delta
end

local function performGroundCheck(root: Part, character: Model): (boolean, Vector3)
	if not CharacterControllerService.Capabilities.GroundDetection then
		return false, Vector3.yAxis
	end

	local origin = root.Position + Vector3.new(0, CharacterControllerService.Physics.GroundRayOffset, 0)
	local direction = Vector3.new(0, -CharacterControllerService.Physics.GroundRayLength, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, raycastParams)

	if result then
		return true, result.Normal
	end

	return false, Vector3.yAxis
end

local function calculateGroundTilt(yaw: number, groundNormal: Vector3): CFrame
	local desiredForward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))

	local right = desiredForward:Cross(groundNormal)
	if right.Magnitude < 0.001 then
		right = Vector3.new(1, 0, 0):Cross(groundNormal)
		if right.Magnitude < 0.001 then
			right = Vector3.new(0, 0, 1):Cross(groundNormal)
		end
	end
	right = right.Unit

	local forward = groundNormal:Cross(right).Unit

	local alignedCF = CFrame.fromMatrix(Vector3.zero, right, groundNormal, -forward)

	local yawRemoval = CFrame.Angles(0, -yaw, 0)
	local tiltOnly = yawRemoval * alignedCF

	return tiltOnly
end

local function checkStepUp(root: Part, velocity: Vector3, character: Model)
	if velocity.Magnitude < 0.1 then
		return
	end

	local lookDirection = velocity.Unit
	local stepHeight = 2.0
	local checkDistance = 1.5
	local maxStepAngle = math.rad(50)

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local bottomOrigin = root.Position - Vector3.new(0, 2.8, 0)
	local bottomRay = workspace:Raycast(bottomOrigin, lookDirection * checkDistance, params)

	if bottomRay then
		local surfaceAngle = math.acos(bottomRay.Normal:Dot(Vector3.yAxis))
		if surfaceAngle < maxStepAngle then
			return
		end

		local topOrigin = bottomOrigin + Vector3.new(0, stepHeight, 0)
		local topRay = workspace:Raycast(topOrigin, lookDirection * checkDistance * 1.1, params)

		if not topRay then
			root.CFrame = root.CFrame + Vector3.new(0, 0.5, 0)
		end
	end
end

-- ===========================
-- PUBLIC API
-- ===========================

function CharacterControllerService.Init(self: CharacterControllerService)
	local player = Players.LocalPlayer

	local function OnCharacterAdded(character: Model)
		self.Character = character
		self.Humanoid = character:WaitForChild("Humanoid")
		self.Root = character:WaitForChild("HumanoidRootPart")
		self.Animator = self.Humanoid:WaitForChild("Animator")

		self.Humanoid.AutoRotate = false
		-- self.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		-- self.Root.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)

		for _, child in self.Character:GetDescendants() do
			if child:IsA("Part") then
				child.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
			end
		end

		local attachment = Instance.new("Attachment")
		attachment.Parent = self.Root
		local antiGravity = Instance.new("VectorForce")
		antiGravity.Name = "AntiGravity"
		antiGravity.Force = Vector3.new(0, workspace.Gravity * self.Root.AssemblyMass, 0)
		antiGravity.Attachment0 = attachment
		antiGravity.RelativeTo = Enum.ActuatorRelativeTo.World
		antiGravity.Parent = self.Root
		self.AntiGravity = antiGravity

		self.Physics.VerticalVelocity = 0
		self.Physics.IsGrounded = false

		self.Rotation.CurrentYaw = math.rad(self.Root.Orientation.Y)
		self.Rotation.CurrentTilt = CFrame.identity
	end

	local character = player.Character or player.CharacterAdded:Wait()
	OnCharacterAdded(character)
	player.CharacterAdded:Connect(OnCharacterAdded)

	RunService.Heartbeat:Connect(function(dt)
		self:Update(dt)
	end)

	RunService.RenderStepped:Connect(function(dt)
		self:Render(dt)
	end)
end

-- ===========================
-- CORE UPDATE LOOP
-- ===========================

function CharacterControllerService.Update(self: CharacterControllerService, dt: number)
	if not self.Root or not self.Humanoid then
		return
	end

	self.AntiGravity.Force = Vector3.new(0, workspace.Gravity * self.Root.AssemblyMass, 0)

	local isGrounded, groundNormal = performGroundCheck(self.Root, self.Character)
	self.Physics.IsGrounded = isGrounded
	self.Physics.GroundNormal = groundNormal

	self.Movement.InputVector = getInputVector()
	local rawMoveDirection = worldInputToCamera(self.Movement.InputVector)

	if self.Physics.IsGrounded and self.Physics.GroundNormal then
		local right = rawMoveDirection:Cross(Vector3.yAxis)
		self.Movement.MoveDirection = self.Physics.GroundNormal:Cross(right).Unit

		if rawMoveDirection.Magnitude == 0 then
			self.Movement.MoveDirection = Vector3.zero
		end
	else
		self.Movement.MoveDirection = rawMoveDirection
	end

	local finalVelocity = Vector3.zero

	if self.Movement.ForcedVelocity then
		local horizontal = Vector3.new(self.Movement.ForcedVelocity.X, 0, self.Movement.ForcedVelocity.Z)
		horizontal *= self.Movement.ForcedVelocityDecay

		if horizontal.Magnitude < 0.5 then
			self.Movement.ForcedVelocity = nil
		else
			self.Movement.ForcedVelocity = Vector3.new(horizontal.x, self.Movement.ForcedVelocity.Y, horizontal.Z)
			finalVelocity = Vector3.new(horizontal.X, 0, horizontal.Z)
		end
	end

	if not self.Movement.ForcedVelocity and self.Capabilities.Movement then
		local acceleration = self.Physics.IsGrounded and self.Movement.Acceleration or self.Movement.AirAcceleration
		local deceleration = self.Physics.IsGrounded and self.Movement.Deceleration or self.Movement.AirDeceleration

		local targetSpeed = 0
		local smoothing = deceleration

		if self.Movement.MoveDirection.Magnitude > 0 then
			targetSpeed = self.Movement.TargetSpeed
			smoothing = acceleration
			self.Movement.LastMoveDirection = self.Movement.MoveDirection
		end

		self.Movement.CurrentSpeed = self.Movement.CurrentSpeed
			+ (targetSpeed - self.Movement.CurrentSpeed) * math.min(smoothing * dt, 1)

		local alignment = self.Movement.LastMoveDirection:Dot(
			Vector3.new(self.Root.CFrame.LookVector.X, 0, self.Root.CFrame.LookVector.Z)
		)

		local speedScale
		if alignment >= 0 then
			speedScale = 1
		else
			speedScale = 1 + alignment * (1 - self.Movement.BackwardsMultiplier)
		end

		finalVelocity = self.Movement.LastMoveDirection * self.Movement.CurrentSpeed * speedScale
	end

	if self.Capabilities.Rotation then
		local targetYaw: number? = nil

		if self.Rotation.TargetYaw then
			targetYaw = self.Rotation.TargetYaw
		elseif self.Rotation.LockToCamera then
			local camera = workspace.CurrentCamera
			local cameraForward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
			targetYaw = math.atan2(-cameraForward.X, -cameraForward.Z)
		elseif self.Rotation.FaceMovementDirection and self.Movement.CurrentSpeed > 0.5 then
			targetYaw = math.atan2(-self.Movement.LastMoveDirection.X, -self.Movement.LastMoveDirection.Z)
		end

		if targetYaw then
			local deltaYaw = shortestRotation(self.Rotation.CurrentYaw, targetYaw)
			local rotationSpeed = math.min(self.Rotation.TurnSpeed * dt, math.abs(deltaYaw))
			self.Rotation.CurrentYaw = self.Rotation.CurrentYaw + math.sign(deltaYaw) * rotationSpeed
		end
	end

	local targetTilt
	if self.Capabilities.GroundAlignment and self.Physics.IsGrounded then
		targetTilt = calculateGroundTilt(self.Rotation.CurrentYaw, self.Physics.GroundNormal)
	else
		targetTilt = CFrame.identity
	end

	local alpha = math.min(self.Rotation.GroundAlignmentSpeed * dt, 1)
	self.Rotation.CurrentTilt = self.Rotation.CurrentTilt:Lerp(targetTilt, alpha)

	local currentPosition = self.Root.Position
	local yawRotation = CFrame.Angles(0, self.Rotation.CurrentYaw, 0)
	self.Root.CFrame = CFrame.new(currentPosition) * yawRotation * self.Rotation.CurrentTilt

	local verticalVelocity = 0

	if self.Capabilities.Gravity then
		if self.Physics.IsGrounded then
			local origin = self.Root.Position
			local castParams = RaycastParams.new()
			castParams.FilterDescendantsInstances = { self.Character }
			castParams.FilterType = Enum.RaycastFilterType.Exclude
			local result = workspace:Raycast(origin, Vector3.new(0, -(self.Physics.HipHeight + 2), 0), castParams)

			if result then
				local currentHeight = result.Distance
				local heightDifference = self.Physics.HipHeight - currentHeight

				if math.abs(heightDifference) > 0.05 then
					verticalVelocity = heightDifference * self.Physics.SuspensionStiffness
				else
					verticalVelocity = 0
				end
			end

			self.Physics.VerticalVelocity = verticalVelocity
		else
			self.Physics.VerticalVelocity -= self.Physics.Gravity * dt
			self.Physics.VerticalVelocity = math.max(self.Physics.VerticalVelocity, -self.Physics.TerminalVelocity)
			verticalVelocity = self.Physics.VerticalVelocity
		end
	end

	local finalVelocity3D = Vector3.new(finalVelocity.X, verticalVelocity, finalVelocity.Z)

	if self.Physics.IsGrounded then
		checkStepUp(self.Root, Vector3.new(finalVelocity3D.X, 0, finalVelocity3D.Z), self.Character)
	end

	self.Root.AssemblyLinearVelocity = finalVelocity3D
	self.Root.AssemblyAngularVelocity = Vector3.zero
end

-- ===========================
-- DEBUG RENDERING
-- ===========================

function CharacterControllerService.Render(self: CharacterControllerService, _dt: number)
	if not self.Capabilities.Debug or not self.Root then
		return
	end

	local origin = self.Root.Position + Vector3.new(0, CharacterControllerService.Physics.GroundRayOffset, 0)
	local direction = origin + Vector3.new(0, -CharacterControllerService.Physics.GroundRayLength, 0)

	Gizmo.PushProperty("Color3", Color3.new(1, 0, 0))

	Gizmo.Ray:Draw(origin, direction)

	Gizmo.PushProperty("Color3", Color3.new(0, 1, 0))

	Gizmo.Ray:Draw(self.Root.Position, self.Root.Position + self.Root.AssemblyLinearVelocity)

	if self.Physics.IsGrounded then
		Gizmo.PushProperty("Color3", Color3.new(1, 1, 0))
		Gizmo.Ray:Draw(self.Root.Position, self.Root.Position + self.Physics.GroundNormal * 3)
	end

	local bottomOrigin = self.Root.Position - Vector3.new(0, 2.8, 0)
	local topOrigin = bottomOrigin + Vector3.new(0, 2.0, 0)
	local lookDirection = Vector3.new(self.Root.AssemblyLinearVelocity.X, 0, self.Root.AssemblyLinearVelocity.Z).Unit

	Gizmo.PushProperty("Color3", Color3.new(0, 0, 1))
	Gizmo.Ray:Draw(bottomOrigin, bottomOrigin + lookDirection * 1.5)
	Gizmo.Ray:Draw(topOrigin, topOrigin + lookDirection * 1.5 * 1.1)
end

-- ===========================
-- CAPABILITY CONTROLS
-- ===========================

function CharacterControllerService.SetCapability(
	self: CharacterControllerService,
	capability: string,
	enabled: boolean
)
	if self.Capabilities[capability] ~= nil then
		self.Capabilities[capability] = enabled
	else
		warn("Unknown capability: ", capability)
	end
end

function CharacterControllerService.IsCapabilityEnabled(self: CharacterControllerService, capability: string)
	return self.Capabilities[capability] == true
end

-- ===========================
-- MOVEMENT CONTROLS
-- ===========================

function CharacterControllerService.SetTargetSpeed(self: CharacterControllerService, speed: number)
	self.Movement.TargetSpeed = speed
end

function CharacterControllerService.SetForcedVelocity(self: CharacterControllerService, velocity: Vector3?)
	self.Movement.ForcedVelocity = velocity
end

function CharacterControllerService.AddImpulse(self: CharacterControllerService, impulse: Vector3)
	if self.Movement.ForcedVelocity then
		self.Movement.ForcedVelocity += impulse
	else
		self.Movement.ForcedVelocity = impulse
	end
end

-- ===========================
-- ROTATION CONTROLS
-- ===========================

function CharacterControllerService.SetFaceMovementDirection(self: CharacterControllerService, enabled: boolean)
	self.Rotation.FaceMovementDirection = enabled
end

function CharacterControllerService.SetLockToCamera(self: CharacterControllerService, enabled: boolean)
	self.Rotation.LockToCamera = enabled
	self.Rotation.FaceMovementDirection = not enabled
end

function CharacterControllerService.SetTargetRotation(self: CharacterControllerService, yaw: number?)
	self.Rotation.TargetYaw = yaw
end

function CharacterControllerService.FaceDirection(self: CharacterControllerService, direction: Vector3)
	if direction.Magnitude > 0 then
		local yaw = math.atan2(direction.X, direction.Z)
		self.Rotation.TargetYaw = yaw
	end
end

-- ===========================
-- ANIMATION CONTROLS
-- ===========================

function CharacterControllerService.LoadAnimation(self: CharacterControllerService, animationId: string): AnimationTrack
	repeat
		wait()
	until self.Animator
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return self.Animator:LoadAnimation(animation)
end

function CharacterControllerService.StopAnimations(self: CharacterControllerService)
	if not self.Animator then
		return
	end
	for _, track in pairs(self.Animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end
end

-- ===========================
-- UTILITY GETTERS
-- ===========================

function CharacterControllerService.IsGrounded(self: CharacterControllerService)
	return self.Physics.IsGrounded
end

function CharacterControllerService.GetMoveDirection(self: CharacterControllerService)
	return self.Movement.MoveDirection
end

function CharacterControllerService.GetCurrentSpeed(self: CharacterControllerService)
	return self.Movement.CurrentSpeed
end

function CharacterControllerService.IsMoving(self: CharacterControllerService)
	return self.Movement.CurrentSpeed > 0.5
end

return CharacterControllerService
