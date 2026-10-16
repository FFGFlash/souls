--!strict
-- Fades out parts between the camera and the character, and fades the character itself when the camera gets
-- very close. Uses LocalTransparencyModifier, which is client-only and never touches the parts' real
-- Transparency, so everything can be restored exactly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraConfig = require(script.Parent.Parent.Config.Camera)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Rig = require(script.Parent.Parent.Character.Rig)

export type Occlusion = {
	Update: (self: Occlusion, dt: number, cameraPosition: Vector3, focus: Vector3) -> (),
	Destroy: (self: Occlusion) -> (),
}

type Impl = {
	Rig: Rig.Rig,
	Config: typeof(CameraConfig.Occlusion),
	-- Parts we have faded and their current modifier.
	Faded: { [BasePart]: number },
	CharacterFade: number,
}

local Occlusion = {}
Occlusion.__index = Occlusion

function Occlusion.new(rig: Rig.Rig): Occlusion
	local self: Impl = {
		Rig = rig,
		Config = CameraConfig.Occlusion,
		Faded = {},
		CharacterFade = 0,
	}
	return (setmetatable(self, Occlusion) :: any) :: Occlusion
end

local function findOccluders(self: Impl, from: Vector3, to: Vector3): { [BasePart]: true }
	local occluders: { [BasePart]: true } = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.Rig.Character }
	params.IgnoreWater = true

	local direction = to - from
	for _ = 1, self.Config.MaxHits do
		local result = workspace:Raycast(from, direction, params)
		if not result then
			break
		end
		local part = result.Instance
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			occluders[part] = true
		end
		params:AddToFilter(part)
	end
	return occluders
end

local function setCharacterFade(self: Impl, fade: number)
	if math.abs(fade - self.CharacterFade) < 1e-3 then
		return
	end
	self.CharacterFade = fade
	for _, descendant in self.Rig.Character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			(descendant :: any).LocalTransparencyModifier = fade
		end
	end
end

function Occlusion.Update(self: Impl, dt: number, cameraPosition: Vector3, focus: Vector3)
	local config = self.Config
	local occluders: { [BasePart]: true } = {}
	if config.Enabled then
		occluders = findOccluders(self, cameraPosition, focus)
	end

	for part in occluders do
		if self.Faded[part] == nil then
			self.Faded[part] = part.LocalTransparencyModifier
		end
	end

	for part, current in self.Faded do
		if not part.Parent then
			self.Faded[part] = nil
			continue
		end

		local target = if occluders[part] then config.Transparency else 0
		local value = MathUtil.Damp(current, target, config.Rate, dt)
		if target == 0 and value < 0.01 then
			part.LocalTransparencyModifier = 0
			self.Faded[part] = nil
		else
			part.LocalTransparencyModifier = value
			self.Faded[part] = value
		end
	end

	local distance = (cameraPosition - focus).Magnitude
	local fade = 1
		- math.clamp((distance - config.CharacterFadeEnd) / (config.CharacterFadeStart - config.CharacterFadeEnd), 0, 1)
	setCharacterFade(self, fade)
end

function Occlusion.Destroy(self: Impl)
	for part in self.Faded do
		part.LocalTransparencyModifier = 0
	end
	table.clear(self.Faded)
	if self.Rig.Character.Parent then
		setCharacterFade(self, 0)
	end
end

return Occlusion
