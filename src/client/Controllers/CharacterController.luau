local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local CameraController = require(script.Parent.CameraController)
local Gizmo = require(ReplicatedStorage.Packages.Gizmo)

local CharacterController = {}
export type CharacterController = typeof(CharacterController)

-- ===========================
-- CAPABILITIES
-- ===========================
CharacterController.Capabilities = {
	Movement = true,
	Rotation = true,
	Gravity = true,
	GroundDetection = true,
	GroundAlignment = false,
	Debug = RunService:IsStudio(),
}

-- ===========================
-- BINDING PROPERTIES
-- ===========================
CharacterController.Bindings = {
	MoveForward = Enum.KeyCode.W,
	MoveLeftward = Enum.KeyCode.A,
	MoveBackward = Enum.KeyCode.S,
	MoveRightward = Enum.KeyCode.D,
	Roll = Enum.KeyCode.Space,
}

-- ===========================
-- MOVEMENT PROPERTIES
-- ===========================
CharacterController.Movement = {
	InputVector = Vector3.zero,
	MoveDirection = Vector3.zero,
	LastMoveDirection = Vector3.zero,

	CurrentSpeed = 0,

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
CharacterController.Rotation = {
	TurnSpeed = math.rad(360),
	FaceMovementDirection = false,
	LockToCamera = true,
	TargetYaw = nil :: number?,

	GroundAlignmentSpeed = 12,
	CurrentYaw = 0,
	CurrentTilt = CFrame.identity,
}

-- ===========================
-- PHYSICS PROPERTIES
-- ===========================
CharacterController.Physics = {
	TerminalVelocity = 150,
	Velocity = Vector3.zero,

	IsGrounded = false,
	GroundRayLength = 4,
	GroundRayOffset = -0.1,
	GroundNormal = Vector3.yAxis,
	GroundDistance = 0,

	MaxWalkableAngle = math.rad(45),

	SlopeEdgeThreshold = 0.5,

	SuspensionStiffness = 15,
}

-- ===========================
-- ANIMATION PROPERTIES
-- ===========================
CharacterController.Animations = {
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
}
CharacterController.Tracks = {}

-- ===========================
-- REFERENCES
-- ===========================
CharacterController.Character = nil :: Model?
CharacterController.Humanoid = nil :: Humanoid?
CharacterController.Root = nil :: Part?
CharacterController.Animator = nil :: Animator?
CharacterController.AntiGravity = nil :: VectorForce?
CharacterController.CameraController = nil :: CameraController.CameraController?

-- ===========================
-- PRIVATE FUNCTIONS
-- ===========================

local function getInputVector(
	moveForward: boolean,
	moveBackward: boolean,
	moveRightward: boolean,
	moveLeftward: boolean
)
	return Vector3.new(
		(moveRightward and 1 or 0) - (moveLeftward and 1 or 0),
		0,
		(moveForward and 1 or 0) - (moveBackward and 1 or 0)
	)
end

local function worldInputToCamera(input: Vector3): Vector3
	if input.Magnitude == 0 then
		return Vector3.zero
	end

	local cameraForward, cameraRight
	if CharacterController.CameraController and CharacterController.CameraController.GetCharacterFacingDirection then
		cameraForward = CharacterController.CameraController:GetCharacterFacingDirection() * -1
		cameraRight = Vector3.new(-cameraForward.Z, 0, cameraForward.X)
	else
		local camera = workspace.CurrentCamera
		cameraForward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		cameraRight = camera.CFrame.RightVector
	end

	local worldDirection = cameraForward * input.Z + cameraRight * input.X
	return worldDirection.Magnitude > 0 and worldDirection.Unit or Vector3.zero
end

local function performGroundCheck(root: Part, character: Model): (boolean, Vector3, number)
	if not CharacterController.Capabilities.GroundDetection then
		return false, Vector3.yAxis, 0
	end

	local origin = root.Position + Vector3.new(0, CharacterController.Physics.GroundRayOffset, 0)
	local direction = Vector3.new(0, -CharacterController.Physics.GroundRayLength, 0)

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, params)

	if result then
		local slopeAngle = math.acos(result.Normal:Dot(Vector3.yAxis))
		local isWalkable = slopeAngle <= CharacterController.Physics.MaxWalkableAngle

		return isWalkable, result.Normal, result.Distance
	end

	return false, Vector3.yAxis, math.huge
