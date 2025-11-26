local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CameraController = {}
export type CameraController = typeof(CameraController)

CameraController.Capabilities = {
	Rotation = true,
}

CameraController.Input = {
	HorizontalSensitivity = 0.003,
	VerticalSensitivity = 0.003,
}

CameraController.Position = {
	Offset = Vector3.new(3, 2.5, -15),
	Smoothing = 0.15,
	CurrentPosition = Vector3.zero,
}

CameraController.Rotation = {
	MinPitch = -1.2,
	MaxPitch = 1.2,
	Smoothing = 0.15,
	CurrentRotation = CFrame.identity,
	Direction = Vector3.new(0, 0, -1),
}

CameraController.Target = nil :: Model?
CameraController.Root = nil :: Part?
CameraController.Camera = workspace.CurrentCamera

local function rotate(vec: Vector3, axis: Vector3, angle: number)
	local cos = math.cos(angle)
	local sin = math.sin(angle)
	return vec * cos + axis:Cross(vec) * sin + axis * axis:Dot(vec) * (1 - cos)
end

function CameraController.Init(self: CameraController)
	self.Camera.CameraType = Enum.CameraType.Scriptable

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	self:SetTarget(Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait())
end

function CameraController.Start(self: CameraController)
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		self:SetTarget(character)
	end)

	RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end)
end

function CameraController.SetTarget(self: CameraController, target: Model)
	self.Target = target
	self.Root = target.PrimaryPart

	local startPosition = self.Root.Position
	self.Position.CurrentPosition = startPosition
	self.Rotation.CurrentRotation = CFrame.lookAt(startPosition, startPosition + self.Rotation.Direction)
end

function CameraController.Update(self: CameraController, dt: number)
	if not self.Root then
		return
	end

	local positionSmoothing, rotationSmoothing = self.Position.Smoothing, self.Rotation.Smoothing

	if self.Capabilities.Rotation then
		local delta = UserInputService:GetMouseDelta()

		local mouseSpeed = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)
		local smoothingScale = 1 / (1 + mouseSpeed * 0.02)

		positionSmoothing *= smoothingScale
		rotationSmoothing *= smoothingScale

		if delta.X ~= 0 then
			self.Rotation.Direction =
				rotate(self.Rotation.Direction, Vector3.yAxis, -delta.X * self.Input.HorizontalSensitivity)
		end

		if delta.Y ~= 0 then
			local horizontalAxis = self.Rotation.Direction:Cross(Vector3.yAxis).Unit
			local newDirection =
				rotate(self.Rotation.Direction, horizontalAxis, -delta.Y * self.Input.VerticalSensitivity)

			local pitch = math.asin(newDirection.Y)
			if self.Rotation.MinPitch < pitch and pitch < self.Rotation.MaxPitch then
				self.Rotation.Direction = newDirection
			end
		end
	end

	local rootPosition = self.Root.Position + Vector3.new(0, self.Position.Offset.Y, 0)
	local right = self.Rotation.Direction:Cross(Vector3.yAxis).Unit

	local desiredCameraPosition = rootPosition
		+ self.Rotation.Direction * self.Position.Offset.Z
		+ right * self.Position.Offset.X

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { self.Target }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rootPosition, (desiredCameraPosition - rootPosition), params)

	if result then
		desiredCameraPosition = result.Position + result.Normal * 0.5
	end

	local positionAlpha = 1 - math.exp(-dt / positionSmoothing)
	self.Position.CurrentPosition = self.Position.CurrentPosition:Lerp(desiredCameraPosition, positionAlpha)

	local desiredRotation = CFrame.lookAt(self.Position.CurrentPosition, rootPosition)
	local rotationAlpha = 1 - math.exp(-dt / rotationSmoothing)
	self.Rotation.CurrentRotation = self.Rotation.CurrentRotation:Lerp(desiredRotation, rotationAlpha)

	self.Camera.CFrame = self.Rotation.CurrentRotation
end

return CameraController
