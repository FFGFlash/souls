local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local CameraService = require(script.Services.CameraService)
local CharacterControllerService = require(script.Services.CharacterControllerService)
local StateMachineService = require(script.Services.StateMachineService)
local FallingState = require(script.States.FallingState)
local IdleState = require(script.States.IdleState)
local RollingState = require(script.States.RollingState)
local WalkingState = require(script.States.WalkingState)

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

StateMachineService:AddState("Idle", IdleState)
StateMachineService:AddState("Walking", WalkingState)
StateMachineService:AddState("Rolling", RollingState)
StateMachineService:AddState("Falling", FallingState)

StateMachineService:AddServices({
	Camera = CameraService,
	CharacterController = CharacterControllerService,
	StateMachine = StateMachineService,
})

CameraService:Init()
CharacterControllerService:Init()
StateMachineService:Init()
