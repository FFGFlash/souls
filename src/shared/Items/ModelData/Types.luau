-- ===========================
-- ATTACHMENT TYPES
-- ===========================

export type AttachmentPoint =
	| "RightHand"
	| "LeftHand"
	| "RightGrip" -- For weapons that use tool grip
	| "Back" -- Weapon sheathed on back
	| "Hip" -- Weapon sheathed on hip
	| "LeftHip"
	| "RightHip"
	| "Chest" -- For armor
	| "Head" -- For helmets
	| "Waist" -- For belts

export type AttachmentConfig = {
	-- Which attachment point on character rig
	Point: AttachmentPoint,

	-- Offset from attachment point
	Offset: CFrame,

	-- Scale (if different from default)
	Scale: number?,
}

export type SheathedConfig = {
	-- Where item is attached when not in use
	Point: AttachmentPoint,
	Offset: CFrame,

	-- Different model when sheathed? (optional)
	AlternativeModel: string?,
}

-- ===========================
-- VISUAL EFFECT TYPES
-- ===========================

export type VFXProfile = {
	-- Particle effects
	ParticleEmitters: {
		{
			AttachTo: string, -- Attachment name on weapon model
			EmitterId: string, -- Reference to particle config
			Enabled: boolean, -- Always on or trigger-based
		}
	}?,

	-- Trail effects (for swings)
	Trails: {
		{
			Attachment0: string, -- Start point (e.g., "Base")
			Attachment1: string, -- End point (e.g., "Tip")
			TrailId: string, -- Reference to trail config
		}
	}?,

	-- Glow/highlight effects
	SurfaceEffects: {
		{
			SurfaceType: "Neon" | "ForceField" | "Outline",
			Color: Color3?,
			Transparency: number?,
			Parts: { string }?, -- Which parts of model (nil = all)
		}
	}?,

	-- Beam effects (magical weapons)
	Beams: {
		{
			Attachment0: string,
			Attachment1: string,
			BeamId: string,
		}
	}?,
}

-- ===========================
-- SOUND TYPES
-- ===========================

export type SoundProfile = {
	-- Equipment sounds
	Equip: string?, -- Sound when equipping
	Unequip: string?, -- Sound when unequipping
	Sheath: string?, -- Sound when sheathing
	Unsheath: string?, -- Sound when drawing weapon

	-- Combat sounds
	Swing: { string }?, -- Array of swing sounds (randomly chosen)
	Hit: { string }?, -- Hit sounds
	Block: { string }?, -- Block sounds
	Parry: string?, -- Parry sound

	-- Special sounds
	WeaponArt: string?, -- Weapon art activation sound
	Break: string?, -- Weapon breaking sound (durability system)

	-- Ambient sounds
	Idle: string?, -- Looping sound when equipped (humming blade, etc.)
}

export type SoundConfig = {
	Id: string, -- Sound asset ID
	Volume: number?,
	Pitch: number?,
	PitchVariation: number?, -- Random pitch variance (0.1 = ±10%)
	RollOffMinDistance: number?,
	RollOffMaxDistance: number?,
}

-- ===========================
-- MODEL DATA TYPE
-- ===========================

export type ModelData = {
	-- ID must match ModelDataId in item definition
	Id: string,

	-- Model reference
	Model: string | Instance, -- AssetId or path to model in ReplicatedStorage

	-- Attachment configuration
	Equipped: AttachmentConfig,
	Sheathed: SheathedConfig?,

	-- Visual effects
	VFX: VFXProfile?,

	-- Sound effects
	Sounds: SoundProfile?,

	-- Special rendering
	RenderDistance: number?, -- Max distance at which model is rendered
	CastShadow: boolean?, -- Whether model casts shadows

	-- Animation-specific attachments
	-- These are attachment points on the weapon model itself for hitbox detection
	Attachments: {
		[string]: CFrame, -- e.g., "Tip", "Middle", "Base", "Guard"
	}?,

	-- Material properties
	MaterialOverrides: {
		[string]: Enum.Material, -- Part name -> material
	}?,

	-- Color customization
	ColorChannels: {
		Primary: Color3?,
		Secondary: Color3?,
		Accent: Color3?,
	}?,

	-- Level of detail (LOD) models
	LODs: {
		{
			Distance: number, -- Distance threshold
			Model: string | Instance,
		}
	}?,
}

-- ===========================
-- ARMOR MODEL DATA TYPE
-- ===========================

export type ArmorModelData = {
	Id: string,

	-- Armor pieces (can replace character parts)
	Parts: {
		[string]: { -- Part name (e.g., "Head", "Torso", "LeftArm")
			Model: string | Instance,
			ReplacesCharacterPart: boolean, -- Hides character's part
			AttachmentOffset: CFrame?,
		},
	},

	-- Accessories (additional decorative parts)
	Accessories: {
		{
			Model: string | Instance,
			AttachTo: AttachmentPoint,
			Offset: CFrame,
		}
	}?,

	-- Visual effects
	VFX: VFXProfile?,

	-- Set visual (when full set is worn)
	SetVFX: VFXProfile?,

	-- Material properties
	MaterialOverrides: {
		[string]: Enum.Material,
	}?,

	-- Color customization
	ColorChannels: {
		Primary: Color3?,
		Secondary: Color3?,
		Accent: Color3?,
	}?,
}

-- ===========================
-- EXAMPLE USAGE
-- ===========================

--[[
local ShortswordModel: ModelData = {
	Id = "Shortsword_Default",
	Model = "rbxassetid://12345",
	
	Equipped = {
		Point = "RightHand",
		Offset = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
	},
	
	Sheathed = {
		Point = "LeftHip",
		Offset = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-45), 0, 0),
	},
	
	VFX = {
		Trails = {
			{
				Attachment0 = "Base",
				Attachment1 = "Tip",
				TrailId = "SwordTrail_Standard",
			}
		},
	},
	
	Sounds = {
		Equip = "rbxassetid://111",
		Unequip = "rbxassetid://222",
		Swing = {
			"rbxassetid://333",
			"rbxassetid://444",
			"rbxassetid://555",
		},
		Hit = {
			"rbxassetid://666",
			"rbxassetid://777",
		},
	},
	
	Attachments = {
		Tip = CFrame.new(0, 0, 2),
		Middle = CFrame.new(0, 0, 1),
		Base = CFrame.new(0, 0, 0),
		Guard = CFrame.new(0, 0, 0.2),
	},
	
	ColorChannels = {
		Primary = Color3.fromRGB(128, 128, 128), -- Blade
		Secondary = Color3.fromRGB(101, 67, 33), -- Handle
		Accent = Color3.fromRGB(255, 215, 0), -- Guard
	},
}
]]

return nil
