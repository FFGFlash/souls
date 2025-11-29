local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(script.Parent.Types)
local ReservedSlots = require(ReplicatedStorage.Shared.Enums.ReservedSlots)

local Shortsword: Types.WeaponData = {
	Id = "Shortsword",
	Name = "Shortsword",
	Description = "A simple rusty shortsword.",
	Rarity = "common",

	Slots = {
		[ReservedSlots.PrimaryMainHand] = true,
		[ReservedSlots.SecondaryMainHand] = true,
		[ReservedSlots.PrimaryOffHand] = true,
		[ReservedSlots.SecondaryOffHand] = true,
	},
	Scaling = { Strength = "D", Dexterity = "C" },

	Type = "weapon",
	Category = "straight_sword",

	Damage = {
		Physical = 5,
	},
	AttackSpeed = 1,

	CombatDataId = "StraightSword_Standard",
	ModelDataId = "Shortsword",
}

return Shortsword
