local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(script.Parent.Types)
local Models = ReplicatedStorage.Models

local Shortsword: Types.ModelAssetData = {
	Id = "Shortsword",
	Type = "Model",
	Models = {
		{
			Level = 0,
			Equipped = { Models:WaitForChild("Shortsword") },
			Sheathed = { Models:WaitForChild("SheathedShortsword") },
		},
	},
	Attributes = {
		Color = Color3.new(0.4, 0.45, 0.5),
	},
}

return Shortsword
