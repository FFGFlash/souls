local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShapecastHitbox = require(ReplicatedStorage.Packages.ShapecastHitbox)

-- ===========================
-- HITBOX TYPES
-- ===========================

export type HitboxConfig = {
	-- Hitbox Cast Data (For ShapecastHitbox)
	CastData: ShapecastHitbox.CastData,

	-- Positioning relative to attachment point
	AttachmentName: string, -- Which attachment on the weapon model ("Tip", "Middle", "Base")

	-- Timing
	StartFrame: number, -- When hitbox becomes active (in frames at 60fps)
	EndFrame: number, -- When hitbox becomes inactive

	-- Hit properties
	MaxHits: number?, -- Max enemies hit before hitbox deactivates (nil = infinite)
	HitSameTargetAgain: boolean?, -- Can hit the same enemy multiple times in one attack

	-- Launch/knockback
	LaunchPower: number?, -- How much force to apply to hit enemies
	LaunchDirection: "away" | "forward" | "up" | "down"?, -- Direction relative to attacker

	-- Special properties
	IgnoreIFrames: boolean?, -- Ignores invincibility frames
	PierceBlocking: boolean?, -- Can hit through blocking
}

-- ===========================
-- ATTACK TYPES
-- ===========================

export type AttackType = "light" | "heavy" | "running" | "rolling" | "jumping" | "backstab" | "riposte" | "weapon_art"

export type AttackData = {
	-- Animation
	AnimationId: string,
	AnimationSpeed: number?, -- Multiplier (default 1.0)

	-- Timing (in seconds)
	WindupTime: number, -- Time before hitbox becomes active
	RecoveryTime: number, -- Time after attack before can act again

	-- Hitboxes (can have multiple for complex attacks)
	Hitboxes: { HitboxConfig },

	-- Damage modifiers
	DamageMultiplier: number, -- Multiplied with weapon base damage
	StaminaCostOverride: number?, -- Override weapon's base stamina cost

	-- Combo properties
	CanBeChained: boolean, -- Can chain into next attack in combo
	ChainWindow: number?, -- Time window (seconds) to input next attack for combo
	NextAttacks: { string }?, -- Which attacks can follow this one

	-- Movement properties
	MovementMultiplier: number?, -- Movement speed during attack (0 = locked, 1 = normal)
	ForwardMovement: number?, -- Forward momentum applied (studs)

	-- Cancel windows
	CanBeCanceled: boolean?, -- Can be canceled with roll/block
	CancelWindow: number?, -- When canceling becomes available (seconds from attack start)

	-- Special flags
	IsGuardBreak: boolean?, -- Breaks through blocks
	IsUnblockable: boolean?, -- Can't be blocked at all
	HasHyperArmor: boolean?, -- Can't be interrupted during attack
	HyperArmorStartTime: number?, -- When hyper armor begins (seconds)
	HyperArmorEndTime: number?, -- When hyper armor ends (seconds)
}

-- ===========================
-- COMBO TYPES
-- ===========================

export type ComboChain = {
	-- Sequence of attacks
	Attacks: { string }, -- Attack IDs in order

	-- Branching (optional)
	Branches: {
		[string]: { -- From this attack
			Light: string?, -- Light attack branches to this
			Heavy: string?, -- Heavy attack branches to this
		},
	}?,

	-- Loop behavior
	LoopsTo: string?, -- After last attack, loops to this attack ID
}

-- ===========================
-- WEAPON MOVESET TYPES
-- ===========================

export type WeaponMoveset = {
	-- Basic attacks
	LightCombo: ComboChain,
	HeavyCombo: ComboChain?,

	-- Conditional attacks
	RollingAttack: AttackData?,
	BackstabAttack: AttackData?,

	-- Guard
	BlockAnimation: string?,
	ParryAnimation: string?,
	ParryWindow: number?, -- Parry active frames (seconds)

	-- Weapon Art
	WeaponArt: {
		Name: string,
		Description: string,
		Attack: AttackData,
		FPCost: number?, -- Focus points / mana cost
	}?,

	-- Two-handing modifications
	TwoHandingChanges: {
		DamageBonus: number?, -- Damage multiplier when two-handing
		StaminaReduction: number?, -- Stamina cost reduction (0.1 = 10% less)
		AlternativeMoveset: WeaponMoveset?, -- Completely different moveset when two-handing
	}?,
}

-- ===========================
-- COMBAT DATA TYPE
-- ===========================

export type CombatData = {
	-- ID must match CombatDataId in weapon definition
	Id: string,

	-- All attacks defined for this weapon
	Attacks: { [string]: AttackData }, -- Key = attack ID (e.g., "Light1", "Heavy2")

	-- Moveset configuration
	Moveset: WeaponMoveset,

	-- Hit effects
	HitVFXProfile: string?, -- VFX to spawn on hit (sparks, blood, etc.)
	HitSoundProfile: string?, -- Sound to play on hit

	-- Swing effects
	SwingVFXProfile: string?, -- Trail VFX during swing
	SwingSoundProfile: string?, -- Whoosh sound during swing
}

-- ===========================
-- EXAMPLE USAGE
-- ===========================

--[[
local StraightSwordCombat: CombatData = {
	Id = "StraightSword_Standard",
	
	Attacks = {
		Light1 = {
			AnimationId = "rbxassetid://123",
			AnimationSpeed = 1.0,
			WindupTime = 0.2,
			RecoveryTime = 0.4,
			DamageMultiplier = 1.0,
			Hitboxes = {
				{
          CastData = { CastType = "Blockcast", CFrame = CFrame.new(0, 0, 2), Size = Vector3.new(1, 1, 4) },
          Attachment = "Blade",
					StartFrame = 12,
					EndFrame = 18,
					MaxHits = 5,
					LaunchPower = 5,
					LaunchDirection = "away",
				}
			},
			CanBeChained = true,
			ChainWindow = 0.3,
			NextAttacks = { "Light2" },
			MovementMultiplier = 0.5,
		},
		-- ... more attacks
	},
	
	Moveset = {
		LightCombo = {
			Attacks = { "Light1", "Light2", "Light3" },
			LoopsTo = "Light1",
		},
		HeavyCombo = {
			Attacks = { "Heavy1", "Heavy2" },
		},
		RunningAttack = { --[=[ AttackData ]=] },
	},
}
]]

return nil
