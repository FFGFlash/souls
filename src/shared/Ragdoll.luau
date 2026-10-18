--!strict
-- Ragdoll joints for humanoid rigs. Every Motor6D (except the root joint) gets a disabled BallSocket or Hinge
-- constraint built from its rest pose; activating the ragdoll swaps the motors for the constraints.
--
-- The server builds the constraints (Setup) so every client has them. Activation runs on the owning client for
-- an instant response, and on the server so it replicates to everyone else. Both make the same changes.
--
-- The Humanoid manages its body parts' CanCollide itself, so the ragdoll doesn't rely on it: body parts stop
-- colliding and each gets an invisible collider welded to it instead. Colliders are only added where the body
-- is simulated (the owning client, or the server for NPCs), and sit in a collision group that doesn't collide
-- with itself so neighbouring colliders can't push each other apart at the joints.
--
-- Each joint's two attachments share one frame at the rest pose, so its limits are centered on the rig's neutral
-- pose. Sockets point their primary axis down the limb (cone = swing, twist = roll around the limb). Hinges
-- rotate around the parent part's X (right) axis; with the rig facing -Z, a negative angle swings the child
-- backwards and a positive angle swings it forwards.

local PhysicsService = game:GetService("PhysicsService")

local JOINT_NAME = "RagdollJoint"
local ROOT_WELD_NAME = "RagdollRootWeld"
local COLLIDER_NAME = "RagdollCollider"
local COLLISION_GROUP = "Ragdoll"
local ATTACHMENT_PREFIX = "Ragdoll"

-- The HumanoidRootPart stays welded to the torso so the camera keeps following the body.
local SKIPPED_JOINTS: { [string]: boolean } = {
	Root = true, -- R15
	RootJoint = true, -- R6
}

type JointLimits = { Kind: "Socket", Cone: number, Twist: number } | { Kind: "Hinge", Lower: number, Upper: number }

-- Angles in degrees, keyed by Motor6D name (R15). Unlisted joints use DEFAULT_JOINT.
local JOINTS: { [string]: JointLimits } = {
	Waist = { Kind = "Socket", Cone = 30, Twist = 20 },
	Neck = { Kind = "Socket", Cone = 45, Twist = 45 },
	LeftShoulder = { Kind = "Socket", Cone = 100, Twist = 45 },
	RightShoulder = { Kind = "Socket", Cone = 100, Twist = 45 },
	LeftElbow = { Kind = "Hinge", Lower = 0, Upper = 135 },
	RightElbow = { Kind = "Hinge", Lower = 0, Upper = 135 },
	LeftWrist = { Kind = "Socket", Cone = 40, Twist = 20 },
	RightWrist = { Kind = "Socket", Cone = 40, Twist = 20 },
	LeftHip = { Kind = "Socket", Cone = 70, Twist = 20 },
	RightHip = { Kind = "Socket", Cone = 70, Twist = 20 },
	LeftKnee = { Kind = "Hinge", Lower = -135, Upper = 0 },
	RightKnee = { Kind = "Hinge", Lower = -135, Upper = 0 },
	LeftAnkle = { Kind = "Socket", Cone = 25, Twist = 10 },
	RightAnkle = { Kind = "Socket", Cone = 25, Twist = 10 },
}
local DEFAULT_JOINT: JointLimits = { Kind = "Socket", Cone = 45, Twist = 30 }

local Ragdoll = {}

