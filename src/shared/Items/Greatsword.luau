local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(script.Parent.Types)
local ReservedSlots = require(ReplicatedStorage.Shared.Enums.ReservedSlots)

local Greatsword: Types.WeaponData = {
	Id = "Greatsword",
	Name = "Greatsword",
	Description = "A simple rusty greatsword.",
	Rarity = "common",

	Slots = {
		[ReservedSlots.PrimaryMainHand] = {
			LockSlots = { [ReservedSlots.PrimaryOffHand] = true },
		},
		[ReservedSlots.SecondaryMainHand] = {
			LockSlots = { [ReservedSlots.SecondaryOffHand] = true },
		},
	},
	Scaling = { Strength = "D", Dexterity = "C" },

	Type = "weapon",
	Category = "straight_sword",

	TwoHanded = true,

	Damage = {
		Physical = 10,
	},
	AttackSpeed = 0.8,

	CombatDataId = "StraightSword_Standard",
	ModelDataId = "Greatsword",
}

return Greatsword
