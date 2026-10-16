--!strict
-- Turns raw UserInputService input (keyboard, mouse and gamepad) into a per-frame InputFrame snapshot.
-- Button state is tracked from events, not polled, so keys pressed while typing in chat are ignored and
-- nothing gets stuck after the window loses focus. Sticks and mouse delta are polled once per frame in Sample.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ActionBuffer = require(script.Parent.ActionBuffer)
local Bindings = require(script.Parent.Parent.Config.Bindings)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Trove = require(ReplicatedStorage.Shared.Trove)
local Types = require(script.Parent.Types)

type BindingsConfig = typeof(Bindings)
type InputFrame = Types.InputFrame
type Presses = Types.Presses

export type Input = {
	Buffer: ActionBuffer.ActionBuffer,

	Sample: (self: Input, dt: number) -> InputFrame,
	Destroy: (self: Input) -> (),
}

type Impl = {
	Buffer: ActionBuffer.ActionBuffer,
	Bindings: BindingsConfig,
	Trove: Trove.Trove,

	-- Which actions each raw input (KeyCode or UserInputType) triggers.
	ActionsByInput: { [EnumItem]: { string } },
	HeldInputs: { [EnumItem]: boolean },
	HeldCount: { [string]: number },
	Pressed: Presses,
	Wheel: number,
	-- Mouse movement accumulated from InputChanged since the last Sample, and whether the mouse was locked then.
	MouseDelta: Vector2,
	MouseWasLocked: boolean,
	DodgeDownAt: number?,
	FlickArmed: boolean,
}

local Input = {}
Input.__index = Input

local function newPresses(): Presses
	return { LockOn = false, ShoulderSwap = false, SwitchLeft = false, SwitchRight = false }
end

local function getInputKey(input: InputObject): EnumItem
	-- KeyCode.Unknown (value 0) means this is a mouse button, so key it by UserInputType instead.
	if input.KeyCode.Value ~= 0 then
		return input.KeyCode
	end
	return input.UserInputType
end

local function isHeld(self: Impl, keys: { EnumItem }): boolean
	for _, key in keys do
		if self.HeldInputs[key] then
			return true
		end
	end
	return false
end

local function onActionPressed(self: Impl, action: string)
	if action == "Dodge" then
		self.DodgeDownAt = os.clock()
	elseif action == "Jump" then
		self.Buffer:Push("Jump")
	elseif action == "LockOn" then
		self.Pressed.LockOn = true
	elseif action == "ShoulderSwap" then
		self.Pressed.ShoulderSwap = true
	end
end

local function onActionReleased(self: Impl, action: string)
	if action == "Dodge" then
		local downAt = self.DodgeDownAt
		-- A short tap is a roll; releasing after a hold just ends the sprint.
		if downAt and os.clock() - downAt < self.Bindings.DodgeHoldTime then
			self.Buffer:Push("Roll")
		end
		self.DodgeDownAt = nil
	end
end

local function onInputBegan(self: Impl, input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	local key = getInputKey(input)
	if self.HeldInputs[key] then
		return
	end
	self.HeldInputs[key] = true

	local actions = self.ActionsByInput[key]
	if not actions then
		return
	end
	for _, action in actions do
		local count = (self.HeldCount[action] or 0) + 1
		self.HeldCount[action] = count
		if count == 1 then
			onActionPressed(self, action)
		end
	end
end

local function onInputEnded(self: Impl, input: InputObject)
	-- Always processed (even if gameProcessed) so a release is never missed.
	local key = getInputKey(input)
	if not self.HeldInputs[key] then
		return
	end
	self.HeldInputs[key] = nil

	local actions = self.ActionsByInput[key]
	if not actions then
		return
	end
	for _, action in actions do
		local count = math.max((self.HeldCount[action] or 0) - 1, 0)
		self.HeldCount[action] = count
		if count == 0 then
			onActionReleased(self, action)
		end
	end
end

local function releaseEverything(self: Impl)
	table.clear(self.HeldInputs)
	table.clear(self.HeldCount)
	self.DodgeDownAt = nil
end

function Input.new(): Input
	local self: Impl = {
		Buffer = ActionBuffer.new(),
		Bindings = Bindings,
		Trove = Trove.new(),
		ActionsByInput = {},
		HeldInputs = {},
		HeldCount = {},
		Pressed = newPresses(),
		Wheel = 0,
		MouseDelta = Vector2.zero,
		MouseWasLocked = false,
		DodgeDownAt = nil,
		FlickArmed = true,
	}

	for action, keys in Bindings.Actions do
		for _, key in keys do
			local actions = self.ActionsByInput[key]
			if not actions then
				actions = {}
				self.ActionsByInput[key] = actions
			end
			table.insert(actions, action)
		end
	end

	self.Trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessed: boolean)
		onInputBegan(self, input, gameProcessed)
	end)
	self.Trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		onInputEnded(self, input)
	end)
	self.Trove:Connect(UserInputService.InputChanged, function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- Accumulating per-event deltas is reliable at any frame rate, unlike polling GetMouseDelta.
			self.MouseDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
			self.Wheel += input.Position.Z
		end
	end)
	self.Trove:Connect(UserInputService.WindowFocusReleased, function()
		releaseEverything(self)
	end)

	return (setmetatable(self, Input) :: any) :: Input
