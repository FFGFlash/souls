-- ===========================
-- BASE TYPES
-- ===========================

export type BaseAssetData = {
	Id: string,
}

-- ===========================
-- MODEL DATA TYPE
-- ===========================

export type ModelAssetData = {
	Type: "Model",
	Models: { { Level: number, Equipped: { Accessory }, Sheated: { Accessory }? } },
	Attributes: {
		[string]: Color3 | Vector3 | BrickColor | string | boolean | number | UDim | UDim2 | Vector2 | CFrame,
	},
} & BaseAssetData

-- ===========================
-- AUDIO DATA TYPE
-- ===========================

export type SoundConfig = {
	Id: string, -- Id for this sound effect
	AssetId: string, -- Sound asset ID
	Volume: number?,
	Pitch: number?,
	PitchVariation: number?, -- Random pitch variance (0.1 = ±10%)
	RollOffMinDistance: number?,
	RollOffMaxDistance: number?,
}

export type AudioAssetData = {
	Type: "audio",
	-- Multiple sounds to be played at random. Ex. Footstep1, Footstep2, Footstep3
	Sounds: { SoundConfig },
} & BaseAssetData

-- ===========================
-- EFFECT DATA TYPE
-- ===========================

export type EffectAssetData = {
	Type: "effect",
	Model: PVInstance,
} & BaseAssetData

-- ===========================
-- UNION TYPE
-- ===========================

export type AssetData = ModelAssetData | AudioAssetData | EffectAssetData

return nil
