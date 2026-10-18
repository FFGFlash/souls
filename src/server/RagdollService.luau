--!strict
-- Gives every humanoid rig in Workspace (player characters and NPCs) ragdoll joints, and ragdolls it on death.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)

local RagdollService = {}

local watched: { [Humanoid]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function onDied(model: Model)
	local player = Players:GetPlayerFromCharacter(model)
	-- A player's client simulates its own body and adds the colliders itself; the server simulates NPCs.
	Ragdoll.Activate(model, player == nil)
	if not player then
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if model.Parent then
				Ragdoll.KeepRootAttached(model)
			else
				connection:Disconnect()
			end
		end)
		return
	end

	-- The body is now many assemblies; keep the owning client simulating all of them (it ragdolled locally first).
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:CanSetNetworkOwnership() then
			descendant:SetNetworkOwner(player)
		end
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Humanoid") or watched[instance] then
		return
	end
	local model = instance.Parent
	if not (model and model:IsA("Model")) then
		return
	end
	watched[instance] = true

	Ragdoll.Setup(model)
	instance.Died:Once(function()
		onDied(model)
	end)
end

function RagdollService.Start()
	Ragdoll.RegisterCollisionGroup()

	for _, descendant in workspace:GetDescendants() do
		watch(descendant)
	end
	workspace.DescendantAdded:Connect(watch)
end

return RagdollService
