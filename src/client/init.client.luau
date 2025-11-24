local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local CameraService = require(script.Services.CameraService)
local CharacterControllerService = require(script.Services.CharacterControllerService)
local StateMachineService = require(script.Services.StateMachineService)

StarterPlayer.EnableMouseLockOption = false
StarterPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable

local player = Players.LocalPlayer

player.CharacterAdded:Connect(function()
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = playerScripts:FindFirstChild("PlayerModule")
	if playerModule then
		playerModule:Destroy()
	end
end)

StateMachineService:AddState("Idle", {
	OnEnter = function()
		CharacterControllerService:SetMoveEnabled(false)
		CharacterControllerService:SetRotationEnabled(false)
	end,

	OnUpdate = function()
		local moving = UserInputService:IsKeyDown(Enum.KeyCode.W)
			or UserInputService:IsKeyDown(Enum.KeyCode.A)
			or UserInputService:IsKeyDown(Enum.KeyCode.S)
			or UserInputService:IsKeyDown(Enum.KeyCode.D)

		if moving then
			StateMachineService:Switch("Walking")
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			StateMachineService:Switch("Rolling")
		end
	end,

	AllowedTransitions = {
		Walking = true,
		Rolling = true,
	},
})

StateMachineService:AddState("Walking", {
	OnEnter = function()
		CharacterControllerService:SetMoveEnabled(true)
		CharacterControllerService:SetRotationEnabled(true)
	end,

	OnUpdate = function()
		local moving = UserInputService:IsKeyDown(Enum.KeyCode.W)
			or UserInputService:IsKeyDown(Enum.KeyCode.A)
			or UserInputService:IsKeyDown(Enum.KeyCode.S)
			or UserInputService:IsKeyDown(Enum.KeyCode.D)

		if not moving then
			StateMachineService:Switch("Idle")
			return
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			StateMachineService:Switch("Rolling")
		end
	end,

	AllowedTransitions = {
		Idle = true,
		Rolling = true,
	},
})

StateMachineService:AddState("Rolling", {
	OnEnter = function(context)
		CharacterControllerService:SetMoveEnabled(false)
		CharacterControllerService:SetRotationEnabled(false)

		local dashDirection = CharacterControllerService.Root.CFrame.LookVector
		CharacterControllerService:SetForcedVelocity(dashDirection * 40)

		context.StartTime = tick()
		context.Duration = 0.5
	end,

	OnUpdate = function(context)
		if tick() - context.StartTime >= context.Duration then
			StateMachineService:Switch("Idle")
		end
	end,

	OnExit = function()
		CharacterControllerService:SetMoveEnabled(true)
		CharacterControllerService:SetRotationEnabled(true)
		CharacterControllerService:SetForcedVelocity(nil)
	end,

	AllowedTransitions = {
		Idle = true,
	},
})

CameraService:Init()
CharacterControllerService:Init()
StateMachineService:Init()
