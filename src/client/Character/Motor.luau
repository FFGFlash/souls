--!strict
-- Physics-driven character motor built on Roblox's ControllerManager.
--
--  * Ground and air movement come from a GroundController / AirController pair. The controllers hover the
--    root at hip height, handle slopes and steps, accelerate, turn and keep the character upright.
--  * Ground detection uses a ControllerPartSensor. This module decides which controller is active, because
--    ControllerManager doesn't switch on its own.
--  * "Override" mode drives horizontal velocity directly with a LinearVelocity, for rolls, root motion and
--    knockback. The active controller keeps handling hover height and gravity.
--  * Only the root part collides (see Rig), so while airborne a frictionless foot collider is enabled under the
--    legs. Without it nothing would hold the character at hip height when sliding down steep slopes, and the
--    legs would sink into the ground.
--
-- Nothing here writes Root.CFrame. States set intents during the render step and physics applies them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local MovementConfig = require(script.Parent.Parent.Config.Movement)
local Rig = require(script.Parent.Rig)
local Trove = require(ReplicatedStorage.Shared.Trove)

type MovementConfig = typeof(MovementConfig)

export type Motor = {
	-- Locomotion intent: `direction` is flat with magnitude 0..1, `speed` is studs/s at full magnitude.
	SetMove: (self: Motor, direction: Vector3, speed: number) -> (),
	-- Direction the character turns to face. nil keeps the current facing.
	SetFacing: (self: Motor, direction: Vector3?) -> (),
	-- Overrides the turn speed (rad/s-like ControllerManager units). nil restores the default.
	SetTurnSpeed: (self: Motor, speed: number?) -> (),
	-- Drives horizontal velocity directly while set. nil returns control to the ground/air controllers.
	SetOverrideVelocity: (self: Motor, velocity: Vector3?) -> (),
	Jump: (self: Motor, height: number) -> (),
	-- Knocks the character into the air with the given velocity.
	Launch: (self: Motor, velocity: Vector3) -> (),

	IsGrounded: (self: Motor) -> boolean,
	-- 0 while grounded, otherwise seconds since the character left the ground.
	GetTimeAirborne: (self: Motor) -> number,
	-- Height of the root part's bottom above the sensed floor (math.huge if none), and the target height.
	GetGroundClearance: (self: Motor) -> (number, number),
	-- While airborne: distance fallen from the highest point. After landing: total height of the last fall.
	GetFallHeight: (self: Motor) -> number,
	GetGroundNormal: (self: Motor) -> Vector3,
	GetVelocity: (self: Motor) -> Vector3,
	GetFacing: (self: Motor) -> Vector3,
	IsOverriding: (self: Motor) -> boolean,

	-- Called every frame before physics.
	PreSimulation: (self: Motor, dt: number) -> (),
	Destroy: (self: Motor) -> (),
}

type Impl = {
	Rig: Rig.Rig,
	Config: MovementConfig,
	Trove: Trove.Trove,

	Manager: ControllerManager,
	Ground: GroundController,
	Air: AirController,
	Sensor: ControllerPartSensor,
	Override: LinearVelocity,
	FootCollider: Part,
	FootWeld: Weld,

	Grounded: boolean,
	HeightAboveGround: number,
	AirborneAt: number,
	GroundLockoutUntil: number,
	PeakHeight: number,
	FallHeight: number,

	MoveDirection: Vector3,
	MoveSpeed: number,
	OverrideVelocity: Vector3?,
	Destroyed: boolean,
}

local Motor = {}
Motor.__index = Motor

local function getHoverHeight(self: Impl): number
	return self.Rig:GetHipHeight() + self.Config.GroundOffsetAdjust
end

local function applySizing(self: Impl)
	local rig = self.Rig
	local config = self.Config
	local rootHalfHeight = rig.Root.Size.Y / 2
	local hoverHeight = getHoverHeight(self)

	-- GroundOffset works like Humanoid.HipHeight: the gap between the root part's bottom and the floor.
	self.Ground.GroundOffset = hoverHeight
	-- Generous search range (measured from the root's center); our own grounded check enforces the real limit.
	self.Sensor.SearchDistance = rootHalfHeight + hoverHeight + config.GroundSearchMargin
	self.Air.MoveMaxForce = rig.Root.AssemblyMass * config.AirAcceleration

	-- The foot collider's bottom sits exactly where the feet should be.
	local radius = config.FootColliderDiameter / 2
	self.FootCollider.Size = Vector3.one * config.FootColliderDiameter
	self.FootWeld.C0 = CFrame.new(0, -(rootHalfHeight + hoverHeight) + radius, 0)
end

local function createFootCollider(trove: Trove.Trove, root: BasePart): (Part, Weld)
	local collider = trove:Add(Instance.new("Part"))
	collider.Name = "FootCollider"
	collider.Shape = Enum.PartType.Ball
	collider.Transparency = 1
	collider.Massless = true
	collider.CanCollide = false
	collider.CanQuery = false
	collider.CanTouch = false
	collider.CastShadow = false
	-- Frictionless and non-bouncy so the character slides down steep slopes instead of sticking to them.
	collider.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 100, 100)
	-- Tells Rig not to manage this part's collision.
	collider:SetAttribute("ControllerCollider", true)
	collider.CFrame = root.CFrame

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = collider
	weld.Parent = collider

	collider.Parent = root
	return collider, weld