end

local function isNearSlopeEdge(root: Part, character: Model, moveDirection: Vector3): boolean
	if moveDirection.Magnitude < 0.1 then
		return false
	end

	local lookAheadDistance = 1.0
	local origin = root.Position + moveDirection.Unit * lookAheadDistance
	origin = origin + Vector3.new(0, CharacterController.Physics.GroundRayOffset, 0)

	local direction = Vector3.new(0, -CharacterController.Physics.GroundRayLength, 0)

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, params)

	if not result then
		return true
	end

	local currentHeight = root.Position.Y
	local aheadHeight = result.Position.Y
	local heightDiff = currentHeight - aheadHeight

	return heightDiff > CharacterController.Physics.SlopeEdgeThreshold
end

local function getAccelerationAndDeceleration(): (number, number)
	if CharacterController.Physics.IsGrounded then
		return CharacterController.Movement.Acceleration, CharacterController.Movement.Deceleration
	end
	return CharacterController.Movement.AirAcceleration, CharacterController.Movement.AirDeceleration
end

local function getForwardVector(cf: CFrame): Vector3
	return Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
end

local function calculateShortestRotation(current: number, target: number)
	local delta = (target - current) % (2 * math.pi)
	if delta > math.pi then
		delta -= 2 * math.pi
	end
	return delta
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
	local tilyOnly = yawRemoval * alignedCF

	return tilyOnly
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

function CharacterController.Init(
	self: CharacterController,
	controllers: { CameraController: CameraController.CameraController }
)
	self.CameraController = controllers.CameraController

	StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
	StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable

	-- Wait for the character to load, so animations and everything are ready.
	self:SetCharacter(Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait())
end

function CharacterController.Start(self: CharacterController)
	-- Update references when the character is respawned
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		self:SetCharacter(character)
	end)

	-- Run updates after physics simulation is applied
	RunService.Heartbeat:Connect(function(dt)
		self:Update(dt)
	end)

	-- Run renders before frames are rendered
	RunService.RenderStepped:Connect(function(dt)
		self:Render(dt)
	end)
end