end

local function readSticks(): (Vector2, Vector2)
	local left, right = Vector2.zero, Vector2.zero
	if not UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
		return left, right
	end

	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick1 then
			left = Vector2.new(state.Position.X, state.Position.Y)
		elseif state.KeyCode == Enum.KeyCode.Thumbstick2 then
			right = Vector2.new(state.Position.X, state.Position.Y)
		end
	end
	return left, right
end

local function sampleMove(self: Impl, leftStick: Vector2): Vector2
	local move = self.Bindings.Move
	local x = (if isHeld(self, move.Right) then 1 else 0) - (if isHeld(self, move.Left) then 1 else 0)
	local y = (if isHeld(self, move.Forward) then 1 else 0) - (if isHeld(self, move.Backward) then 1 else 0)

	local keyboard = Vector2.new(x, y)
	if keyboard.Magnitude > 0 then
		return keyboard.Unit
	end

	local gamepad = self.Bindings.Gamepad
	return MathUtil.RadialDeadzone(leftStick, gamepad.MoveDeadzone, gamepad.MoveOuterDeadzone)
end

local function sampleLook(self: Impl, rightStick: Vector2, dt: number): Vector2
	local mouse = self.Bindings.Mouse
	local mouseDelta = self.MouseDelta
	self.MouseDelta = Vector2.zero

	-- Ignore mouse movement while the cursor is free, and on the frame it gets locked again (that delta is the
	-- cursor snapping back to the center, not the player looking around).
	local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	if not (locked and self.MouseWasLocked) then
		mouseDelta = Vector2.zero
	end
	self.MouseWasLocked = locked

	local look = Vector2.new(
		mouseDelta.X * mouse.Sensitivity * (if mouse.InvertX then -1 else 1),
		-mouseDelta.Y * mouse.Sensitivity * (if mouse.InvertY then -1 else 1)
	)

	local gamepad = self.Bindings.Gamepad
	local stick = MathUtil.RadialDeadzone(rightStick, gamepad.LookDeadzone, 1)
	local magnitude = stick.Magnitude
	if magnitude > 0 then
		local curved = stick / magnitude * magnitude ^ gamepad.LookResponseCurve
		look += Vector2.new(
			curved.X * gamepad.LookSpeedX * dt * (if gamepad.InvertX then -1 else 1),
			curved.Y * gamepad.LookSpeedY * dt * (if gamepad.InvertY then -1 else 1)
		)
	end

	return look
end

-- Detects a right-stick flick (used to switch lock-on targets) and re-arms once the stick recenters.
local function sampleFlick(self: Impl, rightStick: Vector2)
	local gamepad = self.Bindings.Gamepad
	local magnitude = rightStick.Magnitude

	if self.FlickArmed and magnitude >= gamepad.FlickThreshold and math.abs(rightStick.X) > math.abs(rightStick.Y) then
		self.FlickArmed = false
		if rightStick.X > 0 then
			self.Pressed.SwitchRight = true
		else
			self.Pressed.SwitchLeft = true
		end
	elseif magnitude <= gamepad.FlickReset then
		self.FlickArmed = true
	end
end

function Input.Sample(self: Impl, dt: number): InputFrame
	local leftStick, rightStick = readSticks()
	sampleFlick(self, rightStick)

	local look = sampleLook(self, rightStick, dt)
	local dodgeDownAt = self.DodgeDownAt

	local frame: InputFrame = {
		Time = os.clock(),
		Move = sampleMove(self, leftStick),
		LookDelta = look,
		LookActive = look.Magnitude > 1e-5,
		SprintHeld = dodgeDownAt ~= nil and os.clock() - dodgeDownAt >= self.Bindings.DodgeHoldTime,
		FreeCursor = (self.HeldCount.FreeCursor or 0) > 0,
		Wheel = self.Wheel,
		Pressed = self.Pressed,
	}

	-- Edges and accumulators belong to exactly one frame.
	self.Pressed = newPresses()
	self.Wheel = 0

	return frame
end

function Input.Destroy(self: Impl)
	self.Trove:Destroy()
	releaseEverything(self)
end

return Input