end

local function applyMoveIntent(self: Impl)
	local override = self.OverrideVelocity
	if override then
		-- Ask the controllers for the same velocity the override holds so they don't fight it.
		local flat = MathUtil.Flatten(override)
		local speed = flat.Magnitude
		self.Manager.MovingDirection = if speed > 1e-3 then flat / speed else Vector3.zero
		self.Manager.BaseMoveSpeed = speed
	else
		self.Manager.MovingDirection = self.MoveDirection
		self.Manager.BaseMoveSpeed = self.MoveSpeed
	end
end

function Motor.new(rig: Rig.Rig): Motor
	local config = MovementConfig
	local root = rig.Root
	local trove = Trove.new()

	local sensor = trove:Add(Instance.new("ControllerPartSensor"))
	sensor.Name = "GroundSensor"
	sensor.SensorMode = Enum.SensorMode.Floor
	sensor.UpdateType = Enum.SensorUpdateType.OnRead
	sensor.Parent = root

	local manager = trove:Add(Instance.new("ControllerManager"))
	manager.Name = "ControllerManager"

	local ground = Instance.new("GroundController")
	ground.AccelerationTime = config.AccelerationTime
	ground.DecelerationTime = config.DecelerationTime
	ground.BalanceRigidityEnabled = true
	-- Keep the physics root upright while accelerating; slope tilt is applied visually by GroundTilt.
	pcall(function()
		ground.AccelerationLean = 0
	end)
	ground.Parent = manager

	local air = Instance.new("AirController")
	air.MaintainLinearMomentum = true
	air.MaintainAngularMomentum = false
	air.BalanceRigidityEnabled = true
	air.Parent = manager

	manager.RootPart = root
	manager.GroundSensor = sensor
	manager.BaseMoveSpeed = 0
	manager.BaseTurnSpeed = config.TurnSpeed
	manager.MovingDirection = Vector3.zero
	manager.FacingDirection = MathUtil.FlatUnit(root.CFrame.LookVector)
	manager.ActiveController = ground

	local attachment = trove:Add(Instance.new("Attachment"))
	attachment.Name = "MotorAttachment"
	attachment.Parent = root

	local override = trove:Add(Instance.new("LinearVelocity"))
	override.Name = "MotorOverride"
	override.Attachment0 = attachment
	override.RelativeTo = Enum.ActuatorRelativeTo.World
	override.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	override.PrimaryTangentAxis = Vector3.xAxis
	override.SecondaryTangentAxis = Vector3.zAxis
	override.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	override.ReactionForceEnabled = false
	override.Enabled = false
	override.Parent = root

	local footCollider, footWeld = createFootCollider(trove, root)

	local self: Impl = {
		Rig = rig,
		Config = config,
		Trove = trove,

		Manager = manager,
		Ground = ground,
		Air = air,
		Sensor = sensor,
		Override = override,
		FootCollider = footCollider,
		FootWeld = footWeld,

		Grounded = true,
		HeightAboveGround = 0,
		AirborneAt = 0,
		GroundLockoutUntil = 0,
		PeakHeight = root.Position.Y,
		FallHeight = 0,

		MoveDirection = Vector3.zero,
		MoveSpeed = 0,
		OverrideVelocity = nil,
		Destroyed = false,
	}

	applySizing(self)
	trove:Connect(rig.Humanoid:GetPropertyChangedSignal("HipHeight"), function()
		applySizing(self)
	end)
	trove:Connect(root:GetPropertyChangedSignal("Size"), function()
		applySizing(self)
	end)

	-- Parent last so the controllers are fully configured before they start acting on the character.
	manager.Parent = rig.Character
	rig.Humanoid.EvaluateStateMachine = false

	return (setmetatable(self, Motor) :: any) :: Motor
end

function Motor.SetMove(self: Impl, direction: Vector3, speed: number)
	self.MoveDirection = direction
	self.MoveSpeed = speed
	applyMoveIntent(self)
end

function Motor.SetFacing(self: Impl, direction: Vector3?)
	if not direction then
		return
	end
	local flat = MathUtil.FlatUnit(direction)
	if flat.Magnitude > 0 then
		self.Manager.FacingDirection = flat
	end
end

function Motor.SetTurnSpeed(self: Impl, speed: number?)
	self.Manager.BaseTurnSpeed = speed or self.Config.TurnSpeed