-- ===========================
-- CORE UPDATE LOOP
-- ===========================
function CharacterController.Update(self: CharacterController, dt: number)
	if not self.Root or not self.Character then
		return
	end

	local gravity = workspace.Gravity * self.Root.AssemblyMass

	-- Update the gravity counter force
	self.AntiGravity.Force = Vector3.new(0, gravity, 0)

	-- Update the InputVector
	self.Movement.InputVector = getInputVector(
		self:IsBindingDown("MoveForward"),
		self:IsBindingDown("MoveBackward"),
		self:IsBindingDown("MoveRightward"),
		self:IsBindingDown("MoveLeftward")
	)

	-- Update grounded state (IsGrounded and GroundNormal)
	self.Physics.IsGrounded, self.Physics.GroundNormal, self.Physics.GroundDistance =
		performGroundCheck(self.Root, self.Character)

	-- Calculate MoveDirection
	local rawMoveDirection = worldInputToCamera(self.Movement.InputVector)

	if rawMoveDirection.Magnitude == 0 then
		-- if rawMoveDirection has a length of 0 then we aren't moving
		self.Movement.MoveDirection = Vector3.zero
	elseif self.Physics.IsGrounded then
		-- if the player is grounded then align the movement vector to the ground (slopes)
		local right = rawMoveDirection:Cross(Vector3.yAxis)
		self.Movement.MoveDirection = self.Physics.GroundNormal:Cross(right).Unit
	else
		-- if airborne then just use the rawMoveDirection
		self.Movement.MoveDirection = rawMoveDirection
	end

	local finalVelocity = Vector3.zero

	-- Apply forced velocity
	if self.Movement.ForcedVelocity then
		self.Movement.ForcedVelocity *= self.Movement.ForcedVelocityDecay

		if self.Movement.ForcedVelocity.Magnitude < 0.5 then
			self.Movement.ForcedVelocity = nil
		else
			finalVelocity += self.Movement.ForcedVelocity
		end
	end

	-- Apply movement velocity
	if self.Capabilities.Movement then
		-- If we're moving then we accelerate towards the player's walk speed, otherwise we decelerate towards 0
		local acceleration, deceleration = getAccelerationAndDeceleration()
		local targetSpeed, smoothing
		if self.Movement.MoveDirection.Magnitude > 0 then
			targetSpeed, smoothing = self.Humanoid.WalkSpeed, acceleration
			self.Movement.LastMoveDirection = self.Movement.MoveDirection
		else
			targetSpeed, smoothing = 0, deceleration
		end

		-- Update the player's current speed
		self.Movement.CurrentSpeed = self.Movement.CurrentSpeed
			+ (targetSpeed - self.Movement.CurrentSpeed) * math.min(smoothing * dt, 1)

		-- Slow the player down if they're walking backwards
		local forwardVector = getForwardVector(self.Root.CFrame)
		local alignment = self.Movement.LastMoveDirection:Dot(forwardVector)

		local speedScale
		if alignment >= 0 then
			speedScale = 1
		else
			speedScale = 1 + alignment * (1 - self.Movement.BackwardsMultiplier)
		end

		finalVelocity += self.Movement.LastMoveDirection * self.Movement.CurrentSpeed * speedScale
	end

	-- Apply character rotation
	if self.Capabilities.Rotation then
		local targetYaw: number? = nil

		if self.Rotation.TargetYaw then
			-- Rotate toward TargetYaw
			targetYaw = self.Rotation.TargetYaw
		elseif self.Rotation.LockToCamera then
			-- Rotate toward camera rotation
			local cameraForward
			if self.CameraController and self.CameraController.GetCharacterFacingDirection then
				cameraForward = self.CameraController:GetCharacterFacingDirection() * -1
			else
				local camera = workspace.CurrentCamera
				cameraForward = getForwardVector(camera.CFrame).Unit
			end

			targetYaw = math.atan2(-cameraForward.X, -cameraForward.Z)
		elseif self.Rotation.FaceMovementDirection and self.Movement.CurrentSpeed > 0.5 then
			-- Rotate toward character movement direction
			targetYaw = math.atan2(-self.Movement.LastMoveDirection.X, -self.Movement.LastMoveDirection.Z)
		end

		-- If we have a target rotation, then rotate toward it
		if targetYaw then
			local deltaView = calculateShortestRotation(self.Rotation.CurrentYaw, targetYaw)
			local rotationSpeed = math.min(self.Rotation.TurnSpeed * dt, math.abs(deltaView))
			self.Rotation.CurrentYaw = self.Rotation.CurrentYaw + math.sign(deltaView) * rotationSpeed
		end
	end

	-- Calculate the player's tilt relative to the ground
	local targetTilt
	local shouldAlign = self.Capabilities.GroundAlignment and self.Physics.IsGrounded

	if shouldAlign then
		local nearEdge = isNearSlopeEdge(self.Root, self.Character, self.Movement.LastMoveDirection)
		local maxGroundDistance = self.Humanoid.HipHeight + self.Root.Size.Y / 2 + 0.5
		local tooFarFromGround = self.Physics.GroundDistance > maxGroundDistance

		if nearEdge or tooFarFromGround then
			shouldAlign = false
		end
	end

	if shouldAlign then
		targetTilt = calculateGroundTilt(self.Rotation.CurrentYaw, self.Physics.GroundNormal)
	else
		targetTilt = CFrame.identity
	end

	local alpha = math.min(self.Rotation.GroundAlignmentSpeed * dt, 1)
	self.Rotation.CurrentTilt = self.Rotation.CurrentTilt:Lerp(targetTilt, alpha)

	-- Apply Rotations
	local currentPosition = self.Root.Position
	local yawRotation = CFrame.Angles(0, self.Rotation.CurrentYaw, 0)
	self.Root.CFrame = CFrame.new(currentPosition) * yawRotation * self.Rotation.CurrentTilt

	local physicsVelocity = Vector3.zero

	-- Apply gravity and ground snapping
	if self.Capabilities.Gravity then
		if self.Physics.IsGrounded then
			local origin = self.Root.Position

			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { self.Character }
			params.FilterType = Enum.RaycastFilterType.Exclude

			local targetHeight = self.Humanoid.HipHeight + self.Root.Size.Y / 2

			local rayDirection = (self.Physics.GroundNormal * -(targetHeight + 2))

			local result = workspace:Raycast(origin, rayDirection, params)

			if result then
				local currentHeight = result.Distance
				local heightDifference = targetHeight - currentHeight

				if math.abs(heightDifference) > 0.05 then
					physicsVelocity = Vector3.yAxis * heightDifference * self.Physics.SuspensionStiffness
				end
			end

			self.Physics.Velocity = physicsVelocity
		else
			self.Physics.Velocity -= Vector3.new(0, math.sqrt(gravity) * dt, 0)
			self.Physics.Velocity = Vector3.new(
				self.Physics.Velocity.X,
				math.max(self.Physics.Velocity.Y, -self.Physics.TerminalVelocity),
				self.Physics.Velocity.Z
			)
			physicsVelocity = self.Physics.Velocity
		end
	end

	-- Apply vertical velocity
	finalVelocity += physicsVelocity

	-- Check if the player needs to step up a ledge, and step up
	if self.Physics.IsGrounded then
		checkStepUp(self.Root, Vector3.new(finalVelocity.X, 0, finalVelocity.Z), self.Character)
	end

	-- Apply linear velocity and remove angular velocity
	self.Root.AssemblyLinearVelocity = finalVelocity
	self.Root.AssemblyAngularVelocity = Vector3.zero
