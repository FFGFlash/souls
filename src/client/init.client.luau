--!strict
-- Client entry point. Owns the input layer, the lock-on target registry and the character session for the
-- current life, and runs the single ordered frame pipeline:
--
--   Render step (Camera priority): sample input -> lock-on -> camera orientation -> state machine (motor intents,
--                                  animations) -> locomotion blend -> camera transform
--   PreSimulation:                 motor ground/air switching -> visual ground tilt (after the Animator)
--
-- Intents set during the render step are used by the physics step later in the same frame, and the camera
-- reads the pose that is about to be rendered.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local CharacterSession = require(script.Character.CharacterSession)
local Input = require(script.Input.Input)
local TargetRegistry = require(script.Targeting.TargetRegistry)

-- Large frame spikes (e.g. after a hitch) shouldn't teleport timers or smoothing.
local MAX_DT = 0.1

local player = Players.LocalPlayer
local input = Input.new()
local registry = TargetRegistry.new()

local session: CharacterSession.CharacterSession? = nil
-- Bumped on every spawn so a slow-loading session for an old character is discarded.
local generation = 0

-- Tab is used for shoulder swap, so the player list can't be toggled with it.
task.spawn(function()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false) then
			return
		end
		task.wait(0.5)
	end
end)

local function endSession()
	if session then
		session:Destroy()
		session = nil
	end
end

local function startSession(character: Model)
	generation += 1
	local myGeneration = generation
	endSession()

	local newSession = CharacterSession.new(character, input.Buffer, registry)
	if not newSession then
		return
	end
	if myGeneration ~= generation or player.Character ~= character then
		newSession:Destroy()
		return
	end
	session = newSession
end

player.CharacterAdded:Connect(startSession)
player.CharacterRemoving:Connect(function(character: Model)
	if session and session.Character == character then
		endSession()
	end
end)
if player.Character then
	task.spawn(startSession, player.Character)
end

RunService:BindToRenderStep("Souls.Frame", Enum.RenderPriority.Camera.Value, function(dt: number)
	dt = math.min(dt, MAX_DT)
	local frame = input:Sample(dt)
	if session then
		session:RenderStep(frame, dt)
	end
end)

RunService.PreSimulation:Connect(function(dt: number)
	if session then
		session:PreSimulation(math.min(dt, MAX_DT))
	end
end)
