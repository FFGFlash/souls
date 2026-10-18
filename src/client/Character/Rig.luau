--!strict
-- References to the parts of an R15 character that the controller needs, plus collision setup.
--
-- Only the HumanoidRootPart collides: with Humanoid.EvaluateStateMachine disabled nothing else manages limb
-- collisions, and colliding legs would catch on steps while the GroundController hovers the root.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Trove)

local WAIT_TIMEOUT = 10

export type Rig = {
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Animator: Animator,
	-- Excludes the character; shared by ground probes and other character-relative queries.
	RaycastParams: RaycastParams,

	GetRootJoint: (self: Rig) -> Motor6D?,
	GetHipHeight: (self: Rig) -> number,
	-- Distance from the root part's center to the bottom of the feet when standing.
	GetStandingHeight: (self: Rig) -> number,
	-- Stops managing collision and restores the limbs' original CanCollide (e.g. so a corpse rests on the floor).
	ReleaseCollision: (self: Rig) -> (),
	Destroy: (self: Rig) -> (),
}

type Impl = Rig & {
	Trove: Trove.Trove,
	RootJoint: Motor6D?,
	CollisionConnection: RBXScriptConnection?,
	-- CanCollide of each part before the rig overrode it.
	OriginalCollision: { [BasePart]: boolean },
}

local Rig = {}
Rig.__index = Rig

local function setupCollision(self: Impl, part: Instance)
	-- Colliders added by the controller itself (e.g. the Motor's foot collider) manage their own collision.
	if part:IsA("BasePart") and not part:GetAttribute("ControllerCollider") then
		if self.OriginalCollision[part] == nil then
			self.OriginalCollision[part] = part.CanCollide
		end
		part.CanCollide = part == self.Root
	end
end

-- Yields until the character's parts exist. Returns nil if the character is unusable (e.g. it was removed).
function Rig.new(character: Model): Rig?
	local humanoid = character:WaitForChild("Humanoid", WAIT_TIMEOUT)
	local root = character:WaitForChild("HumanoidRootPart", WAIT_TIMEOUT)
	if not (humanoid and humanoid:IsA("Humanoid") and root and root:IsA("BasePart")) then
		warn("[Rig] Character is missing its Humanoid or HumanoidRootPart:", character:GetFullName())
		return nil
	end

	local animator = humanoid:WaitForChild("Animator", WAIT_TIMEOUT)
	if not (animator and animator:IsA("Animator")) then
		warn("[Rig] Humanoid has no Animator:", character:GetFullName())
		return nil
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn("[Rig] The controller is built for R15 characters. Set the avatar type to R15 in Game Settings.")
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	params.RespectCanCollide = true

	local self: Impl = {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Animator = animator,
		RaycastParams = params,
		Trove = Trove.new(),
		RootJoint = nil,
		CollisionConnection = nil,
		OriginalCollision = setmetatable({}, { __mode = "k" }) :: any,
	} :: any
	setmetatable(self :: any, Rig)

	for _, descendant in character:GetDescendants() do
		setupCollision(self, descendant)
	end
	self.CollisionConnection = self.Trove:Connect(character.DescendantAdded, function(descendant: Instance)
		setupCollision(self, descendant)
	end)

	return self
end

-- The LowerTorso "Root" Motor6D. Re-resolved when the rig is rebuilt (appearance loads, scaling).
function Rig.GetRootJoint(self: Impl): Motor6D?
	local joint = self.RootJoint
	if joint and joint.Parent and joint.Part0 == self.Root then
		return joint
	end

	local lowerTorso = self.Character:FindFirstChild("LowerTorso")
	local found = lowerTorso and lowerTorso:FindFirstChild("Root")
	if found and found:IsA("Motor6D") then
		self.RootJoint = found
		return found
	end
	self.RootJoint = nil
	return nil
end

function Rig.GetHipHeight(self: Impl): number
	return self.Humanoid.HipHeight
end

function Rig.GetStandingHeight(self: Impl): number
	return self.Root.Size.Y / 2 + self.Humanoid.HipHeight
end

function Rig.ReleaseCollision(self: Impl)
	local connection = self.CollisionConnection
	if connection then
		self.CollisionConnection = nil
		connection:Disconnect()
	end
	for part, canCollide in self.OriginalCollision do
		if part.Parent then
			part.CanCollide = canCollide
		end
	end
	table.clear(self.OriginalCollision)
end

function Rig.Destroy(self: Impl)
	self.Trove:Destroy()
end

return Rig
