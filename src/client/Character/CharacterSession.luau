--!strict
-- Everything that exists for one life of the local character: rig, motor, animation, lock-on, camera and the
-- state machine. Created when the character spawns and destroyed when it is removed, so respawning always
-- starts from a clean slate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionBuffer = require(script.Parent.Parent.Input.ActionBuffer)
local Animation = require(script.Parent.Animation)
local CameraConfig = require(script.Parent.Parent.Config.Camera)
local CameraRig = require(script.Parent.Parent.Camera.CameraRig)
local Context = require(script.Parent.States.Context)
local DebugConfig = require(script.Parent.Parent.Config.Debug)
local DebugDraw = require(script.Parent.Parent.Debug.DebugDraw)
local GroundTilt = require(script.Parent.GroundTilt)
local InputTypes = require(script.Parent.Parent.Input.Types)
local LockOn = require(script.Parent.Parent.Targeting.LockOn)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Motor = require(script.Parent.Motor)
local MovementConfig = require(script.Parent.Parent.Config.Movement)
local Rig = require(script.Parent.Rig)
local StateMachine = require(ReplicatedStorage.Shared.StateMachine)
local States = require(script.Parent.States)
local TargetRegistry = require(script.Parent.Parent.Targeting.TargetRegistry)
local Trove = require(ReplicatedStorage.Shared.Trove)

type InputFrame = InputTypes.InputFrame

export type CharacterSession = {
	Character: Model,

	RenderStep: (self: CharacterSession, frame: InputFrame, dt: number) -> (),
	PreSimulation: (self: CharacterSession, dt: number) -> (),
	Destroy: (self: CharacterSession) -> (),
}

type Impl = {
	Character: Model,
	Trove: Trove.Trove,
	Rig: Rig.Rig,
	Motor: Motor.Motor,
	Animation: Animation.Animation,
	Tilt: GroundTilt.GroundTilt,
	LockOn: LockOn.LockOn,
	Camera: CameraRig.CameraRig,
	Context: Context.Context,
	StateMachine: StateMachine.StateMachine<Context.Context>,
	Destroyed: boolean,
}

local CharacterSession = {}
CharacterSession.__index = CharacterSession

local function onDied(self: Impl)
	if not self.Destroyed and self.StateMachine:GetState() ~= "Dead" then
		self.StateMachine:Transition("Dead")
	end
end

-- Yields while the character loads. Returns nil if the character can't be controlled.
function CharacterSession.new(
	character: Model,
	buffer: ActionBuffer.ActionBuffer,
	registry: TargetRegistry.TargetRegistry
): CharacterSession?
	local rig = Rig.new(character)
	if not rig or not character.Parent then
		if rig then
			rig:Destroy()
		end
		return nil
	end

	local trove = Trove.new()
	trove:Add(rig)
	local motor = trove:Add(Motor.new(rig))
	local animation = trove:Add(Animation.new(rig))
	local tilt = trove:Add(GroundTilt.new(rig, motor))
	local lockOn = trove:Add(LockOn.new(rig, registry))
	local camera = trove:Add(CameraRig.new(rig, lockOn))

	local context: Context.Context = {
		Rig = rig,
		Motor = motor,
		Animation = animation,
		Camera = camera,
		LockOn = lockOn,
		Tilt = tilt,
		Buffer = buffer,
		Config = MovementConfig,
		Frame = {
			Time = os.clock(),
			Move = Vector2.zero,
			LookDelta = Vector2.zero,
			LookActive = false,
			SprintHeld = false,
			FreeCursor = false,
			Wheel = 0,
			Pressed = { LockOn = false, ShoulderSwap = false, SwitchLeft = false, SwitchRight = false },
		},
		AirSpeed = MovementConfig.WalkSpeed,
		Roll = nil,
	}

	local stateMachine = StateMachine.new(States, context)
	-- Added before the trove's other items are cleaned (reverse order), so states exit while everything exists.
	trove:Add(stateMachine)

	local self: Impl = {
		Character = character,
		Trove = trove,
		Rig = rig,
		Motor = motor,
		Animation = animation,
		Tilt = tilt,
		LockOn = lockOn,
		Camera = camera,
		Context = context,
		StateMachine = stateMachine,
		Destroyed = false,
	}

	if DebugConfig.LogStates then
		trove:Add(stateMachine.Changed:Connect(function(state: string, previous: string?)
			print(`[State] {previous or "-"} -> {state}`)
		end))
	end

	local humanoid = rig.Humanoid
	trove:Connect(humanoid.Died, function()
		onDied(self)
	end)
	-- Died isn't guaranteed to fire locally while the Humanoid state machine is disabled.
	trove:Connect(humanoid.HealthChanged, function(health: number)
		if health <= 0 then
			onDied(self)
		end
	end)

	buffer:Clear()
	stateMachine:Start("Idle")
	if humanoid.Health <= 0 then
		onDied(self)
	end

	return (setmetatable(self, CharacterSession) :: any) :: CharacterSession