end

-- ===========================
-- CORE RENDER LOOP
-- ===========================
function CharacterController.Render(self: CharacterController, _dt: number)
	if not self.Capabilities.Debug or not self.Root then
		return
	end

	local origin = self.Root.Position + Vector3.new(0, CharacterController.Physics.GroundRayOffset, 0)
	local direction = origin + Vector3.new(0, -CharacterController.Physics.GroundRayLength, 0)

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
-- REFERENCE SETTERS
-- ===========================

function CharacterController.SetCharacter(self: CharacterController, character: Model)
	local player = Players.LocalPlayer
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = playerScripts:FindFirstChild("PlayerModule")
	if playerModule then
		playerModule:Destroy()
	end

	self.Character = character
	self.Humanoid = self.Character:WaitForChild("Humanoid")
	self.Root = self.Character:WaitForChild("HumanoidRootPart")
	self.Animator = self.Humanoid:WaitForChild("Animator")

	-- for _, child in self.Character:GetDescendants() do
	-- 	if child:IsA("Part") then
	-- 		child.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
	-- 	end
	-- end

	self.Humanoid.AutoRotate = false
	self.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Add a counter force to ignore Roblox's Gravity
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

	self:LoadAnimations()
end

-- ===========================
-- ANIMATION CONTROLS
-- ===========================

function CharacterController.LoadAnimations(self: CharacterController)
	for name, animationId in pairs(self.Animations) do
		if animationId == "rbxassetid://0" then
			continue
		end

		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		animation.Name = name

		local success = pcall(function()
			local track = self.Animator:LoadAnimation(animation)
			self.Tracks[name] = track
		end)

		if not success then
			warn("Failed to load animation: " .. name .. " (" .. animationId .. ")")
			self.Tracks[name] = nil
		end
	end
end

function CharacterController.PlayAnimation(
	self: CharacterController,
	name: string,
	fadeTime: number?,
	weight: number?,
	speed: number?
)
	if not self.Animations[name] then
		error("Uknown animation: " .. name)
	end

	if not self.Tracks[name] then
		warn("Animation not loaded: " .. name .. " (" .. self.Animations[name] .. ")")
		return
	end

	self.Tracks[name]:Play(fadeTime, weight, speed)
end

function CharacterController.StopAnimations(self: CharacterController, fadeTime: number?)
	for _, track in self.Animator:GetPlayingAnimationTracks() do
		track:Stop(fadeTime)
	end
end

function CharacterController.StopAnimation(self: CharacterController, name: string, fadeTime: number?)
	if not self.Animations[name] then
		error("Uknown animation: " .. name)
	end

	if not self.Tracks[name] then
		warn("Animation not loaded: " .. name .. " (" .. self.Animations[name] .. ")")
		return
	end

	self.Tracks[name]:Stop(fadeTime)
end

