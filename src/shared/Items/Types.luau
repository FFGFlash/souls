-- ===========================
-- BASE TYPES
-- ===========================

export type Base = {
	Id: string,
	Name: string,
	Description: string,
	BuyPrice: number?,
	SellPrice: number?,
	Weight: number?,
	MaxStack: number?,
	Rarity: Rarity?,

	--[[
    Reference to item model
  ]]
	ModelDataId: string?,
}

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "unique"

-- ===========================
-- STAT & SCALING TYPES
-- ===========================

export type ScalingGrade = "E" | "D" | "C" | "B" | "A" | "S"

export type StatRequirements = {
	Strength: number?,
	Dexterity: number?,
	Intelligence: number?,
	Faith: number?,
	Vitality: number?,
	Endurance: number?,
}

export type StatScaling = {
	Strength: ScalingGrade?,
	Dexterity: ScalingGrade?,
	Intelligence: ScalingGrade?,
	Faith: ScalingGrade?,
	Vitality: ScalingGrade?,
	Endurance: ScalingGrade?,
}

export type DamageTypes = {
	Physical: number?,
	Fire: number?,
	Lightning: number?,
	Magic: number?,
	Dark: number?,
	Bleed: number?,
	Poison: number?,
}

export type DefenseTypes = {
	Physical: number?,
	Fire: number?,
	Lightning: number?,
	Magic: number?,
	Dark: number?,
	Poise: number?,
	BleedResist: number?,
	PoisonResist: number?,
}

-- ===========================
-- EQUIPMENT SLOT TYPES
-- ===========================

export type SlotConfig = {
	--[[
    Prevents other slots from being used when this item is equiped
  ]]
	LockSlots: { [number]: boolean }?,
}

export type Equippable = {
	--[[
    Which slots this item can be equipped to
  ]]
	Slots: { [number]: SlotConfig | boolean },

	--[[
    Stats required to equip item
  ]]
	Requirements: StatRequirements?,
	--[[
    Stat Scaling
  ]]
	Scaling: StatScaling?,

	--[[
    Used to identify items in a set
  ]]
	SetId: string?,

	--[[
    Whether the item can be unequipped or not
  ]]
	Cursed: boolean?,
} & Base

-- ===========================
-- WEAPON TYPES
-- ===========================

export type WeaponCategory =
	| "dagger"
	| "straight_sword"
	| "greatsword"
	| "ultra_greatsword"
	| "curved_sword"
	| "katana"
	| "axe"
	| "greataxe"
	| "hammer"
	| "great_hammer"
	| "spear"
	| "halberd"
	| "whip"
	| "fist"
	| "bow"
	| "crossbow"
	| "staff"
	| "catalyst"
	| "round_shield"
	| "greatshield"

export type WeaponData = {
	Type: "weapon",
	Category: WeaponCategory,

	Damage: DamageTypes,
	AttackSpeed: number,
	CriticalRate: number?,
	CriticalMultiplier: number?,

	-- StaminaCost: {
	-- 	Light: number,
	-- 	Heavy: number,
	-- 	Block: number?,
	-- 	Parry: number?,
	-- 	WeaponArt: number?,
	-- },

	TwoHanded: boolean?,
	TwoHandedMultiplier: number?,

	Poise: number?,
	Stability: number?,

	GuardAbsorption: DefenseTypes?,

	MaxDurability: number?,

	CombatDataId: string,

	ModelDataId: string,
} & Equippable

-- ===========================
-- ARMOR TYPES
-- ===========================

export type ArmorCategory = "helmet" | "chest" | "gauntlets" | "leggings"

export type ArmorData = {
	Type: "armor",
	Category: ArmorCategory,

	-- Defense Stats
	Defense: DefenseTypes,

	-- Reference to visual module
	ModelDataId: string,
} & Equippable

-- ===========================
-- ACCESSORY TYPES
-- ===========================

export type AccessoryCategory = "ring" | "amulet" | "charm"

export type AccessoryEffect = {
	Type: "stat_bonus" | "damage_bonus" | "defense_bonus" | "special",
	Target: string,
	Multiplier: number?,
	Additive: number?,
}

export type AccessoryData = {
	Type: "accessory",
	Category: AccessoryCategory,
	Effects: { AccessoryEffect },
} & Equippable

-- ===========================
-- CONSUMABLE TYPES
-- ===========================

export type ConsumableEffect =
	| "heal"
	| "restore_stamina"
	| "cure_poison"
	| "cure_bleed"
	| "buff_damage"
	| "buff_defense"
	| "buff_stamina_regen"

export type ConsumableData = {
	Type: "consumable",

	Effect: ConsumableEffect,
	Amount: number,
	Duration: number?,

	UseDuration: number,
	Cooldown: number?,

	UseAnimationId: string?,
	VFXProfile: string?,
} & Base

-- ===========================
-- MATERIAL TYPES
-- ===========================

export type MaterialCategory = "ore" | "wood" | "herb" | "essence" | "gem" | "bone" | "hide"

export type MaterialData = {
	Type: "material",
	Category: MaterialCategory,

	Tier: number,
} & Base

-- ===========================
-- KEY ITEM TYPES
-- ===========================

export type KeyItemData = {
	Type: "key_item",

	Unique: boolean,
	QuestRelated: boolean?,
} & Base

-- ===========================
-- MISC TYPES
-- ===========================

export type MiscData = {
	Type: "misc",
} & Base

-- ===========================
-- UNION TYPE
-- ===========================

export type Item = WeaponData | ArmorData | AccessoryData | ConsumableData | MaterialData | KeyItemData | MiscData

return nil