end

-- Lock-on toggling/switching, shoulder swap and zoom.
local function handleCameraInput(self: Impl, frame: InputFrame)
	local lockOn = self.LockOn
	local camera = self.Camera
	local pressed = frame.Pressed

	if pressed.LockOn then
		if lockOn:IsLocked() then
			lockOn:Release()
		elseif not lockOn:TryAcquire(camera:GetCFrame()) then
			camera:Recenter()
		end
	end

	if lockOn:IsLocked() then
		local switch = 0
		if pressed.SwitchRight then
			switch = 1
		elseif pressed.SwitchLeft then
			switch = -1
		elseif frame.Wheel ~= 0 then
			switch = math.sign(frame.Wheel) * (if CameraConfig.LockOn.WheelUpSwitchesRight then 1 else -1)
		end
		if switch ~= 0 then
			lockOn:Switch(switch, camera:GetCFrame())
		end
	elseif frame.Wheel ~= 0 then
		camera:AdjustZoom(-frame.Wheel * CameraConfig.Zoom.Step)
	end

	if pressed.ShoulderSwap then
		camera:SwapShoulder()
	end
end

local function drawDebug(self: Impl)
	if not DebugDraw.Enabled then
		return
	end

	local root = self.Rig.Root
	local position = root.Position
	local motor = self.Motor

	DebugDraw.Ray(position, position + motor:GetVelocity(), Color3.new(0, 1, 0))
	DebugDraw.Ray(position, position + motor:GetFacing() * 3, Color3.new(0, 0.6, 1))
	DebugDraw.Ray(
		position,
		position - Vector3.new(0, self.Rig:GetStandingHeight(), 0),
		if motor:IsGrounded() then Color3.new(1, 1, 0) else Color3.new(1, 0, 0)
	)

	local pitch, roll = self.Tilt:GetTilt()
	DebugDraw.Text(
		position + Vector3.new(0, 4, 0),
		string.format(
			"%s | %.1f studs/s | tilt %.1f, %.1f",
			self.StateMachine:GetState() or "?",
			MathUtil.Flatten(motor:GetVelocity()).Magnitude,
			math.deg(pitch),
			math.deg(roll)
		)
	)

	local targetPoint = self.LockOn:GetTargetPoint()
	if targetPoint then
		DebugDraw.Sphere(targetPoint, 0.5, Color3.new(1, 0.3, 0.3))
	end
end

function CharacterSession.RenderStep(self: Impl, frame: InputFrame, dt: number)
	if self.Destroyed then
		return
	end
	self.Context.Frame = frame

	handleCameraInput(self, frame)
	self.LockOn:Update(dt, self.Camera:GetFocus())

	local moving = MathUtil.Flatten(self.Motor:GetVelocity()).Magnitude > 1 or frame.Move.Magnitude > 0
	self.Camera:UpdateOrientation(frame, dt, moving)

	self.StateMachine:Update(dt)
	self.Animation:UpdateLocomotion(dt)
	self.Camera:UpdateTransform(frame, dt)

	drawDebug(self)
end

function CharacterSession.PreSimulation(self: Impl, dt: number)
	if self.Destroyed then
		return
	end
	self.Motor:PreSimulation(dt)
	self.Tilt:PreSimulation(dt)
end

function CharacterSession.Destroy(self: Impl)
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Trove:Destroy()
end

return CharacterSession