local tracked: { [Motor6D]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local pending: { [Motor6D]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- The root's offset from the torso, captured on activation while the root joint still holds it.
local rootOffsets: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function getRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function getTorso(character: Model): BasePart?
	local torso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then torso else nil
end

-- `preferred` made perpendicular to the unit `axis`, falling back to `fallback` when they're parallel.
local function perpendicular(axis: Vector3, preferred: Vector3, fallback: Vector3): Vector3
	local projected = preferred - axis * preferred:Dot(axis)
	if projected.Magnitude < 1e-3 then
		projected = fallback - axis * fallback:Dot(axis)
	end
	return projected.Unit
end

local function clearJoint(motor: Motor6D)
	local joint = motor:FindFirstChild(JOINT_NAME)
	if joint and joint:IsA("Constraint") then
		if joint.Attachment0 then
			joint.Attachment0:Destroy()
		end
		if joint.Attachment1 then
			joint.Attachment1:Destroy()
		end
		joint:Destroy()
	end
end

local function buildJoint(motor: Motor6D)
	clearJoint(motor)

	local part0, part1 = motor.Part0, motor.Part1
	if not (part0 and part1) then
		return
	end
	local limits = JOINTS[motor.Name] or DEFAULT_JOINT

	-- Part1 relative to Part0 at the rest pose (identity Transform).
	local rest = motor.C0 * motor.C1:Inverse()
	local pivot = motor.C0.Position
	local along = rest.Position - pivot
	along = if along.Magnitude > 1e-3 then along.Unit else -Vector3.yAxis

	local primary, secondary
	if limits.Kind == "Hinge" then
		primary = Vector3.xAxis
		secondary = perpendicular(primary, along, -Vector3.yAxis)
	else
		primary = along
		secondary = perpendicular(primary, Vector3.zAxis, Vector3.xAxis)
	end
	local frame0 = CFrame.fromMatrix(pivot, primary, secondary)

	local name = ATTACHMENT_PREFIX .. motor.Name
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = name
	attachment0.CFrame = frame0
	attachment0.Parent = part0

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = name
	attachment1.CFrame = rest:Inverse() * frame0
	attachment1.Parent = part1

	local joint: Constraint
	if limits.Kind == "Hinge" then
		local hinge = Instance.new("HingeConstraint")
		hinge.LimitsEnabled = true
		hinge.LowerAngle = limits.Lower
		hinge.UpperAngle = limits.Upper
		joint = hinge
	else
		local socket = Instance.new("BallSocketConstraint")
		socket.LimitsEnabled = true
		socket.UpperAngle = limits.Cone
		socket.TwistLimitsEnabled = true
		socket.TwistLowerAngle = -limits.Twist
		socket.TwistUpperAngle = limits.Twist
		joint = socket
	end
	joint.Name = JOINT_NAME
	joint.Attachment0 = attachment0
	joint.Attachment1 = attachment1
	-- Ragdolled already (e.g. rebuilt after death): take over from the motor straight away.
	joint.Enabled = not motor.Enabled
	joint.Parent = motor
end

local function addCollider(part: BasePart)
	if part:FindFirstChild(COLLIDER_NAME) then
		return
	end

	local collider = Instance.new("Part")
	collider.Name = COLLIDER_NAME
	collider.Size = part.Size
	collider.CFrame = part.CFrame
	collider.Transparency = 1
	collider.Massless = true
	collider.CanCollide = true
	collider.CanQuery = false
	collider.CanTouch = false
	collider.CollisionGroup = COLLISION_GROUP
	-- Keeps the character controller's collision setup (Rig) from switching it off.
	collider:SetAttribute("ControllerCollider", true)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = collider
	weld.Parent = collider

	collider.Parent = part
end

-- Builds the motor's joint now and rebuilds it whenever the rig changes it (body scaling, appearance loading).
local function track(motor: Motor6D)
	if tracked[motor] or SKIPPED_JOINTS[motor.Name] then
		return
	end
	tracked[motor] = true

	local function schedule()
		if pending[motor] then
			return
		end
		pending[motor] = true
		-- Deferred so several property changes (and Part0/Part1 set just after parenting) rebuild once.
		task.defer(function()
			pending[motor] = nil
			if motor.Parent then
				buildJoint(motor)
			end
		end)
	end

	for _, property in { "C0", "C1", "Part0", "Part1" } do
		motor:GetPropertyChangedSignal(property):Connect(schedule)
	end
	schedule()
end

-- Server, once: registers the colliders' collision group (it replicates to clients).
function Ragdoll.RegisterCollisionGroup()
	if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end

-- Server: gives the rig ragdoll joints and keeps them in sync with its motors. Joints die with the character.
function Ragdoll.Setup(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			track(descendant)
		end
	end
	character.DescendantAdded:Connect(function(descendant: Instance)
		if descendant:IsA("Motor6D") then
			track(descendant)
		end
	end)
end

-- Swaps every motor that has a ragdoll joint for that joint, and moves the body's collision onto colliders when
-- `simulated` (this machine runs the body's physics). Safe to call repeatedly.
function Ragdoll.Activate(character: Model, simulated: boolean)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
	end
	local root = getRoot(character)
	local torso = getTorso(character)
	if root then
		-- Welded inside the torso, so colliding would prop the body up and shove the limbs around.
		root.CanCollide = false
		if torso and not rootOffsets[character] and root.AssemblyRootPart == torso.AssemblyRootPart then
			rootOffsets[character] = torso.CFrame:ToObjectSpace(root.CFrame)
		end
	end

	local bodyParts: { [BasePart]: boolean } = {}
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("Motor6D") then
			continue
		end
		for _, part in { descendant.Part0, descendant.Part1 } do
			if part and part ~= root then
				bodyParts[part] = true
			end
		end

		local joint = descendant:FindFirstChild(JOINT_NAME)
		if joint and joint:IsA("Constraint") then
			joint.Enabled = true
			descendant.Enabled = false
		end
	end

	for part in bodyParts do
		part.CanCollide = false
		if simulated then
			addCollider(part)
		end
	end
end

-- Call every frame while ragdolled, where the body is simulated. The Humanoid can detach the root from the torso
-- on death, which would leave it (and the camera following it) falling through the floor; this welds it back.
function Ragdoll.KeepRootAttached(character: Model)
	local root = getRoot(character)
	local torso = getTorso(character)
	local offset = rootOffsets[character]
	if not (root and torso and offset) or root.AssemblyRootPart == torso.AssemblyRootPart then
		return
	end

	local weld = root:FindFirstChild(ROOT_WELD_NAME)
	if weld then
		weld:Destroy()
	end
	root.CFrame = torso.CFrame * offset
	root.AssemblyLinearVelocity = torso.AssemblyLinearVelocity

	local newWeld = Instance.new("WeldConstraint")
	newWeld.Name = ROOT_WELD_NAME
	newWeld.Part0 = torso
	newWeld.Part1 = root
	newWeld.Parent = root
end

return Ragdoll