function CharacterController.AdjustAnimationWeight(
	self: CharacterController,
	name: string,
	weight: number?,
	fadeTime: number?
)
	if not self.Animations[name] then
		error("Uknown animation: " .. name)
	end

	if not self.Tracks[name] then
		warn("Animation not loaded: " .. name .. " (" .. self.Animations[name] .. ")")
		return
	end

	self.Tracks[name]:AdjustWeight(weight, fadeTime)
end

function CharacterController.AdjustAnimationSpeed(self: CharacterController, name: string, speed: number?)
	if not self.Animations[name] then
		error("Uknown animation: " .. name)
	end

	if not self.Tracks[name] then
		warn("Animation not loaded: " .. name .. " (" .. self.Animations[name] .. ")")
		return
	end

	self.Tracks[name]:AdjustSpeed(speed)
end

function CharacterController.GetAnimationTrack(self: CharacterController, name: string): AnimationTrack?
	if not self.Animations[name] then
		error("Uknown animation: " .. name)
	end

	if not self.Tracks[name] then
		warn("Animation not loaded: " .. name .. " (" .. self.Animations[name] .. ")")
		return nil
	end

	return self.Tracks[name]
end

-- ===========================
-- CAPABILITY CONTROLS
-- ===========================

function CharacterController.SetCapability(self: CharacterController, capability: string, enabled: boolean)
	if self.Capabilities[capability] == nil then
		error("Unknown Capability: " .. capability)
	end
	self.Capabilities[capability] = enabled
end

function CharacterController.IsCapabilityEnabled(self: CharacterController, capability: string)
	return self.Capabilities[capability] == true
end

-- ===========================
-- MOVEMENT CONTROLS
-- ===========================

function CharacterController.SetTargetSpeed(self: CharacterController, speed: number?)
	self.Humanoid.WalkSpeed = speed or StarterPlayer.CharacterWalkSpeed
end

function CharacterController.SetForcedVelocity(self: CharacterController, velocity: Vector3?)
	self.Movement.ForcedVelocity = velocity
end

function CharacterController.AddImpulse(self: CharacterController, impulse: Vector3)
	if self.Movement.ForcedVelocity then
		self.Movement.ForcedVelocity += impulse
	else
		self.Movement.ForcedVelocity = impulse
	end
end

-- ===========================
-- ROTATION CONTROLS
-- ===========================

function CharacterController.SetFaceMovementDirection(self: CharacterController, enabled: boolean)
	self.Rotation.FaceMovementDirection = enabled
	self.Rotation.LockToCamera = not enabled
end

function CharacterController.SetLockToCamera(self: CharacterController, enabled: boolean)
	self.Rotation.LockToCamera = enabled
	self.Rotation.FaceMovementDirection = not enabled
end

function CharacterController.SetTargetRotation(self: CharacterController, yaw: number?)
	self.Rotation.TargetYaw = yaw
end

function CharacterController.FaceDirection(self: CharacterController, direction: Vector3)
	if direction.Magnitude > 0 then
		local yaw = math.atan2(direction.X, direction.Z)
		self.Rotation.TargetYaw = yaw
	end
end

-- ===========================
-- BINDING CONTROLS
-- ===========================

function CharacterController.SetBinding(self: CharacterController, name: string, keycode: Enum.KeyCode)
	if not self.Bindings[name] then
		error("Unknown keybinding: " .. name)
	end
	self.Bindings[name] = keycode
end

function CharacterController.GetBinding(self: CharacterController, name: string): Enum.KeyCode
	if not self.Bindings[name] then
		error("Unknown keybinding: " .. name)
	end
	return self.Bindings[name]
end

function CharacterController.IsBindingDown(self: CharacterController, name: string): boolean
	if not self.Bindings[name] then
		error("Unknown keybinding: " .. name)
	end
	return UserInputService:IsKeyDown(self.Bindings[name])
end

-- ===========================
-- UTILITY GETTERS
-- ===========================

function CharacterController.IsGrounded(self: CharacterController)
	return self.Physics.IsGrounded
end

function CharacterController.GetMoveDirection(self: CharacterController)
	return self.Movement.MoveDirection
end

function CharacterController.GetCurrentSpeed(self: CharacterController)
	return self.Movement.CurrentSpeed
end

function CharacterController.IsMoving(self: CharacterController)
	return self.Movement.CurrentSpeed > 0.5
end

return CharacterController
