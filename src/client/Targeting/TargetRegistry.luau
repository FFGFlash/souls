--!strict
-- Live set of models tagged as lock-on targets (see server/LockOnTagger). Lives for the whole session so
-- respawning doesn't need to rebuild it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Trove = require(ReplicatedStorage.Shared.Trove)

export type TargetRegistry = {
	GetTargets: (self: TargetRegistry) -> { [Model]: true },
	Destroy: (self: TargetRegistry) -> (),
}

type Impl = {
	Targets: { [Model]: true },
	Trove: Trove.Trove,
}

local TargetRegistry = {}
TargetRegistry.__index = TargetRegistry

function TargetRegistry.new(): TargetRegistry
	local self: Impl = {
		Targets = {},
		Trove = Trove.new(),
	}

	local function onAdded(instance: Instance)
		if instance:IsA("Model") then
			self.Targets[instance] = true
		end
	end

	local function onRemoved(instance: Instance)
		if instance:IsA("Model") then
			self.Targets[instance] = nil
		end
	end

	self.Trove:Connect(CollectionService:GetInstanceAddedSignal(Tags.LockOnTarget), onAdded)
	self.Trove:Connect(CollectionService:GetInstanceRemovedSignal(Tags.LockOnTarget), onRemoved)
	for _, instance in CollectionService:GetTagged(Tags.LockOnTarget) do
		onAdded(instance)
	end

	return (setmetatable(self, TargetRegistry) :: any) :: TargetRegistry
end

function TargetRegistry.GetTargets(self: Impl): { [Model]: true }
	return self.Targets
end

function TargetRegistry.Destroy(self: Impl)
	self.Trove:Destroy()
	table.clear(self.Targets)
end

return TargetRegistry
