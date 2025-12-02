local Constants = {}

Constants.ASSET_FOLDER_NAME = "BrushToolAssets"
Constants.WORKSPACE_FOLDER_NAME = "BrushToolCreations"
Constants.SETTINGS_KEY = "BrushToolAssetOffsets_v5"
Constants.PRESETS_KEY = "BrushToolPresets_v1"

-- Modern Minimalist Theme (Sleek & Soft)
Constants.Theme = {
	-- Base Colors (Soft Dark)
	Background = Color3.fromHex("18181B"),      -- Zinc-900: Deep, soft dark
	Panel = Color3.fromHex("27272A"),           -- Zinc-800: Soft panel background
	PanelHover = Color3.fromHex("3F3F46"),      -- Zinc-700: Lighter interactive state
	Border = Color3.fromHex("3F3F46"),          -- Zinc-700: Subtle borders

	-- Text Colors
	Text = Color3.fromHex("F4F4F5"),            -- Zinc-100: High contrast text
	TextDim = Color3.fromHex("A1A1AA"),         -- Zinc-400: Muted text

	-- Accents (Vibrant but Soft)
	Accent = Color3.fromHex("2DD4BF"),          -- Teal-400: Minty modern accent
	AccentHover = Color3.fromHex("5EEAD4"),     -- Teal-300: Lighter mint

	-- Status Colors (Pastel/Soft)
	Warning = Color3.fromHex("FBBF24"),         -- Amber-400
	Destructive = Color3.fromHex("F87171"),     -- Red-400
	Success = Color3.fromHex("34D399"),         -- Emerald-400

	-- Fonts (Geometric & Clean)
	FontMain = Enum.Font.GothamMedium,
	FontHeader = Enum.Font.GothamBold,
	FontTech = Enum.Font.Gotham,                -- Unified font family
}

return Constants