end

function Motor.SetOverrideVelocity(self: Impl, velocity: Vector3?)
	self.OverrideVelocity = velocity
	local override = self.Override

	if velocity then
		override.MaxForce = self.Rig.Root.AssemblyMass * self.Config.OverrideAcceleration
		override.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
		override.Enabled = true
	else
		override.Enabled = false
	end

	applyMoveIntent(self)
end

local function becomeAirborne(self: Impl)
	if self.Grounded then
		self.Grounded = false
		self.AirborneAt = os.clock()
		self.PeakHeight = self.Rig.Root.Position.Y
		self.FallHeight = 0
	end
	self.Manager.ActiveController = self.Air
end

function Motor.Jump(self: Impl, height: number)
	local root = self.Rig.Root
	local velocity = root.AssemblyLinearVelocity
	local upSpeed = math.sqrt(2 * workspace.Gravity * height)

	becomeAirborne(self)
	self.GroundLockoutUntil = os.clock() + self.Config.Jump.Lockout
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, 0) + upSpeed, velocity.Z)
end

function Motor.Launch(self: Impl, velocity: Vector3)
	becomeAirborne(self)
	self.GroundLockoutUntil = os.clock() + self.Config.Jump.Lockout
	self.Rig.Root.AssemblyLinearVelocity = velocity
end

function Motor.IsGrounded(self: Impl): boolean
	return self.Grounded
end

function Motor.GetTimeAirborne(self: Impl): number
	if self.Grounded then
		return 0
	end
	return os.clock() - self.AirborneAt
end

function Motor.GetGroundClearance(self: Impl): (number, number)
	return self.HeightAboveGround, self.Ground.GroundOffset
end

function Motor.GetFallHeight(self: Impl): number
	if self.Grounded then
		return self.FallHeight
	end
	return math.max(self.PeakHeight - self.Rig.Root.Position.Y, 0)
end

function Motor.GetGroundNormal(self: Impl): Vector3
	if self.Grounded then
		return self.Sensor.HitNormal
	end
	return Vector3.yAxis
end

function Motor.GetVelocity(self: Impl): Vector3
	return self.Rig.Root.AssemblyLinearVelocity
end

function Motor.GetFacing(self: Impl): Vector3
	return self.Manager.FacingDirection
end

function Motor.IsOverriding(self: Impl): boolean
	return self.OverrideVelocity ~= nil
end

function Motor.PreSimulation(self: Impl, _dt: number)
	if self.Destroyed then
		return
	end

	local config = self.Config
	local root = self.Rig.Root
	local sensor = self.Sensor
	local now = os.clock()

	local groundOffset = self.Ground.GroundOffset
	local velocity = root.AssemblyLinearVelocity
	local sensedPart = sensor.SensedPart

	-- Height of the root's bottom above the sensed floor (same reference as GroundOffset).
	local heightAboveGround = math.huge
	local walkable = false
	if sensedPart then
		heightAboveGround = (root.Position.Y - root.Size.Y / 2) - sensor.HitFrame.Position.Y
		walkable = sensor.HitNormal.Y >= math.cos(config.MaxSlopeAngle)
	end
	self.HeightAboveGround = heightAboveGround

	local grounded
	if now < self.GroundLockoutUntil or not walkable then
		grounded = false
	elseif self.Grounded then
		-- Stay grounded over small drops (stepping down stairs); the ground snap pulls us down onto them.
		grounded = heightAboveGround <= groundOffset + config.GroundSearchMargin
	else
		-- Only land once we're close to standing height and not still moving upwards.
		grounded = heightAboveGround <= groundOffset + config.LandTolerance and velocity.Y <= 1
	end

	if grounded then
		if not self.Grounded then
			self.Grounded = true
			self.FallHeight = math.max(self.PeakHeight - root.Position.Y, 0)
		end
		self.Manager.ActiveController = self.Ground

		-- The GroundController only pushes up, so pull the character down onto the ground when it is
		-- hovering too high (e.g. walking over the top of a ramp or down stairs).
		local snap = config.GroundSnap
		if snap.Enabled and heightAboveGround > groundOffset + snap.Threshold and velocity.Y > -snap.Speed then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, -snap.Speed, velocity.Z)
		end
	else
		becomeAirborne(self)
		self.PeakHeight = math.max(self.PeakHeight, root.Position.Y)
	end

	-- While grounded the GroundController holds the legs above the floor, and a collider there would snag on
	-- steps. While airborne the collider keeps the legs out of slopes and floors.
	local footCollides = not grounded
	if self.FootCollider.CanCollide ~= footCollides then
		self.FootCollider.CanCollide = footCollides
	end
end

function Motor.Destroy(self: Impl)
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Trove:Destroy()

	local humanoid = self.Rig.Humanoid
	if humanoid.Parent then
		humanoid.EvaluateStateMachine = true
	end
end

return Motor
