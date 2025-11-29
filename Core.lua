local State = {}
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

-- Dependencies (Passed via init)
local Constants
local pluginInstance

-- Data
State.assetOffsets = {}
State.presets = {}
State.currentMode = "Paint"
State.active = false
State.mouse = nil
State.isPainting = false
State.lastPaintPosition = nil
State.lineStartPoint = nil
State.pathPoints = {}
State.partToFill = nil
State.sourceAsset = nil
State.targetAsset = nil
State.eraseFilter = {}
State.selectedAssetInUI = nil
State.surfaceAngleMode = "Off"
State.snapToGridEnabled = false
State.gridSize = 4
State.smartSnapEnabled = false
State.currentAssetGroup = "Default"
State.isGroupListView = false
State.ghostTransparency = 0.65
State.alignToSurface = false

-- Material Filter State
State.MaterialFilter = {
	Enabled = false,
	Whitelist = {}
}

-- Slope Filter State
State.SlopeFilter = {
	Enabled = false,
	MinAngle = 0,
	MaxAngle = 45
}

-- Height Filter State
State.HeightFilter = {
	Enabled = false,
	MinHeight = -500,
	MaxHeight = 500
}

-- Physics Drop State
State.PhysicsDrop = {
	Enabled = false,
	Duration = 1.0
}

-- Smart Eraser/Replacer State
State.SmartEraser = {
	FilterMode = "All" -- "All" or "CurrentGroup"
}

-- Preview Objects (Will be set by Core)
State.previewPart = nil
State.cyl = nil
State.linePreviewPart = nil
State.fillSelectionBox = nil
State.ghostModel = nil

-- Folders
State.assetsFolder = nil
State.previewFolder = nil
State.pathPreviewFolder = nil

-- Randomizer States
State.Randomizer = {
	Scale = { Enabled = false },
	Rotation = { Enabled = false },
	Color = { Enabled = false },
	Transparency = { Enabled = false }
}

State.Wobble = { Enabled = false }

-- Next Stamp State
State.nextStampAsset = nil
State.nextStampScale = nil
State.nextStampRotation = nil
State.nextStampWobble = nil

function State.init(pPlugin, pConstants)
	pluginInstance = pPlugin
	Constants = pConstants

	-- Ensure assets folder exists
	State.assetsFolder = ServerStorage:FindFirstChild(Constants.ASSET_FOLDER_NAME)
	if not State.assetsFolder then
		State.assetsFolder = Instance.new("Folder")
		State.assetsFolder.Name = Constants.ASSET_FOLDER_NAME
		State.assetsFolder.Parent = ServerStorage
	end

	-- Ensure Default group exists
	if not State.assetsFolder:FindFirstChild("Default") then
		local defaultGroup = Instance.new("Folder")
		defaultGroup.Name = "Default"
		defaultGroup.Parent = State.assetsFolder
	end

	-- Global Preview Folders
	State.previewFolder = workspace:FindFirstChild("_BrushPreview") or Instance.new("Folder", workspace)
	State.previewFolder.Name = "_BrushPreview"

	State.pathPreviewFolder = workspace:FindFirstChild("_PathPreview") or Instance.new("Folder", workspace)
	State.pathPreviewFolder.Name = "_PathPreview"

	State.currentMode = "Paint" -- Ensure default mode is Paint explicitly on init

	State.loadOffsets()
	State.loadPresetsFromStorage()
end

function State.loadOffsets()
	local jsonString = pluginInstance:GetSetting(Constants.SETTINGS_KEY)
	if jsonString and #jsonString > 0 then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, jsonString)
		if ok and type(data) == "table" then State.assetOffsets = data else State.assetOffsets = {} end
	else State.assetOffsets = {} end
end

function State.persistOffsets()
	local ok, jsonString = pcall(HttpService.JSONEncode, HttpService, State.assetOffsets)
	if ok then pluginInstance:SetSetting(Constants.SETTINGS_KEY, jsonString) end
end

function State.loadPresetsFromStorage()
	local jsonString = pluginInstance:GetSetting(Constants.PRESETS_KEY)
	if jsonString and #jsonString > 0 then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, jsonString)
		if ok and type(data) == "table" then State.presets = data else State.presets = {} end
	else State.presets = {} end
end

function State.savePresetsToStorage()
	local ok, jsonString = pcall(HttpService.JSONEncode, HttpService, State.presets)
	if ok then pluginInstance:SetSetting(Constants.PRESETS_KEY, jsonString) end
end

return State
