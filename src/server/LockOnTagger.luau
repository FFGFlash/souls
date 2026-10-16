--!strict
-- Tags lock-on targets: NPC rigs (models with a Humanoid in Workspace) and every player's character.
-- Clients filter out their own character and dead targets, so tags are never removed here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local LockOnTagger = {}

local function tagModel(model: Instance?)
	if model and model:IsA("Model") and not model:HasTag(Tags.LockOnTarget) then
		model:AddTag(Tags.LockOnTarget)
	end
end

local function tryTagHumanoidOwner(instance: Instance)
	if not instance:IsA("Humanoid") then
		return
	end

	local model = instance.Parent
	if model and not Players:GetPlayerFromCharacter(model) then
		tagModel(model)
	end
end

local function onPlayerAdded(player: Player)
	if player.Character then
		tagModel(player.Character)
	end
	player.CharacterAdded:Connect(tagModel)
end

function LockOnTagger.Start()
	for _, descendant in workspace:GetDescendants() do
		tryTagHumanoidOwner(descendant)
	end
	workspace.DescendantAdded:Connect(tryTagHumanoidOwner)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return LockOnTagger
