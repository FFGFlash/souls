local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local camera = workspace.CurrentCamera

local CameraService = {
	Sensitivity = 0.003,
	Distance = 15,

	MinPitch = -1.2,
	MaxPitch = 1.2,

	ShoulderOffset = 3,
	HeightOffset = 2.5,

	PositionSmoothing = 0.15,
	RotationSmoothing = 0.15,

	Direction = Vector3.new(0, 0, -1),
	SmoothPosition = nil,
	SmoothRotation = nil,
}

local function rotate(vec: Vector3, axis: Vector3, angle: number)
	local cos = math.cos(angle)
	local sin = math.sin(angle)
	return vec * cos + axis:Cross(vec) * sin + axis * (axis:Dot(vec)) * (1 - cos)
end

function CameraService:Init()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(char)
		self.Character = char
		self.Root = char:WaitForChild("HumanoidRootPart")

		local startPosition = self.Root.Position
		self.SmoothPosition = startPosition
		self.SmoothRotation = CFrame.lookAt(startPosition, startPosition + self.Direction)
	end)

	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end)
end

function CameraService:Update(dt: number)
	if not self.Root then
		return
	end

	local positionSmoothing, rotationSmoothing = self.PositionSmoothing, self.RotationSmoothing

	if not self.LockRotation then
		local delta = UserInputService:GetMouseDelta()

		local mouseSpeed = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)
		local smoothingScale = 1 / (1 + mouseSpeed * 0.02)

		positionSmoothing *= smoothingScale
		rotationSmoothing *= smoothingScale

		if delta.X ~= 0 then
			self.Direction = rotate(self.Direction, Vector3.yAxis, -delta.X * self.Sensitivity)
		end

		if delta.Y ~= 0 then
			local horizontalAxis = self.Direction:Cross(Vector3.yAxis).Unit
			local newDirection = rotate(self.Direction, horizontalAxis, -delta.Y * self.Sensitivity)

			local pitch = math.asin(newDirection.Y)
			if pitch > self.MinPitch and pitch < self.MaxPitch then
				self.Direction = newDirection
			end
		end
	end

	local rootPosition = self.Root.Position + Vector3.new(0, self.HeightOffset, 0)
	local right = self.Direction:Cross(Vector3.yAxis).Unit

	local desiredCameraPosition = rootPosition - self.Direction * self.Distance + right * self.ShoulderOffset

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { self.Character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local ray = workspace:Raycast(rootPosition, (desiredCameraPosition - rootPosition), raycastParams)

	if ray then
		desiredCameraPosition = ray.Position + ray.Normal * 0.5
	end

	local positionAlpha = 1 - math.exp(-dt / positionSmoothing)
	self.SmoothPosition = self.SmoothPosition:Lerp(desiredCameraPosition, positionAlpha)

	local desiredRotation = CFrame.lookAt(self.SmoothPosition, rootPosition)
	local rotationAlpha = 1 - math.exp(-dt / rotationSmoothing)
	self.SmoothRotation = self.SmoothRotation:Lerp(desiredRotation, rotationAlpha)

	camera.CFrame = self.SmoothRotation
end

return CameraService
