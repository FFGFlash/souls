local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CharacterControllerService = {
	MoveDirection = Vector3.zero,
	LastMoveDirection = Vector3.zero,
	CurrentSpeed = 0,
	WalkSpeed = 6,
	Acceleration = 18,
	Deceleration = 12,
	TurnSpeed = math.rad(180),
	ForcedVelocity = nil,
	MoveEnabled = true,
	RotationEnabled = true,
	Character = nil,
	Root = nil,
	Animator = nil,
}

local function getInputVector()
	local forward, right = 0, 0

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		forward -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		forward += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		right -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		right += 1
	end

	return Vector3.new(right, 0, forward)
end

local function shortestAngle(current, target)
	local delta = target - current
	delta = (delta + math.pi) % (2 * math.pi) - math.pi
	return delta
end

function CharacterControllerService:Init()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(char)
		self.Character = char
		self.Humanoid = char:WaitForChild("Humanoid") :: Humanoid
		self.Root = char:WaitForChild("HumanoidRootPart") :: Part
		self.Animator = self.Humanoid:WaitForChild("Animator") :: Animator
		self.Humanoid.AutoRotate = false
	end)

	RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end)
end

function CharacterControllerService:SetMoveEnabled(enabled: boolean)
	self.MoveEnabled = enabled
end

function CharacterControllerService:SetRotationEnabled(enabled: boolean)
	self.RotationEnabled = enabled
end

function CharacterControllerService:SetForcedVelocity(vel: Vector3?)
	self.ForcedVelocity = vel
end

function CharacterControllerService:PlayRootMotion(animation: Animation)
	self.Animator:LoadAnimation(animation):Play()
end

function CharacterControllerService:SetFriction(friction: number)
	self.Friction = friction
end

function CharacterControllerService:Update(dt: number)
	if not self.Root or not self.Humanoid then
		return
	end

	if self.ForcedVelocity then
		self.Root.AssemblyLinearVelocity = self.ForcedVelocity
		return
	end

	local input = getInputVector()
	if input.Magnitude > 0 then
		input = input.Unit
	end

	local camCF = workspace.CurrentCamera.CFrame
	local camLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
	local camRight = camCF.RightVector

	self.MoveDirection = (camLook * input.Z + camRight * input.X)
	if self.MoveDirection.Magnitude > 0 then
		self.MoveDirection = self.MoveDirection.Unit
	end

	local targetSpeed, smoothing = 0, self.Deceleration
	if self.MoveEnabled and self.MoveDirection.Magnitude > 0 then
		targetSpeed, smoothing = self.WalkSpeed, self.Acceleration
		self.LastMoveDirection = self.MoveDirection
	end

	self.CurrentSpeed = self.CurrentSpeed + (targetSpeed - self.CurrentSpeed) * math.clamp(smoothing * dt, 0, 1)

	if self.RotationEnabled and self.CurrentSpeed > 0.1 then
		local targetYaw = math.atan2(self.LastMoveDirection.X, self.LastMoveDirection.Z)
		local currentYaw = self.Root.Orientation.Y * math.pi / 180
		local deltaYaw = shortestAngle(currentYaw, targetYaw)

		local rotationFactor = math.clamp(self.TurnSpeed * dt, 0, 1)

		local newYaw = currentYaw + deltaYaw * rotationFactor
		self.Root.CFrame = CFrame.new(self.Root.Position) * CFrame.Angles(0, newYaw, 0)
	end

	self.Humanoid:Move(self.Root.CFrame.LookVector * self.CurrentSpeed, false)
end

return CharacterControllerService
