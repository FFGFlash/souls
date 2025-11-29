local Types = require(script.Parent.Types)

local StraightSword_Standard: Types.CombatData = {
	Id = "StraightSword_Standard",

	Attacks = {
		Light1 = {
			AnimationId = "rbxassetid://0",
			AnimationSpeed = 1.0,
			WindupTime = 0.2,
			RecoveryTime = 0.4,
			DamageMultiplier = 1.0,
			Hitboxes = {},
			CanBeChained = true,
			ChainWindow = 0.3,
			NextAttacks = { "Light2" },
			MovementMultiplier = 0.5,
		},
		Light2 = {
			AnimationId = "rbxassetid://0",
			AnimationSpeed = 1.0,
			WindupTime = 0.2,
			RecoveryTime = 0.5,
			DamageMultiplier = 1.05,
			Hitboxes = {},
			CanBeChained = true,
			ChainWindow = 0.3,
			NextAttacks = { "Light3" },
			MovementMultiplier = 0.5,
		},
		Light3 = {
			AnimationId = "rbxassetid://0",
			AnimationSpeed = 1.0,
			WindupTime = 0.2,
			RecoveryTime = 0.7,
			DamageMultiplier = 1.15,
			Hitboxes = {},
			CanBeChained = false,
			MovementMultiplier = 0.5,
		},
		Heavy1 = {
			AnimationId = "rbxassetid://0",
			AnimationSpeed = 1.0,
			WindupTime = 0.3,
			RecoveryTime = 0.6,
			DamageMultiplier = 1.07,
			Hitboxes = {},
			CanBeChained = true,
			ChainWindow = 0.3,
			NextAttacks = { "Heavy2" },
			MovementMultiplier = 0.4,
		},
		Heavy2 = {
			AnimationId = "rbxassetid://0",
			AnimationSpeed = 1.0,
			WindupTime = 0.4,
			RecoveryTime = 0.8,
			DamageMultiplier = 1.3,
			Hitboxes = {},
			CanBeChained = false,
			MovementMultiplier = 0.4,
		},
	},

	Moveset = {
		LightCombo = {
			Attacks = { "Light1", "Light2", "Light3" },
			LoopsTo = "Light1",
		},
		HeavyCombo = {
			Attacks = { "Heavy1", "Heavy2" },
		},
	},

	TwoHandingChanges = {
		DamgeBonus = 1.1,
	},
}

return StraightSword_Standard
