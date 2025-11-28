--[[
	Brush Tool Plugin for Roblox Studio - "Cyber-Industrial" Edition (V8)
	
	Features:
	- Complete UI Overhaul: Tabbed Interface, Dark/Industrial Theme.
	- Robust Logic Restored: Physics, Path Splines, Volume Painting, Masking.
	- Enhanced UX: Hover states, clear active indicators, organized settings.
	- Fully Interactive: All buttons and inputs connected with persistence.
]]

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

-- Constants
local ASSET_FOLDER_NAME = "BrushToolAssets"
local WORKSPACE_FOLDER_NAME = "BrushToolCreations"
local SETTINGS_KEY = "BrushToolAssetOffsets_v5"
local PRESETS_KEY = "BrushToolPresets_v1"

-- Ensure assets folder exists
local assetsFolder = ServerStorage:FindFirstChild(ASSET_FOLDER_NAME)
if not assetsFolder then
	assetsFolder = Instance.new("Folder")
	assetsFolder.Name = ASSET_FOLDER_NAME
	assetsFolder.Parent = ServerStorage
end

-- State Variables
local assetOffsets = {}
local presets = {}
local currentMode = "Paint"
local active = false
local mouse = nil
local moveConn, downConn, upConn
local previewPart, cyl
local isPainting = false
local lastPaintPosition = nil
local lineStartPoint = nil
local linePreviewPart = nil
local pathPoints = {}
local pathPreviewFolder = nil
local partToFill = nil
local fillSelectionBox = nil
local sourceAsset = nil
local targetAsset = nil
local eraseFilter = {}
local selectedAssetInUI = nil
local previewFolder = nil
local surfaceAngleMode = "Off"
local snapToGridEnabled = false
local gridSize = 4
local smartSnapEnabled = false
local currentAssetGroup = "Default"
local isGroupListView = false
local ghostModel = nil
local ghostTransparency = 0.65
local nextStampAsset = nil
local nextStampScale = nil
local nextStampRotation = nil

-- Global Preview Folders
previewFolder = workspace:FindFirstChild("_BrushPreview") or Instance.new("Folder", workspace); previewFolder.Name = "_BrushPreview"
pathPreviewFolder = workspace:FindFirstChild("_PathPreview") or Instance.new("Folder", workspace); pathPreviewFolder.Name = "_PathPreview"

-- Transformation Randomizer States
local randomizeScaleEnabled = false
local randomizeRotationEnabled = false
local randomizeColorEnabled = false
local randomizeTransparencyEnabled = false

-- Forward Declarations
local updateAssetUIList
local updateFillSelection = nil
local updateGhostPreview
local clearPath
local updatePathPreview
local catmullRom
local placeAsset
local getRandomWeightedAsset
local getWorkspaceContainer
local parseNumber
local paintAlongPath
local persistOffsets
local loadOffsets
local updatePreview
local paintAt
local scaleModel
local randomizeProperties
local findSurfacePositionAndNormal
local paintInVolume
local stampAt
local eraseAt
local paintAlongLine
local fillArea
local replaceAt
local trim
local activate
local deactivate
local setMode
local updateModeButtonsUI
local updateAllToggles
local addSelectedAssets
local clearAssetList
local randomPointInCircle
local updateGroupUI
local migrateAssetsToGroup
local savePresetsToStorage
local loadPresetsFromStorage
local updatePresetUIList
local captureCurrentState
local applyPresetState

--[[
    VISUAL THEME: CYBER-INDUSTRIAL
]]
local Theme = {
	Background = Color3.fromHex("121214"),
	Panel = Color3.fromHex("1E1E24"),
	Border = Color3.fromHex("383842"),
	BorderActive = Color3.fromHex("00A8FF"),
	Text = Color3.fromHex("E0E0E0"),
	TextDim = Color3.fromHex("808080"),
	Accent = Color3.fromHex("00A8FF"),
	AccentHover = Color3.fromHex("33BFFF"),
	Warning = Color3.fromHex("FFB302"),
	Destructive = Color3.fromHex("FF2A6D"),
	Success = Color3.fromHex("05FFA1"),
	FontMain = Enum.Font.GothamMedium,
	FontHeader = Enum.Font.GothamBold,
	FontTech = Enum.Font.Code,
}

-- UI Components Storage
local C = {}
local allTabs = {}

-- UI Helper Functions
local function createTechFrame(parent, size)
	local f = Instance.new("Frame")
	f.Size = size
	f.BackgroundColor3 = Theme.Panel
	f.BorderSizePixel = 0
	f.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Border
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	return f, stroke
end

local function createTechButton(text, parent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Theme.Panel
	btn.Text = text
	btn.TextColor3 = Theme.Text
	btn.Font = Theme.FontMain
	btn.TextSize = 14
	btn.AutoButtonColor = false
	btn.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Border
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	btn.MouseEnter:Connect(function()
		if not btn.Active then return end
		stroke.Color = Theme.Accent
		btn.TextColor3 = Theme.Accent
	end)
	btn.MouseLeave:Connect(function()
		if not btn.Active then return end
		stroke.Color = Theme.Border
		btn.TextColor3 = Theme.Text
	end)
	return btn, stroke
end

local function createTechToggle(text, parent)
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 32)
	container.Parent = parent

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 24, 0, 24)
	btn.Position = UDim2.new(0, 0, 0.5, -12)
	btn.BackgroundColor3 = Theme.Background
	btn.Text = ""
	btn.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Border
	stroke.Thickness = 1
	stroke.Parent = btn

	local inner = Instance.new("Frame")
	inner.Size = UDim2.new(1, -6, 1, -6)
	inner.Position = UDim2.new(0, 3, 0, 3)
	inner.BackgroundColor3 = Theme.Accent
	inner.BorderSizePixel = 0
	inner.Visible = false
	inner.Parent = btn

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -32, 1, 0)
	label.Position = UDim2.new(0, 32, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Theme.FontMain
	label.TextSize = 13
	label.TextColor3 = Theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	return btn, inner, label
end

local function createTechInput(labelText, defaultValue, parent)
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 40)
	container.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.Font = Theme.FontMain
	label.TextSize = 12
	label.TextColor3 = Theme.TextDim
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, 0, 0, 22)
	inputBox.Position = UDim2.new(0, 0, 0, 18)
	inputBox.BackgroundColor3 = Theme.Background
	inputBox.Text = tostring(defaultValue)
	inputBox.TextColor3 = Theme.Accent
	inputBox.Font = Theme.FontTech
	inputBox.TextSize = 14
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.Parent = inputBox

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Border
	stroke.Parent = inputBox

	inputBox.Focused:Connect(function() stroke.Color = Theme.Accent end)
	inputBox.FocusLost:Connect(function() stroke.Color = Theme.Border end)

	return inputBox, container
end

local function createSectionHeader(text, parent)
	local h = Instance.new("TextLabel")
	h.Size = UDim2.new(1, 0, 0, 24)
	h.BackgroundTransparency = 1
	h.Text = "// " .. string.upper(text)
	h.Font = Theme.FontTech
	h.TextSize = 12
	h.TextColor3 = Theme.Warning
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.Parent = parent
	return h
end

-- Main Widget Setup
local toolbar = plugin:CreateToolbar("Brush Tool V8")
local toolbarBtn = toolbar:CreateButton("Brush", "Open Brush Tool", "rbxassetid://1507949203")

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, false, 400, 650, 350, 400
)
local widget = plugin:CreateDockWidgetPluginGui("BrushToolWidgetV8", widgetInfo)
widget.Title = "BRUSH TOOL // PROTOCOL"

local uiRoot = Instance.new("Frame")
uiRoot.Size = UDim2.new(1, 0, 1, 0)
uiRoot.BackgroundColor3 = Theme.Background
uiRoot.Parent = widget

-- Top Bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = Theme.Panel
topBar.BorderSizePixel = 0
topBar.Parent = uiRoot

local statusIndicator = Instance.new("Frame")
statusIndicator.Size = UDim2.new(0, 8, 0, 8)
statusIndicator.Position = UDim2.new(0, 12, 0.5, -4)
statusIndicator.BackgroundColor3 = Theme.Destructive
statusIndicator.Parent = topBar
Instance.new("UICorner", statusIndicator).CornerRadius = UDim.new(1, 0)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 1, 0)
titleLabel.Position = UDim2.new(0, 28, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SYSTEM: STANDBY"
titleLabel.Font = Theme.FontTech
titleLabel.TextSize = 14
titleLabel.TextColor3 = Theme.Text
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

C.activationBtn = Instance.new("TextButton")
C.activationBtn.Size = UDim2.new(0, 100, 0, 24)
C.activationBtn.AnchorPoint = Vector2.new(1, 0.5)
C.activationBtn.Position = UDim2.new(1, -12, 0.5, 0)
C.activationBtn.BackgroundColor3 = Theme.Background
C.activationBtn.Text = "ACTIVATE"
C.activationBtn.Font = Theme.FontHeader
C.activationBtn.TextSize = 11
C.activationBtn.TextColor3 = Theme.Text
C.activationBtn.Parent = topBar
Instance.new("UIStroke", C.activationBtn).Color = Theme.Border

-- Tabs
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 36)
tabBar.Position = UDim2.new(0, 0, 0, 40)
tabBar.BackgroundColor3 = Theme.Background
tabBar.BorderSizePixel = 0
tabBar.Parent = uiRoot

local tabBarLayout = Instance.new("UIListLayout")
tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
tabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabBarLayout.Parent = tabBar

local tabContent = Instance.new("Frame")
tabContent.Size = UDim2.new(1, 0, 1, -76)
tabContent.Position = UDim2.new(0, 0, 0, 76)
tabContent.BackgroundTransparency = 1
tabContent.Parent = uiRoot

local function switchTab(tabName)
	for _, t in pairs(allTabs) do
		if t.Name == tabName then
			t.Button.TextColor3 = Theme.Accent
			t.Indicator.Visible = true
			t.Frame.Visible = true
		else
			t.Button.TextColor3 = Theme.TextDim
			t.Indicator.Visible = false
			t.Frame.Visible = false
		end
	end
end

local function createTab(name, label)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.25, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = label
	btn.Font = Theme.FontHeader
	btn.TextSize = 12
	btn.TextColor3 = Theme.TextDim
	btn.Parent = tabBar
	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(1, -4, 0, 2)
	indicator.Position = UDim2.new(0, 2, 1, -2)
	indicator.BackgroundColor3 = Theme.Accent
	indicator.BorderSizePixel = 0
	indicator.Visible = false
	indicator.Parent = btn
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name .. "Frame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = Theme.Border
	frame.Visible = false
	frame.Parent = tabContent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = frame
	btn.MouseButton1Click:Connect(function() switchTab(name) end)
	table.insert(allTabs, {Name = name, Button = btn, Indicator = indicator, Frame = frame})
	return {frame = frame}
end

local TabTools = createTab("Tools", "OPERATIONS")
local TabAssets = createTab("Assets", "INVENTORY")
local TabPresets = createTab("Presets", "PRESETS")
local TabTuning = createTab("Tuning", "SYSTEM")

-- Tools Tab
createSectionHeader("MODE SELECT", TabTools.frame)
local modeGrid = Instance.new("Frame")
modeGrid.Size = UDim2.new(1, 0, 0, 100)
modeGrid.AutomaticSize = Enum.AutomaticSize.Y
modeGrid.BackgroundTransparency = 1
modeGrid.Parent = TabTools.frame
local mgLayout = Instance.new("UIGridLayout")
mgLayout.CellSize = UDim2.new(0.48, 0, 0, 36)
mgLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
mgLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mgLayout.Parent = modeGrid

C.modeButtons = {}
local modeNames = {"Paint", "Line", "Path", "Fill", "Replace", "Stamp", "Volume", "Erase"}
for _, m in ipairs(modeNames) do
	local b, s = createTechButton(string.upper(m), modeGrid)
	b.TextSize = 11
	C.modeButtons[m] = {Button = b, Stroke = s}
end

createSectionHeader("BRUSH PARAMETERS", TabTools.frame)
local brushParamsContainer = Instance.new("Frame")
brushParamsContainer.Size = UDim2.new(1, 0, 0, 100)
brushParamsContainer.AutomaticSize = Enum.AutomaticSize.Y
brushParamsContainer.BackgroundTransparency = 1
brushParamsContainer.Parent = TabTools.frame
local bpLayout = Instance.new("UIGridLayout")
bpLayout.CellSize = UDim2.new(0.48, 0, 0, 40)
bpLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
bpLayout.Parent = brushParamsContainer

C.radiusBox = {createTechInput("RADIUS (Studs)", "10", brushParamsContainer)}
C.densityBox = {createTechInput("DENSITY (Count)", "10", brushParamsContainer)}
C.spacingBox = {createTechInput("SPACING (Studs)", "1.5", brushParamsContainer)}

C.contextContainer = Instance.new("Frame")
C.contextContainer.Size = UDim2.new(1, 0, 0, 20)
C.contextContainer.AutomaticSize = Enum.AutomaticSize.Y
C.contextContainer.BackgroundTransparency = 1
C.contextContainer.Parent = TabTools.frame

-- Path Context
C.pathFrame = Instance.new("Frame")
C.pathFrame.AutomaticSize = Enum.AutomaticSize.Y
C.pathFrame.Size = UDim2.new(1, 0, 0, 0)
C.pathFrame.BackgroundTransparency = 1
C.pathFrame.Visible = false
C.pathFrame.Parent = C.contextContainer
local pathLayout = Instance.new("UIListLayout", C.pathFrame)
pathLayout.Padding = UDim.new(0, 8)
pathLayout.SortOrder = Enum.SortOrder.LayoutOrder
local pathHeader = createSectionHeader("PATH SETTINGS", C.pathFrame)
pathHeader.LayoutOrder = 1
local pathBtnGrid = Instance.new("Frame")
pathBtnGrid.LayoutOrder = 2
pathBtnGrid.Size = UDim2.new(1, 0, 0, 32)
pathBtnGrid.BackgroundTransparency = 1
pathBtnGrid.Parent = C.pathFrame
local pgl = Instance.new("UIGridLayout")
pgl.CellSize = UDim2.new(0.48, 0, 0, 32)
pgl.CellPadding = UDim2.new(0.04, 0, 0, 0)
pgl.Parent = pathBtnGrid
C.applyPathBtn = {createTechButton("GENERATE", pathBtnGrid)}
C.clearPathBtn = {createTechButton("CLEAR", pathBtnGrid)}
C.clearPathBtn[1].TextColor3 = Theme.Destructive

-- Fill Context
C.fillFrame = Instance.new("Frame")
C.fillFrame.AutomaticSize = Enum.AutomaticSize.Y
C.fillFrame.Size = UDim2.new(1, 0, 0, 0)
C.fillFrame.BackgroundTransparency = 1
C.fillFrame.Visible = false
C.fillFrame.Parent = C.contextContainer
C.fillBtn = {createTechButton("SELECT TARGET VOLUME", C.fillFrame)}

-- Assets Tab
createSectionHeader("ASSET GROUPS", TabAssets.frame)
local groupActions = Instance.new("Frame")
groupActions.Size = UDim2.new(1, 0, 0, 32)
groupActions.BackgroundTransparency = 1
groupActions.Parent = TabAssets.frame
groupActions.ZIndex = 10
local gal = Instance.new("UIListLayout")
gal.FillDirection = Enum.FillDirection.Horizontal
gal.Parent = groupActions

C.groupNameLabel = {createTechButton("GROUP: DEFAULT", groupActions)}
C.groupNameLabel[1].Size = UDim2.new(1, 0, 1, 0)
C.groupNameLabel[1].AutoButtonColor = true

C.groupNameInput = Instance.new("TextBox")
C.groupNameInput.Size = UDim2.new(1, 0, 1, 0)
C.groupNameInput.BackgroundColor3 = Theme.Background
C.groupNameInput.TextColor3 = Theme.Accent
C.groupNameInput.Font = Theme.FontTech
C.groupNameInput.TextSize = 14
C.groupNameInput.Text = ""
C.groupNameInput.PlaceholderText = "ENTER NAME..."
C.groupNameInput.Visible = false
C.groupNameInput.Parent = groupActions
local inputStroke = Instance.new("UIStroke")
inputStroke.Color = Theme.Accent
inputStroke.Thickness = 1
inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
inputStroke.Parent = C.groupNameInput

local groupButtonsContainer = Instance.new("Frame")
groupButtonsContainer.Size = UDim2.new(1, 0, 0, 32)
groupButtonsContainer.BackgroundTransparency = 1
groupButtonsContainer.Parent = TabAssets.frame
local gbl = Instance.new("UIGridLayout")
gbl.CellSize = UDim2.new(0.5, -2, 1, 0)
gbl.CellPadding = UDim2.new(0, 4, 0, 0)
gbl.Parent = groupButtonsContainer

C.newGroupBtn = {createTechButton("ADD", groupButtonsContainer)}
C.newGroupBtn[1].Size = UDim2.new(1, 0, 1, 0)
C.newGroupBtn[1].TextColor3 = Theme.Success

C.deleteGroupBtn = {createTechButton("DEL", groupButtonsContainer)}
C.deleteGroupBtn[1].Size = UDim2.new(1, 0, 1, 0)
C.deleteGroupBtn[1].TextColor3 = Theme.Destructive

-- Dropdown container removed in favor of List View toggle

createSectionHeader("ASSET MANAGEMENT", TabAssets.frame)
local assetActions = Instance.new("Frame")
assetActions.Size = UDim2.new(1, 0, 0, 32)
assetActions.BackgroundTransparency = 1
assetActions.Parent = TabAssets.frame
local aal = Instance.new("UIListLayout")
aal.FillDirection = Enum.FillDirection.Horizontal
aal.Padding = UDim.new(0, 8)
aal.Parent = assetActions
C.addBtn = {createTechButton("+ ADD SELECTED", assetActions)}
C.addBtn[1].Size = UDim2.new(0.5, -4, 1, 0)
C.addBtn[1].TextColor3 = Theme.Success
C.clearBtn = {createTechButton("CLEAR ALL", assetActions)}
C.clearBtn[1].Size = UDim2.new(0.5, -4, 1, 0)
C.clearBtn[1].TextColor3 = Theme.Destructive

C.assetListFrame = Instance.new("Frame")
C.assetListFrame.Size = UDim2.new(1, 0, 0, 200)
C.assetListFrame.AutomaticSize = Enum.AutomaticSize.Y
C.assetListFrame.BackgroundTransparency = 1
C.assetListFrame.Parent = TabAssets.frame
local alGrid = Instance.new("UIGridLayout")
alGrid.CellSize = UDim2.new(0.48, 0, 0, 100)
alGrid.CellPadding = UDim2.new(0.03, 0, 0, 8)
alGrid.Parent = C.assetListFrame

C.assetSettingsFrame = Instance.new("Frame")
C.assetSettingsFrame.Size = UDim2.new(1, 0, 0, 150)
C.assetSettingsFrame.BackgroundTransparency = 1
C.assetSettingsFrame.Visible = false
C.assetSettingsFrame.Parent = TabAssets.frame
Instance.new("UIListLayout", C.assetSettingsFrame).Padding = UDim.new(0, 8)
local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, 0, 0, 1)
sep.BackgroundColor3 = Theme.Border
sep.BorderSizePixel = 0
sep.Parent = C.assetSettingsFrame
C.assetSettingsName = createSectionHeader("SELECTED: ???", C.assetSettingsFrame)
local asGrid = Instance.new("Frame")
asGrid.Size = UDim2.new(1, 0, 0, 80)
asGrid.BackgroundTransparency = 1
asGrid.Parent = C.assetSettingsFrame
local asgl = Instance.new("UIGridLayout")
asgl.CellSize = UDim2.new(0.48, 0, 0, 40)
asgl.CellPadding = UDim2.new(0.04, 0, 0, 8)
asgl.Parent = asGrid
C.assetSettingsOffsetY = {createTechInput("Y-OFFSET", "0", asGrid)}
C.assetSettingsWeight = {createTechInput("PROBABILITY", "1", asGrid)}
C.assetSettingsAlign = {createTechToggle("Align to Surface", C.assetSettingsFrame)}
C.assetSettingsActive = {createTechToggle("Active in Brush", C.assetSettingsFrame)}

-- Presets Tab
createSectionHeader("NEW PRESET", TabPresets.frame)
local presetCreationFrame = Instance.new("Frame")
presetCreationFrame.Size = UDim2.new(1, 0, 0, 80)
presetCreationFrame.BackgroundTransparency = 1
presetCreationFrame.Parent = TabPresets.frame
local pcl = Instance.new("UIListLayout")
pcl.Padding = UDim.new(0, 8)
pcl.Parent = presetCreationFrame

C.presetNameInput = {createTechInput("PRESET NAME", "", presetCreationFrame)}
C.savePresetBtn = {createTechButton("SAVE CURRENT CONFIG", presetCreationFrame)}
C.savePresetBtn[1].TextColor3 = Theme.Success

createSectionHeader("SAVED PROFILES", TabPresets.frame)
C.presetListFrame = Instance.new("Frame")
C.presetListFrame.Size = UDim2.new(1, 0, 0, 300)
C.presetListFrame.BackgroundTransparency = 1
C.presetListFrame.Parent = TabPresets.frame
local plGrid = Instance.new("UIGridLayout")
plGrid.CellSize = UDim2.new(1, 0, 0, 36)
plGrid.CellPadding = UDim2.new(0, 0, 0, 4)
plGrid.Parent = C.presetListFrame

-- Tuning Tab
local layoutOrderCounter = 1

local function createOrderedSectionHeader(text, parent)
	local h = createSectionHeader(text, parent)
	h.LayoutOrder = layoutOrderCounter
	layoutOrderCounter = layoutOrderCounter + 1
	return h
end

local function createOrderedRandomizerGroup(parent, toggleText)
	local container = Instance.new("Frame")
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Size = UDim2.new(1, 0, 0, 0)
	container.BackgroundTransparency = 1
	container.LayoutOrder = layoutOrderCounter
	container.Parent = parent
	layoutOrderCounter = layoutOrderCounter + 1

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = container

	local toggle = {createTechToggle(toggleText, container)}

	local grid = Instance.new("Frame")
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Size = UDim2.new(1,0,0,0)
	grid.BackgroundTransparency = 1
	grid.Parent = container

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.48, 0, 0, 40)
	gridLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	gridLayout.Parent = grid

	local randomizeBtn = {createTechButton("Randomize", container)}
	randomizeBtn[1].Size = UDim2.new(1, 0, 0, 28)
	randomizeBtn[1].TextSize = 12

	return toggle, grid, randomizeBtn
end

createOrderedSectionHeader("TRANSFORMATION RANDOMIZER", TabTuning.frame)

-- Scale
C.randomizeScaleToggle, C.scaleGrid, C.randomizeScaleBtn = createOrderedRandomizerGroup(TabTuning.frame, "Randomize Scale")
C.scaleMinBox = {createTechInput("SCALE MIN", "0.8", C.scaleGrid)}
C.scaleMaxBox = {createTechInput("SCALE MAX", "1.2", C.scaleGrid)}

-- Rotation
C.randomizeRotationToggle, C.rotationGrid, C.randomizeRotationBtn = createOrderedRandomizerGroup(TabTuning.frame, "Randomize Rotation (X/Z)")
C.rotXMinBox = {createTechInput("ROT X MIN", "0", C.rotationGrid)}
C.rotXMaxBox = {createTechInput("ROT X MAX", "0", C.rotationGrid)}
C.rotZMinBox = {createTechInput("ROT Z MIN", "0", C.rotationGrid)}
C.rotZMaxBox = {createTechInput("ROT Z MAX", "0", C.rotationGrid)}

-- Color
C.randomizeColorToggle, C.colorGrid, C.randomizeColorBtn = createOrderedRandomizerGroup(TabTuning.frame, "Randomize Color (HSV)")
C.hueMinBox = {createTechInput("HUE MIN", "0", C.colorGrid)}
C.hueMaxBox = {createTechInput("HUE MAX", "0", C.colorGrid)}
C.satMinBox = {createTechInput("SAT MIN", "0", C.colorGrid)}
C.satMaxBox = {createTechInput("SAT MAX", "0", C.colorGrid)}
C.valMinBox = {createTechInput("VAL MIN", "0", C.colorGrid)}
C.valMaxBox = {createTechInput("VAL MAX", "0", C.colorGrid)}

-- Transparency
C.randomizeTransparencyToggle, C.transparencyGrid, C.randomizeTransparencyBtn = createOrderedRandomizerGroup(TabTuning.frame, "Randomize Transparency")
C.transMinBox = {createTechInput("TRNS MIN", "0", C.transparencyGrid)}
C.transMaxBox = {createTechInput("TRNS MAX", "0", C.transparencyGrid)}

-- The global randomize button is now removed.

createOrderedSectionHeader("ENVIRONMENT CONTROL", TabTuning.frame)
C.smartSnapBtn = {createTechToggle("Smart Surface Snap", TabTuning.frame)}
C.smartSnapBtn[1].Parent.LayoutOrder = layoutOrderCounter; layoutOrderCounter = layoutOrderCounter + 1
C.snapToGridBtn = {createTechToggle("Snap to Grid", TabTuning.frame)}
C.snapToGridBtn[1].Parent.LayoutOrder = layoutOrderCounter; layoutOrderCounter = layoutOrderCounter + 1
C.gridSizeBox = {createTechInput("GRID SIZE", "4", TabTuning.frame)}
C.gridSizeBox[2].LayoutOrder = layoutOrderCounter; layoutOrderCounter = layoutOrderCounter + 1
C.ghostTransparencyBox = {createTechInput("GHOST TRANS", "0.65", TabTuning.frame)}
C.ghostTransparencyBox[2].LayoutOrder = layoutOrderCounter; layoutOrderCounter = layoutOrderCounter + 1


createOrderedSectionHeader("SURFACE LOCK", TabTuning.frame)
local surfaceGrid = Instance.new("Frame")
surfaceGrid.Size = UDim2.new(1, 0, 0, 80)
surfaceGrid.BackgroundTransparency = 1
surfaceGrid.Parent = TabTuning.frame
surfaceGrid.LayoutOrder = layoutOrderCounter; layoutOrderCounter = layoutOrderCounter + 1
local slLayout = Instance.new("UIGridLayout")
slLayout.CellSize = UDim2.new(0.48, 0, 0, 32)
slLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
slLayout.Parent = surfaceGrid

C.surfaceButtons = {}
local surfaceModes = {"Off", "Floor", "Wall", "Ceiling"}
for _, m in ipairs(surfaceModes) do
	local b, s = createTechButton(string.upper(m), surfaceGrid)
	C.surfaceButtons[m] = {Button = b, Stroke = s}
	b.MouseButton1Click:Connect(function()
		surfaceAngleMode = m
		updateAllToggles()
	end)
end


-- Switch Tab
switchTab("Tools")

-- ==========================================
-- LOGIC HELPERS & IMPLEMENTATION
-- ==========================================

savePresetsToStorage = function()
	local ok, jsonString = pcall(HttpService.JSONEncode, HttpService, presets)
	if ok then plugin:SetSetting(PRESETS_KEY, jsonString) end
end

loadPresetsFromStorage = function()
	local jsonString = plugin:GetSetting(PRESETS_KEY)
	if jsonString and #jsonString > 0 then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, jsonString)
		if ok and type(data) == "table" then presets = data else presets = {} end
	else presets = {} end
end

captureCurrentState = function()
	local state = {}

	-- Brush Params
	state.brush = {
		radius = parseNumber(C.radiusBox[1].Text, 10),
		density = parseNumber(C.densityBox[1].Text, 10),
		spacing = parseNumber(C.spacingBox[1].Text, 1.5)
	}

	-- Environment
	state.environment = {
		smartSnap = smartSnapEnabled,
		snapGrid = snapToGridEnabled,
		gridSize = gridSize,
		surfaceMode = surfaceAngleMode,
		ghostTransparency = ghostTransparency
	}

	-- Randomizers
	state.randomizer = {
		scale = {
			enabled = randomizeScaleEnabled,
			min = parseNumber(C.scaleMinBox[1].Text, 0.8),
			max = parseNumber(C.scaleMaxBox[1].Text, 1.2)
		},
		rotation = {
			enabled = randomizeRotationEnabled,
			xmin = parseNumber(C.rotXMinBox[1].Text, 0),
			xmax = parseNumber(C.rotXMaxBox[1].Text, 0),
			zmin = parseNumber(C.rotZMinBox[1].Text, 0),
			zmax = parseNumber(C.rotZMaxBox[1].Text, 0)
		},
		color = {
			enabled = randomizeColorEnabled,
			hmin = parseNumber(C.hueMinBox[1].Text, 0),
			hmax = parseNumber(C.hueMaxBox[1].Text, 0),
			smin = parseNumber(C.satMinBox[1].Text, 0),
			smax = parseNumber(C.satMaxBox[1].Text, 0),
			vmin = parseNumber(C.valMinBox[1].Text, 0),
			vmax = parseNumber(C.valMaxBox[1].Text, 0)
		},
		transparency = {
			enabled = randomizeTransparencyEnabled,
			tmin = parseNumber(C.transMinBox[1].Text, 0),
			tmax = parseNumber(C.transMaxBox[1].Text, 0)
		}
	}

	-- Assets (Current Group Only)
	state.assets = {}
	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if targetGroup then
		for _, asset in ipairs(targetGroup:GetChildren()) do
			state.assets[asset.Name] = {
				weight = assetOffsets[asset.Name .. "_weight"] or 1,
				offset = assetOffsets[asset.Name] or 0,
				active = (assetOffsets[asset.Name .. "_active"] ~= false),
				align = assetOffsets[asset.Name .. "_align"] or false
			}
		end
	end

	return state
end

applyPresetState = function(state)
	if not state then return end

	-- Apply Brush
	if state.brush then
		C.radiusBox[1].Text = tostring(state.brush.radius or 10)
		C.densityBox[1].Text = tostring(state.brush.density or 10)
		C.spacingBox[1].Text = tostring(state.brush.spacing or 1.5)
	end

	-- Apply Environment
	if state.environment then
		smartSnapEnabled = state.environment.smartSnap or false
		snapToGridEnabled = state.environment.snapGrid or false
		gridSize = state.environment.gridSize or 4
		C.gridSizeBox[1].Text = tostring(gridSize)
		surfaceAngleMode = state.environment.surfaceMode or "Off"
		ghostTransparency = state.environment.ghostTransparency or 0.65
		C.ghostTransparencyBox[1].Text = tostring(ghostTransparency)
	end

	-- Apply Randomizers
	if state.randomizer then
		local r = state.randomizer
		if r.scale then
			randomizeScaleEnabled = r.scale.enabled
			C.scaleMinBox[1].Text = tostring(r.scale.min or 0.8)
			C.scaleMaxBox[1].Text = tostring(r.scale.max or 1.2)
		end
		if r.rotation then
			randomizeRotationEnabled = r.rotation.enabled
			C.rotXMinBox[1].Text = tostring(r.rotation.xmin or 0)
			C.rotXMaxBox[1].Text = tostring(r.rotation.xmax or 0)
			C.rotZMinBox[1].Text = tostring(r.rotation.zmin or 0)
			C.rotZMaxBox[1].Text = tostring(r.rotation.zmax or 0)
		end
		if r.color then
			randomizeColorEnabled = r.color.enabled
			C.hueMinBox[1].Text = tostring(r.color.hmin or 0)
			C.hueMaxBox[1].Text = tostring(r.color.hmax or 0)
			C.satMinBox[1].Text = tostring(r.color.smin or 0)
			C.satMaxBox[1].Text = tostring(r.color.smax or 0)
			C.valMinBox[1].Text = tostring(r.color.vmin or 0)
			C.valMaxBox[1].Text = tostring(r.color.vmax or 0)
		end
		if r.transparency then
			randomizeTransparencyEnabled = r.transparency.enabled
			C.transMinBox[1].Text = tostring(r.transparency.tmin or 0)
			C.transMaxBox[1].Text = tostring(r.transparency.tmax or 0)
		end
	end

	-- Apply Assets
	if state.assets then
		for assetName, data in pairs(state.assets) do
			assetOffsets[assetName .. "_weight"] = data.weight
			assetOffsets[assetName] = data.offset
			assetOffsets[assetName .. "_active"] = data.active
			assetOffsets[assetName .. "_align"] = data.align
		end
	end

	persistOffsets()
	updateAllToggles()
	updateAssetUIList()
end

updatePresetUIList = function()
	for _, c in ipairs(C.presetListFrame:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end

	local sortedNames = {}
	for name, _ in pairs(presets) do table.insert(sortedNames, name) end
	table.sort(sortedNames)

	for _, name in ipairs(sortedNames) do
		local container = Instance.new("Frame")
		container.BackgroundTransparency = 1
		container.BackgroundColor3 = Theme.Panel
		container.Parent = C.presetListFrame

		local loadBtn = Instance.new("TextButton")
		loadBtn.Size = UDim2.new(1, -30, 1, 0)
		loadBtn.BackgroundColor3 = Theme.Panel
		loadBtn.Text = "  " .. name
		loadBtn.Font = Theme.FontTech
		loadBtn.TextSize = 12
		loadBtn.TextColor3 = Theme.Text
		loadBtn.TextXAlignment = Enum.TextXAlignment.Left
		loadBtn.AutoButtonColor = false
		loadBtn.Parent = container

		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Border
		stroke.Parent = loadBtn

		loadBtn.MouseEnter:Connect(function() stroke.Color = Theme.Accent; loadBtn.TextColor3 = Theme.Accent end)
		loadBtn.MouseLeave:Connect(function() stroke.Color = Theme.Border; loadBtn.TextColor3 = Theme.Text end)

		loadBtn.MouseButton1Click:Connect(function()
			applyPresetState(presets[name])
			print("Loaded Preset: " .. name)
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.new(0, 24, 1, 0)
		delBtn.Position = UDim2.new(1, -24, 0, 0)
		delBtn.BackgroundColor3 = Theme.Panel
		delBtn.Text = "X"
		delBtn.Font = Theme.FontMain
		delBtn.TextColor3 = Theme.Destructive
		delBtn.Parent = container
		local delStroke = Instance.new("UIStroke")
		delStroke.Color = Theme.Border
		delStroke.Parent = delBtn

		local isConfirm = false
		delBtn.MouseButton1Click:Connect(function()
			if not isConfirm then
				isConfirm = true
				delBtn.Text = "?"
				delBtn.BackgroundColor3 = Theme.Destructive
				delBtn.TextColor3 = Theme.Text
				task.delay(2, function()
					if isConfirm then
						isConfirm = false
						delBtn.Text = "X"
						delBtn.BackgroundColor3 = Theme.Panel
						delBtn.TextColor3 = Theme.Destructive
					end
				end)
			else
				presets[name] = nil
				savePresetsToStorage()
				updatePresetUIList()
			end
		end)
	end
end

trim = function(s)
	return s:match("^%s*(.-)%s*$") or s
end

parseNumber = function(txt, fallback)
	local ok, n = pcall(function() return tonumber(trim(txt)) end)
	if ok and n then return n end
	return fallback
end

loadOffsets = function()
	local jsonString = plugin:GetSetting(SETTINGS_KEY)
	if jsonString and #jsonString > 0 then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, jsonString)
		if ok and type(data) == "table" then assetOffsets = data else assetOffsets = {} end
	else assetOffsets = {} end
end

migrateAssetsToGroup = function()
	-- Check for legacy structure (assets directly under assetsFolder)
	local needsMigration = false
	for _, child in ipairs(assetsFolder:GetChildren()) do
		if not child:IsA("Folder") then
			needsMigration = true
			break
		end
	end

	if needsMigration then
		local defaultGroup = assetsFolder:FindFirstChild("Default")
		if not defaultGroup then
			defaultGroup = Instance.new("Folder")
			defaultGroup.Name = "Default"
			defaultGroup.Parent = assetsFolder
		end
		for _, child in ipairs(assetsFolder:GetChildren()) do
			if not child:IsA("Folder") then
				child.Parent = defaultGroup
			end
		end
	else
		-- Ensure at least Default group exists
		if #assetsFolder:GetChildren() == 0 then
			local defaultGroup = Instance.new("Folder")
			defaultGroup.Name = "Default"
			defaultGroup.Parent = assetsFolder
		end
	end
end

persistOffsets = function()
	local ok, jsonString = pcall(HttpService.JSONEncode, HttpService, assetOffsets)
	if ok then plugin:SetSetting(SETTINGS_KEY, jsonString) end
end

local function randFloat(a, b)
	return a + math.random() * (b - a)
end

randomPointInCircle = function(radius)
	local r = radius * math.sqrt(math.random())
	local theta = math.random() * 2 * math.pi
	return Vector3.new(r * math.cos(theta), 0, r * math.sin(theta))
end

local function getRandomPointInSphere(radius)
	local u = math.random()
	local v = math.random()
	local theta = u * 2 * math.pi
	local phi = math.acos(2 * v - 1)
	local r = math.pow(math.random(), 1/3) * radius
	return Vector3.new(r * math.sin(phi) * math.cos(theta), r * math.sin(phi) * math.sin(theta), r * math.cos(phi))
end

catmullRom = function(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

getWorkspaceContainer = function()
	local container = workspace:FindFirstChild(WORKSPACE_FOLDER_NAME)
	if not container or not container:IsA("Folder") then
		container = Instance.new("Folder")
		container.Name = WORKSPACE_FOLDER_NAME
		container.Parent = workspace
	end
	return container
end

getRandomWeightedAsset = function(assetList)
	local totalWeight = 0
	for _, asset in ipairs(assetList) do
		local weight = assetOffsets[asset.Name .. "_weight"] or 1
		totalWeight = totalWeight + weight
	end
	if totalWeight == 0 then return assetList[math.random(1, #assetList)] end
	local randomNum = math.random() * totalWeight
	local currentWeight = 0
	for _, asset in ipairs(assetList) do
		local weight = assetOffsets[asset.Name .. "_weight"] or 1
		currentWeight = currentWeight + weight
		if randomNum <= currentWeight then return asset end
	end
	return assetList[#assetList]
end

scaleModel = function(model, scale)
	local ok, bboxCFrame, bboxSize = pcall(function() return model:GetBoundingBox() end)
	if not ok then return end
	local center = bboxCFrame.Position
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local rel = d.Position - center
			d.Size = d.Size * scale
			d.CFrame = CFrame.new(center + rel * scale) * (d.CFrame - d.CFrame.Position)
		elseif d:IsA("SpecialMesh") then
			d.Scale = d.Scale * scale
		elseif d:IsA("MeshPart") then
			pcall(function() d.Mesh.Scale = d.Mesh.Scale * scale end)
		end
	end
end

randomizeProperties = function(target)
	if not randomizeColorEnabled and not randomizeTransparencyEnabled then return end

	local parts = {}
	if target:IsA("BasePart") then table.insert(parts, target) else
		for _, descendant in ipairs(target:GetDescendants()) do
			if descendant:IsA("BasePart") then table.insert(parts, descendant) end
		end
	end

	for _, part in ipairs(parts) do
		if randomizeColorEnabled then
			local hmin = parseNumber(C.hueMinBox[1].Text, 0)
			local hmax = parseNumber(C.hueMaxBox[1].Text, 0)
			local smin = parseNumber(C.satMinBox[1].Text, 0)
			local smax = parseNumber(C.satMaxBox[1].Text, 0)
			local vmin = parseNumber(C.valMinBox[1].Text, 0)
			local vmax = parseNumber(C.valMaxBox[1].Text, 0)

			local h, s, v = part.Color:ToHSV()
			h = (h + randFloat(hmin, hmax)) % 1
			s = math.clamp(s + randFloat(smin, smax), 0, 1)
			v = math.clamp(v + randFloat(vmin, vmax), 0, 1)
			part.Color = Color3.fromHSV(h, s, v)
		end
		if randomizeTransparencyEnabled then
			local tmin = parseNumber(C.transMinBox[1].Text, 0)
			local tmax = parseNumber(C.transMaxBox[1].Text, 0)
			part.Transparency = math.clamp(part.Transparency + randFloat(tmin, tmax), 0, 1)
		end
	end
end

local function snapPositionToGrid(position, size)
	if size <= 0 then return position end
	local x = math.floor(position.X / size + 0.5) * size
	local y = math.floor(position.Y / size + 0.5) * size
	local z = math.floor(position.Z / size + 0.5) * size
	return Vector3.new(x, y, z)
end

findSurfacePositionAndNormal = function()
	if not mouse then return nil, nil, nil end
	local camera = workspace.CurrentCamera
	local unitRay = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { previewFolder, getWorkspaceContainer(), pathPreviewFolder }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 2000, params)
	if result then
		if surfaceAngleMode == "Floor" and result.Normal.Y < 0.7 then return nil, nil, nil
		elseif surfaceAngleMode == "Wall" and math.abs(result.Normal.Y) > 0.3 then return nil, nil, nil
		elseif surfaceAngleMode == "Ceiling" and result.Normal.Y > -0.7 then return nil, nil, nil end
		return result.Position, result.Normal, result.Instance
	end
	return nil, nil, nil
end

-- Helper to calculate asset transform (used by placeAsset and ghost preview)
local function applyAssetTransform(asset, position, normal, overrideScale, overrideRotation)
	local s = overrideScale
	if not s then
		s = 1.0 -- Default scale
		if randomizeScaleEnabled then
			local smin = parseNumber(C.scaleMinBox[1].Text, 0.8)
			local smax = parseNumber(C.scaleMaxBox[1].Text, 1.2)
			if smin <= 0 then smin = 0.1 end; if smax < smin then smax = smin end
			s = randFloat(smin, smax)
		end
	end

	local effectiveNormal = normal or Vector3.new(0, 1, 0)
	local randomRotation = overrideRotation

	if not randomRotation then
		local xrot, yrot, zrot
		yrot = math.rad(math.random() * 360) -- Always apply random Y rotation
		xrot, zrot = 0, 0

		if randomizeRotationEnabled then
			if normal and surfaceAngleMode == "Floor" then
				effectiveNormal = Vector3.new(0, 1, 0)
			elseif normal and surfaceAngleMode == "Ceiling" then
				xrot = math.pi
				effectiveNormal = Vector3.new(0, -1, 0)
			else
				local rotXMin = math.rad(parseNumber(C.rotXMinBox[1].Text, 0))
				local rotXMax = math.rad(parseNumber(C.rotXMaxBox[1].Text, 0))
				local rotZMin = math.rad(parseNumber(C.rotZMinBox[1].Text, 0))
				local rotZMax = math.rad(parseNumber(C.rotZMaxBox[1].Text, 0))
				xrot = randFloat(rotXMin, rotXMax)
				zrot = randFloat(rotZMin, rotZMax)
			end
		end
		randomRotation = CFrame.Angles(xrot, yrot, zrot)
	end

	local assetName = asset.Name:gsub("^GHOST_", "")
	local customOffset = assetOffsets[assetName] or 0
	local shouldAlign = assetOffsets[assetName .. "_align"] or false

	if asset:IsA("Model") and asset.PrimaryPart then
		if math.abs(s - 1) > 0.0001 then scaleModel(asset, s) end

		local finalPosition = position + (effectiveNormal * customOffset)

		if smartSnapEnabled then
			local downDir = -effectiveNormal
			if (not normal) or (surfaceAngleMode == "Off" and not shouldAlign) then downDir = Vector3.new(0, -1, 0) end

			-- Temporarily place to check bounds
			local tempCFrame = asset:GetPrimaryPartCFrame()
			asset:SetPrimaryPartCFrame(CFrame.new(finalPosition) * randomRotation)

			local maxDistAlongDown = -math.huge
			for _, desc in ipairs(asset:GetDescendants()) do
				if desc:IsA("BasePart") then
					local s_part = desc.Size/2
					local corners = {
						Vector3.new(s_part.X, s_part.Y, s_part.Z), Vector3.new(s_part.X, s_part.Y, -s_part.Z),
						Vector3.new(s_part.X, -s_part.Y, s_part.Z), Vector3.new(s_part.X, -s_part.Y, -s_part.Z),
						Vector3.new(-s_part.X, s_part.Y, s_part.Z), Vector3.new(-s_part.X, s_part.Y, -s_part.Z),
						Vector3.new(-s_part.X, -s_part.Y, s_part.Z), Vector3.new(-s_part.X, -s_part.Y, -s_part.Z)
					}
					for _, c in ipairs(corners) do
						local worldC = desc.CFrame * c
						local dist = (worldC - finalPosition):Dot(downDir)
						if dist > maxDistAlongDown then maxDistAlongDown = dist end
					end
				end
			end

			if maxDistAlongDown > -math.huge then
				local rayStart = finalPosition + (downDir * maxDistAlongDown) - (downDir * 1) 
				local rayParams = RaycastParams.new()
				rayParams.FilterDescendantsInstances = { previewFolder, getWorkspaceContainer(), pathPreviewFolder, asset }
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				local snapResult = workspace:Raycast(rayStart, downDir * 20, rayParams)
				if snapResult then
					local shift = (snapResult.Position - (finalPosition + downDir * maxDistAlongDown))
					finalPosition = finalPosition + (downDir * (shift:Dot(downDir)))
				end
			end
			asset:SetPrimaryPartCFrame(tempCFrame)
		end

		if snapToGridEnabled then finalPosition = snapPositionToGrid(finalPosition, gridSize) end

		local finalCFrame
		local forceAlign = (surfaceAngleMode == "Wall")
		if (forceAlign or (shouldAlign and surfaceAngleMode == "Off")) and normal then
			local rotatedCFrame = CFrame.new() * randomRotation
			local look = rotatedCFrame.LookVector
			local rightVec = look:Cross(effectiveNormal).Unit
			local lookActual = effectiveNormal:Cross(rightVec).Unit
			if rightVec.Magnitude < 0.9 then
				look = rotatedCFrame.RightVector; rightVec = look:Cross(effectiveNormal).Unit; lookActual = effectiveNormal:Cross(rightVec).Unit
			end
			finalCFrame = CFrame.fromMatrix(finalPosition, rightVec, effectiveNormal, -lookActual)
		else
			finalCFrame = CFrame.new(finalPosition) * randomRotation
		end
		asset:SetPrimaryPartCFrame(finalCFrame)

	elseif asset:IsA("BasePart") then
		asset.Size = asset.Size * s
		local finalYOffset = (asset.Size.Y / 2) + customOffset
		local finalPos = position + (effectiveNormal * finalYOffset)

		if smartSnapEnabled then
			local downDir = -effectiveNormal
			if (not normal) or (surfaceAngleMode == "Off" and not shouldAlign) then downDir = Vector3.new(0, -1, 0) end
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = { previewFolder, getWorkspaceContainer(), pathPreviewFolder, asset }
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			local rayStart = finalPos + (downDir * (asset.Size.Y/2 - 1))
			local snapResult = workspace:Raycast(rayStart, downDir * 20, rayParams)
			if snapResult then
				local currentBottom = finalPos + (downDir * (asset.Size.Y/2))
				local shift = snapResult.Position - currentBottom
				finalPos = finalPos + shift
			end
		end

		if snapToGridEnabled then finalPos = snapPositionToGrid(finalPos, gridSize) end
		local finalCFrame
		local forceAlign = (surfaceAngleMode == "Wall")
		if (forceAlign or (shouldAlign and surfaceAngleMode == "Off")) and normal then
			local rotatedCFrame = CFrame.new() * randomRotation
			local look = rotatedCFrame.LookVector
			local rightVec = look:Cross(effectiveNormal).Unit
			local lookActual = effectiveNormal:Cross(rightVec).Unit
			if rightVec.Magnitude < 0.9 then
				look = rotatedCFrame.RightVector; rightVec = look:Cross(effectiveNormal).Unit; lookActual = effectiveNormal:Cross(rightVec).Unit
			end
			finalCFrame = CFrame.fromMatrix(finalPos, rightVec, effectiveNormal, -lookActual)
		else
			finalCFrame = CFrame.new(finalPos) * randomRotation
		end
		asset.CFrame = finalCFrame
	end
	return asset
end

placeAsset = function(assetToClone, position, normal, overrideScale, overrideRotation)
	local clone = assetToClone:Clone()
	randomizeProperties(clone)
	if clone:IsA("Model") and not clone.PrimaryPart then
		for _, v in ipairs(clone:GetDescendants()) do if v:IsA("BasePart") then clone.PrimaryPart = v; break end end
	end

	applyAssetTransform(clone, position, normal, overrideScale, overrideRotation)

	return clone
end

paintAt = function(center, surfaceNormal)
	local radius = math.max(0.1, parseNumber(C.radiusBox[1].Text, 10))
	local density = math.max(1, math.floor(parseNumber(C.densityBox[1].Text, 10)))
	local spacing = math.max(0.1, parseNumber(C.spacingBox[1].Text, 1.0))

	ChangeHistoryService:SetWaypoint("Brush - Before Paint")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder")
	groupFolder.Name = "BrushGroup_" .. tostring(math.floor(os.time()))
	groupFolder.Parent = container
	local placed = {}

	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end

	local allAssets = targetGroup:GetChildren()
	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then groupFolder:Destroy(); return end

	local up = surfaceNormal
	local look = Vector3.new(1, 0, 0)
	if math.abs(up:Dot(look)) > 0.99 then look = Vector3.new(0, 0, 1) end
	local right = look:Cross(up).Unit
	local look_actual = up:Cross(right).Unit
	local planeCFrame = CFrame.fromMatrix(center, right, up, -look_actual)

	for i = 1, density do
		local assetToClone = getRandomWeightedAsset(activeAssets)
		if not assetToClone then break end
		local found = false; local candidatePos = nil; local candidateNormal = surfaceNormal; local attempts = 0
		while not found and attempts < 12 do
			attempts = attempts + 1
			local offset2D = randomPointInCircle(radius)
			local spawnPos = planeCFrame:PointToWorldSpace(Vector3.new(offset2D.X, 0, offset2D.Z))
			local rayOrigin = spawnPos + surfaceNormal * 5; local rayDir = -surfaceNormal * 10
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { previewFolder, container }; params.FilterType = Enum.RaycastFilterType.Exclude
			local result = workspace:Raycast(rayOrigin, rayDir, params)
			if result and result.Instance then
				local posOnSurface = result.Position
				local ok = true
				for _, p in ipairs(placed) do if (p - posOnSurface).Magnitude < spacing then ok = false; break end end
				if ok then found = true; candidatePos = posOnSurface; candidateNormal = result.Normal end
			end
		end
		if candidatePos then
			local placedAsset = placeAsset(assetToClone, candidatePos, candidateNormal)
			if placedAsset then placedAsset.Parent = groupFolder end
			table.insert(placed, candidatePos)
		end
	end
	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Paint")
end


paintInVolume = function(center)
	local radius = math.max(0.1, parseNumber(C.radiusBox[1].Text, 10))
	local density = math.max(1, math.floor(parseNumber(C.densityBox[1].Text, 10)))
	ChangeHistoryService:SetWaypoint("Brush - Before VolumePaint")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder"); groupFolder.Name = "BrushVolume_" .. tostring(math.floor(os.time())); groupFolder.Parent = container

	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end
	local allAssets = targetGroup:GetChildren()

	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then groupFolder:Destroy(); return end
	for i = 1, density do
		local assetToPlace = getRandomWeightedAsset(activeAssets)
		if assetToPlace then
			local randomPoint = center + getRandomPointInSphere(radius)
			local placedAsset = placeAsset(assetToPlace, randomPoint, nil)
			if placedAsset then placedAsset.Parent = groupFolder end
		end
	end
	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After VolumePaint")
end

stampAt = function(center, surfaceNormal)
	ChangeHistoryService:SetWaypoint("Brush - Before Stamp")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder"); groupFolder.Name = "BrushStamp_" .. tostring(math.floor(os.time())); groupFolder.Parent = container

	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end
	local allAssets = targetGroup:GetChildren()

	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then groupFolder:Destroy(); return end

	local assetToPlace = nextStampAsset or getRandomWeightedAsset(activeAssets)
	if assetToPlace then
		local placedAsset = placeAsset(assetToPlace, center, surfaceNormal, nextStampScale, nextStampRotation)
		if placedAsset then placedAsset.Parent = groupFolder end
	end

	-- Reset so next preview picks a new one
	nextStampAsset = nil 
	nextStampScale = nil
	nextStampRotation = nil
	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Stamp")
end

eraseAt = function(center)
	local radius = math.max(0.1, parseNumber(C.radiusBox[1].Text, 10))
	local container = workspace:FindFirstChild(WORKSPACE_FOLDER_NAME)
	if not container then return end
	local itemsToDestroy = {}
	local allChildren = container:GetDescendants()
	for _, child in ipairs(allChildren) do
		if child:IsA("BasePart") or child:IsA("Model") then
			local part = child
			if child:IsA("Model") then part = child.PrimaryPart end
			if part and part.Parent and (part.Position - center).Magnitude <= radius then
				local ancestorToDestroy = child
				while ancestorToDestroy and ancestorToDestroy.Parent ~= container and ancestorToDestroy.Parent ~= workspace do ancestorToDestroy = ancestorToDestroy.Parent end
				if ancestorToDestroy and ancestorToDestroy.Parent == container then
					local filterActive = next(eraseFilter) ~= nil
					if not filterActive or eraseFilter[ancestorToDestroy.Name] then itemsToDestroy[ancestorToDestroy] = true end
				end
			end
		end
	end
	if next(itemsToDestroy) ~= nil then
		ChangeHistoryService:SetWaypoint("Brush - Before Erase")
		for item, _ in pairs(itemsToDestroy) do item:Destroy() end
		if #container:GetChildren() == 0 then container:Destroy() end
		ChangeHistoryService:SetWaypoint("Brush - After Erase")
	end
end

fillArea = function(part)
	if not part then return end
	local density = math.max(1, math.floor(parseNumber(C.densityBox[1].Text, 10)))
	local spacing = math.max(0.1, parseNumber(C.spacingBox[1].Text, 1.0))

	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then return end
	local allAssets = targetGroup:GetChildren()

	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then return end
	ChangeHistoryService:SetWaypoint("Brush - Before Fill")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder"); groupFolder.Name = "BrushFill_" .. tostring(math.floor(os.time())); groupFolder.Parent = container
	local placedPoints = {}
	local partCF = part.CFrame; local partSize = part.Size
	for i = 1, density do
		local assetToPlace = getRandomWeightedAsset(activeAssets)
		local foundPoint = false; local attempts = 0
		while not foundPoint and attempts < 20 do
			attempts = attempts + 1
			local randomX = (math.random() - 0.5) * partSize.X
			local randomZ = (math.random() - 0.5) * partSize.Z
			local topY = partSize.Y / 2
			local pointInPartSpace = Vector3.new(randomX, topY, randomZ)
			local worldPoint = partCF * pointInPartSpace
			local rayOrigin = worldPoint + part.CFrame.UpVector * 5
			local rayDir = -part.CFrame.UpVector * (partSize.Y + 10)
			local params = RaycastParams.new()

			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = {part}
			local result = workspace:Raycast(rayOrigin, rayDir, params)

			if result then
				local isSpaced = true
				for _, p in ipairs(placedPoints) do if (result.Position - p).Magnitude < spacing then isSpaced = false; break end end

				if isSpaced then
					local placedAsset = placeAsset(assetToPlace, result.Position, result.Normal)
					if placedAsset then placedAsset.Parent = groupFolder; table.insert(placedPoints, result.Position) end
					foundPoint = true
				end
			end
		end
	end
	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Fill")
end

replaceAt = function(center)
	if not sourceAsset or not targetAsset then return end
	local radius = math.max(0.1, parseNumber(C.radiusBox[1].Text, 10))
	local container = workspace:FindFirstChild(WORKSPACE_FOLDER_NAME)
	if not container then return end
	local sourceModel = assetsFolder:FindFirstChild(sourceAsset)
	local targetModel = assetsFolder:FindFirstChild(targetAsset)
	if not sourceModel or not targetModel then return end
	local itemsToReplace = {}
	local allPartsInRadius = workspace:GetPartBoundsInRadius(center, radius)
	for _, part in ipairs(allPartsInRadius) do
		if part:IsDescendantOf(container) then
			local ancestorToReplace = part
			while ancestorToReplace and ancestorToReplace.Parent ~= container do ancestorToReplace = ancestorToReplace.Parent end
			if ancestorToReplace and ancestorToReplace.Name == sourceAsset then itemsToReplace[ancestorToReplace] = true end
		end
	end
	if next(itemsToReplace) ~= nil then
		ChangeHistoryService:SetWaypoint("Brush - Before Replace")
		local groupFolder = Instance.new("Folder"); groupFolder.Name = "BrushReplace_" .. tostring(math.floor(os.time())); groupFolder.Parent = container
		for item, _ in pairs(itemsToReplace) do
			local oldCFrame, oldSize
			if item:IsA("Model") and item.PrimaryPart then oldCFrame = item.PrimaryPart.CFrame; oldSize = item:GetExtentsSize()
			elseif item:IsA("BasePart") then oldCFrame = item.CFrame; oldSize = item.Size end
			if oldCFrame and oldSize then
				item:Destroy()
				local newAsset = targetModel:Clone()
				if newAsset:IsA("Model") and newAsset.PrimaryPart then
					local _, newSize = newAsset:GetBoundingBox()
					local scaleFactor = oldSize.Magnitude / newSize.Magnitude
					scaleModel(newAsset, scaleFactor)
					newAsset:SetPrimaryPartCFrame(oldCFrame)
				elseif newAsset:IsA("BasePart") then
					newAsset.Size = oldSize; newAsset.CFrame = oldCFrame
				end
				newAsset.Parent = groupFolder
			end
		end
		if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
		ChangeHistoryService:SetWaypoint("Brush - After Replace")
	end
end

paintAlongPath = function()
	if #pathPoints < 2 then return end
	ChangeHistoryService:SetWaypoint("Brush - Before Path Paint")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder"); groupFolder.Name = "BrushPath_" .. tostring(math.floor(os.time())); groupFolder.Parent = container

	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); clearPath(); return end
	local allAssets = targetGroup:GetChildren()

	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then groupFolder:Destroy(); clearPath(); return end
	local spacing = math.max(0.1, parseNumber(C.spacingBox[1].Text, 1.0))
	local distanceSinceLastPaint = 0
	local pointsToDraw = pathPoints
	for i = 1, #pointsToDraw - 1 do
		local p1 = pointsToDraw[i]; local p2 = pointsToDraw[i+1]
		local p0 = pointsToDraw[i-1] or (p1 + (p1 - p2)); local p3 = pointsToDraw[i+2] or (p2 + (p2 - p1))
		local lastPoint = p1
		local segments = 100
		for t_step = 1, segments do
			local t = t_step / segments
			local pointOnCurve = catmullRom(p0, p1, p2, p3, t)
			local segmentLength = (pointOnCurve - lastPoint).Magnitude
			distanceSinceLastPaint = distanceSinceLastPaint + segmentLength
			if distanceSinceLastPaint >= spacing then
				local assetToPlace = getRandomWeightedAsset(activeAssets)
				local rayOrigin = pointOnCurve + Vector3.new(0, 10, 0); local rayDir = Vector3.new(0, -20, 0)
				local params = RaycastParams.new()

				local filter = { previewFolder, pathPreviewFolder, container }
				params.FilterDescendantsInstances = filter
				params.FilterType = Enum.RaycastFilterType.Exclude

				local result = workspace:Raycast(rayOrigin, rayDir, params)
				if result then
					local placedAsset = placeAsset(assetToPlace, result.Position, result.Normal)
					if placedAsset then placedAsset.Parent = groupFolder end
				end
				distanceSinceLastPaint = 0
			end
			lastPoint = pointOnCurve
		end
	end
	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Path Paint")
	clearPath()
end

clearPath = function() pathPoints = {}; pathPreviewFolder:ClearAllChildren() end
updatePathPreview = function()
	pathPreviewFolder:ClearAllChildren()
	for _, point in ipairs(pathPoints) do
		local marker = Instance.new("Part")
		marker.Shape = Enum.PartType.Ball; marker.Size = Vector3.new(0.8, 0.8, 0.8)
		marker.Anchored = true; marker.CanCollide = false; marker.Color = Theme.Accent; marker.Material = Enum.Material.Neon
		marker.Position = point; marker.Parent = pathPreviewFolder
	end
	local pointsToDraw = pathPoints
	if #pointsToDraw < 2 then return end
	local segments = 20
	for i = 1, #pointsToDraw - 1 do
		local p1 = pointsToDraw[i]; local p2 = pointsToDraw[i+1]
		local p0 = pointsToDraw[i-1] or (p1 + (p1 - p2)); local p3 = pointsToDraw[i+2] or (p2 + (p2 - p1))
		local lastPoint = p1
		for t_step = 1, segments do
			local t = t_step / segments
			local pointOnCurve = catmullRom(p0, p1, p2, p3, t)
			local part = Instance.new("Part")
			part.Anchored = true; part.CanCollide = false; part.Size = Vector3.new(0.4, 0.4, (pointOnCurve - lastPoint).Magnitude)
			part.CFrame = CFrame.new(lastPoint, pointOnCurve) * CFrame.new(0, 0, -(pointOnCurve-lastPoint).Magnitude / 2)
			part.Color = Theme.Accent; part.Material = Enum.Material.Neon; part.Parent = pathPreviewFolder
			lastPoint = pointOnCurve
		end
	end
end

updateGhostPreview = function(position, normal)
	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then return end
	local allAssets = targetGroup:GetChildren()
	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then 
		if ghostModel then ghostModel:Destroy(); ghostModel = nil end
		return 
	end

	if not nextStampAsset or not nextStampAsset.Parent then
		nextStampAsset = getRandomWeightedAsset(activeAssets)
		nextStampScale = nil
		nextStampRotation = nil
	end

	-- Generate stable random values if missing
	if not nextStampScale then
		local smin = parseNumber(C.scaleMinBox[1].Text, 0.8)
		local smax = parseNumber(C.scaleMaxBox[1].Text, 1.2)
		if smin <= 0 then smin = 0.1 end; if smax < smin then smax = smin end
		nextStampScale = randFloat(smin, smax)
	end

	if not nextStampRotation then
		local rotXMin = math.rad(parseNumber(C.rotXMinBox[1].Text, 0))
		local rotXMax = math.rad(parseNumber(C.rotXMaxBox[1].Text, 0))
		local rotZMin = math.rad(parseNumber(C.rotZMinBox[1].Text, 0))
		local rotZMax = math.rad(parseNumber(C.rotZMaxBox[1].Text, 0))
		local xrot = randFloat(rotXMin, rotXMax)
		local yrot = math.rad(math.random() * 360)
		local zrot = randFloat(rotZMin, rotZMax)
		if surfaceAngleMode == "Floor" and normal then
			xrot = 0; zrot = 0
		elseif surfaceAngleMode == "Ceiling" and normal then
			xrot = math.pi; zrot = 0
		end
		nextStampRotation = CFrame.Angles(xrot, yrot, zrot)
	end

	-- Always recreate ghost to avoid cumulative scaling issues
	if ghostModel then ghostModel:Destroy() end

	ghostModel = nextStampAsset:Clone()
	ghostModel.Name = "GHOST_" .. nextStampAsset.Name

	if ghostModel:IsA("Model") and not ghostModel.PrimaryPart then
		for _, v in ipairs(ghostModel:GetDescendants()) do if v:IsA("BasePart") then ghostModel.PrimaryPart = v; break end end
	end

	-- Apply ghost styling to Model descendants OR single Part
	local partsToStyle = {}
	if ghostModel:IsA("Model") then
		for _, d in ipairs(ghostModel:GetDescendants()) do table.insert(partsToStyle, d) end
	elseif ghostModel:IsA("BasePart") then
		table.insert(partsToStyle, ghostModel)
	end

	for _, desc in ipairs(partsToStyle) do
		if desc:IsA("BasePart") then
			desc.Transparency = ghostTransparency
			desc.CastShadow = false
			desc.CanCollide = false
			desc.Anchored = true
			desc.Material = Enum.Material.ForceField
			desc.Color = Theme.Accent
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			desc:Destroy()
		end
	end

	ghostModel.Parent = previewFolder
	applyAssetTransform(ghostModel, position, normal, nextStampScale, nextStampRotation)
end

updatePreview = function()
	if not mouse or not previewPart then return end

	-- Determine if we should show ghost
	local showGhost = (currentMode ~= "Replace" and currentMode ~= "Erase")

	if not showGhost and ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end

	if currentMode == "Line" and lineStartPoint then previewPart.Parent = nil
	elseif currentMode == "Volume" then
		previewPart.Parent = previewFolder
		local radius = math.max(0.1, parseNumber(C.radiusBox[1].Text, 10))
		local unitRay = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
		local positionInSpace = unitRay.Origin + unitRay.Direction * 100
		previewPart.Shape = Enum.PartType.Ball
		previewPart.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		previewPart.CFrame = CFrame.new(positionInSpace)
		previewPart.Color = Color3.fromRGB(150, 150, 255)
		if cyl then cyl.Parent = nil end

		if showGhost then
			updateGhostPreview(positionInSpace, nil)
		end
	else
		if currentMode == "Paint" or currentMode == "Line" or currentMode == "Path" or currentMode == "Fill" then previewPart.Color = Color3.fromRGB(80, 255, 80)
		elseif currentMode == "Replace" then previewPart.Color = Color3.fromRGB(80, 180, 255)
		else previewPart.Color = Color3.fromRGB(255, 80, 80) end

		previewPart.Shape = Enum.PartType.Cylinder
		local radius = math.max(0.1, parseNumber(C.radiusBox[1].Text, 10))
		local surfacePos, normal = findSurfacePositionAndNormal()

		if not surfacePos or not normal or currentMode == "Line" or currentMode == "Path" then
			previewPart.Parent = nil

			if not surfacePos and showGhost and ghostModel then
				ghostModel:Destroy()
				ghostModel = nil
			elseif surfacePos and showGhost then
				updateGhostPreview(surfacePos, normal)
			end
		else
			if currentMode == "Stamp" then
				previewPart.Parent = nil
			else
				previewPart.Parent = previewFolder
				local pos = surfacePos
				local look = Vector3.new(1, 0, 0)
				if math.abs(look:Dot(normal)) > 0.99 then look = Vector3.new(0, 0, 1) end
				local right = look:Cross(normal).Unit
				local lookActual = normal:Cross(right).Unit
				previewPart.CFrame = CFrame.fromMatrix(pos + normal * 0.05, normal, right, lookActual)
				previewPart.Size = Vector3.new(0.02, radius*2, radius*2)
			end

			if showGhost then
				updateGhostPreview(surfacePos, normal)
			end
		end
	end
	if currentMode == "Line" and lineStartPoint and linePreviewPart then
		local endPoint, _ = findSurfacePositionAndNormal()
		if endPoint then
			linePreviewPart.Parent = previewFolder
			local mag = (endPoint - lineStartPoint).Magnitude
			linePreviewPart.Size = Vector3.new(0.2, 0.2, mag)
			linePreviewPart.CFrame = CFrame.new(lineStartPoint, endPoint) * CFrame.new(0, 0, -mag/2)
		else linePreviewPart.Parent = nil end
	elseif linePreviewPart then linePreviewPart.Parent = nil end
end

local function paintAlongLine(startPos, endPos)
	local spacing = math.max(0.1, parseNumber(C.spacingBox[1].Text, 1.0))
	local lineVector = endPos - startPos; local lineLength = lineVector.Magnitude
	if lineLength < spacing then return end
	ChangeHistoryService:SetWaypoint("Brush - Before Line")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder"); groupFolder.Name = "BrushLine_" .. tostring(math.floor(os.time())); groupFolder.Parent = container

	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end
	local allAssets = targetGroup:GetChildren()

	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then groupFolder:Destroy(); return end
	local numSteps = math.floor(lineLength / spacing)
	for i = 0, numSteps do
		local t = i / numSteps
		local pointOnLine = startPos + lineVector * t
		local rayOrigin = pointOnLine + Vector3.new(0, 10, 0); local rayDir = Vector3.new(0, -20, 0)
		local params = RaycastParams.new()

		local filter = { previewFolder, container }
		params.FilterDescendantsInstances = filter
		params.FilterType = Enum.RaycastFilterType.Exclude

		local result = workspace:Raycast(rayOrigin, rayDir, params)
		if result then
			local skip = false
			if surfaceAngleMode == "Floor" and result.Normal.Y < 0.7 then skip = true
			elseif surfaceAngleMode == "Wall" and math.abs(result.Normal.Y) > 0.3 then skip = true
			elseif surfaceAngleMode == "Ceiling" and result.Normal.Y > -0.7 then skip = true end

			if not skip then
				local assetToPlace = getRandomWeightedAsset(activeAssets)
				local placedAsset = placeAsset(assetToPlace, result.Position, result.Normal)
				if placedAsset then placedAsset.Parent = groupFolder end
			end
		end
	end
	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Line")
end

-- Main Connection Logic

C.applyPathBtn[1].MouseButton1Click:Connect(paintAlongPath)
C.clearPathBtn[1].MouseButton1Click:Connect(clearPath)
C.fillBtn[1].MouseButton1Click:Connect(function() if C.fillBtn[1].Text ~= "SELECT TARGET VOLUME" then fillArea(partToFill) end end)

-- Individual Randomize Button Logic
C.randomizeScaleBtn[1].MouseButton1Click:Connect(function()
	if not randomizeScaleEnabled then return end
	C.scaleMinBox[1].Text = string.format("%.2f", randFloat(0.5, 1.0))
	C.scaleMaxBox[1].Text = string.format("%.2f", randFloat(1.1, 2.5))
end)
C.randomizeRotationBtn[1].MouseButton1Click:Connect(function()
	if not randomizeRotationEnabled then return end
	C.rotXMinBox[1].Text = tostring(math.random(0, 45))
	C.rotXMaxBox[1].Text = tostring(math.random(45, 90))
	C.rotZMinBox[1].Text = tostring(math.random(0, 45))
	C.rotZMaxBox[1].Text = tostring(math.random(45, 90))
end)
C.randomizeColorBtn[1].MouseButton1Click:Connect(function()
	if not randomizeColorEnabled then return end
	C.hueMinBox[1].Text = string.format("%.2f", randFloat(0, 0.5))
	C.hueMaxBox[1].Text = string.format("%.2f", randFloat(0.6, 1.0))
	C.satMinBox[1].Text = string.format("%.2f", randFloat(-0.3, 0))
	C.satMaxBox[1].Text = string.format("%.2f", randFloat(0, 0.3))
	C.valMinBox[1].Text = string.format("%.2f", randFloat(-0.2, 0))
	C.valMaxBox[1].Text = string.format("%.2f", randFloat(0, 0.2))
end)
C.randomizeTransparencyBtn[1].MouseButton1Click:Connect(function()
	if not randomizeTransparencyEnabled then return end
	C.transMinBox[1].Text = string.format("%.2f", randFloat(0, 0.5))
	C.transMaxBox[1].Text = string.format("%.2f", randFloat(0.6, 1.0))
end)


-- Helper for UI Updates
updateModeButtonsUI = function()
	for mode, controls in pairs(C.modeButtons) do
		if mode == currentMode then
			controls.Stroke.Color = Theme.Accent
			controls.Button.TextColor3 = Theme.Background
			controls.Button.BackgroundColor3 = Theme.Accent
			controls.Stroke.Thickness = 2
		else
			controls.Stroke.Color = Theme.Border
			controls.Button.TextColor3 = Theme.Text
			controls.Button.BackgroundColor3 = Theme.Panel
			controls.Stroke.Thickness = 1
		end
	end

	-- Context visibility
	C.pathFrame.Visible = (currentMode == "Path")
	C.fillFrame.Visible = (currentMode == "Fill")

	-- Input visibility
	local showBrush = (currentMode == "Paint" or currentMode == "Erase" or currentMode == "Replace" or currentMode == "Volume" or currentMode == "Fill")
	local showDensity = (currentMode == "Paint" or currentMode == "Volume" or currentMode == "Fill")
	local showSpacing = (currentMode == "Paint" or currentMode == "Line" or currentMode == "Path")

	C.radiusBox[2].Visible = showBrush
	C.densityBox[2].Visible = showDensity
	C.spacingBox[2].Visible = showSpacing
end

updateToggle = function(btn, inner, label, state, activeText, inactiveText)
	inner.Visible = state
	if state then
		inner.BackgroundColor3 = Theme.Accent
		if activeText then label.Text = activeText end
	else
		if inactiveText then label.Text = inactiveText end
	end
end

local function updateInputGroupEnabled(grid, enabled, randomizeBtn)
	-- Update input boxes
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChildOfClass("TextBox") then
			local inputBox = child:FindFirstChildOfClass("TextBox")
			inputBox.TextEditable = enabled
			if enabled then
				inputBox.TextColor3 = Theme.Accent
				child:FindFirstChildOfClass("TextLabel").TextColor3 = Theme.TextDim
			else
				inputBox.TextColor3 = Theme.TextDim
				child:FindFirstChildOfClass("TextLabel").TextColor3 = Color3.fromHex("505050")
			end
		end
	end
	-- Update randomize button
	if randomizeBtn then
		randomizeBtn[1].Active = enabled
		pcall(function() randomizeBtn[1].Interactable = enabled end) -- Use Interactable if available

		if enabled then
			randomizeBtn[2].Color = Theme.Border
			randomizeBtn[1].TextColor3 = Theme.Text
			randomizeBtn[1].TextTransparency = 0
		else
			randomizeBtn[2].Color = Color3.fromHex("2a2a2a")
			randomizeBtn[1].TextColor3 = Theme.TextDim
			randomizeBtn[1].TextTransparency = 0.5
		end
	end
end

updateAllToggles = function()

	local alignState = false
	local activeState = false
	if selectedAssetInUI then
		alignState = assetOffsets[selectedAssetInUI .. "_align"]
		activeState = assetOffsets[selectedAssetInUI .. "_active"] ~= false
	end

	updateToggle(C.assetSettingsAlign[1], C.assetSettingsAlign[2], C.assetSettingsAlign[3], alignState)
	updateToggle(C.assetSettingsActive[1], C.assetSettingsActive[2], C.assetSettingsActive[3], activeState)

	updateToggle(C.smartSnapBtn[1], C.smartSnapBtn[2], C.smartSnapBtn[3], smartSnapEnabled)
	updateToggle(C.snapToGridBtn[1], C.snapToGridBtn[2], C.snapToGridBtn[3], snapToGridEnabled)

	-- New randomization toggles
	updateToggle(C.randomizeScaleToggle[1], C.randomizeScaleToggle[2], C.randomizeScaleToggle[3], randomizeScaleEnabled)
	updateToggle(C.randomizeRotationToggle[1], C.randomizeRotationToggle[2], C.randomizeRotationToggle[3], randomizeRotationEnabled)
	updateToggle(C.randomizeColorToggle[1], C.randomizeColorToggle[2], C.randomizeColorToggle[3], randomizeColorEnabled)
	updateToggle(C.randomizeTransparencyToggle[1], C.randomizeTransparencyToggle[2], C.randomizeTransparencyToggle[3], randomizeTransparencyEnabled)

	-- Update input groups
	updateInputGroupEnabled(C.scaleGrid, randomizeScaleEnabled, C.randomizeScaleBtn)
	updateInputGroupEnabled(C.rotationGrid, randomizeRotationEnabled, C.randomizeRotationBtn)
	updateInputGroupEnabled(C.colorGrid, randomizeColorEnabled, C.randomizeColorBtn)
	updateInputGroupEnabled(C.transparencyGrid, randomizeTransparencyEnabled, C.randomizeTransparencyBtn)

	for mode, controls in pairs(C.surfaceButtons) do
		if mode == surfaceAngleMode then
			controls.Stroke.Color = Theme.Accent
			controls.Button.TextColor3 = Theme.Background
			controls.Button.BackgroundColor3 = Theme.Accent
			controls.Stroke.Thickness = 2
		else
			controls.Stroke.Color = Theme.Border
			controls.Button.TextColor3 = Theme.Text
			controls.Button.BackgroundColor3 = Theme.Panel
			controls.Stroke.Thickness = 1
		end
	end
end


addSelectedAssets = function()
	local selection = Selection:Get()
	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then return end

	for _, v in ipairs(selection) do
		if (v:IsA("Model") or v:IsA("BasePart")) and not targetGroup:FindFirstChild(v.Name) then
			local clone = v:Clone()
			clone.Parent = targetGroup
		end
	end
	updateAssetUIList()
end

clearAssetList = function()
	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if targetGroup then
		targetGroup:ClearAllChildren()
	end
	-- Note: Not clearing offsets to preserve settings if re-added
	updateAssetUIList()
end

-- Asset UI Logic
local function setupViewport(viewport, asset, zoomScale)
	zoomScale = zoomScale or 1.0
	for _, c in ipairs(viewport:GetChildren()) do c:Destroy() end
	local cam = Instance.new("Camera"); cam.Parent = viewport; viewport.CurrentCamera = cam
	local worldModel = Instance.new("WorldModel"); worldModel.Parent = viewport
	local c = asset:Clone(); c.Parent = worldModel
	local cf, size = c:GetBoundingBox()
	local maxDim = math.max(size.X, size.Y, size.Z)
	local dist = (maxDim / 2) / math.tan(math.rad(35))
	dist = (dist * 1.2) / zoomScale
	cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist, dist*0.8, dist), cf.Position)
end

updateGroupUI = function()
	C.groupNameLabel[1].Text = "GROUP: " .. string.upper(currentAssetGroup)
end

updateAssetUIList = function()
	for _, v in pairs(C.assetListFrame:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end

	if isGroupListView then
		-- Render List of Groups (Folder View)
		local groups = {}
		for _, c in ipairs(assetsFolder:GetChildren()) do if c:IsA("Folder") then table.insert(groups, c) end end
		table.sort(groups, function(a,b) return a.Name < b.Name end)

		for _, grp in ipairs(groups) do
			local btn = Instance.new("TextButton")
			btn.BackgroundColor3 = (grp.Name == currentAssetGroup) and Theme.Panel or Theme.Background
			btn.Text = ""
			btn.Parent = C.assetListFrame
			local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Border; stroke.Parent = btn
			if grp.Name == currentAssetGroup then stroke.Color = Theme.Accent end

			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.new(1, 0, 1, -20)
			icon.BackgroundTransparency = 1
			icon.Text = "??"
			icon.TextSize = 32
			icon.TextColor3 = Theme.TextDim
			icon.Parent = btn

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -8, 0, 20)
			lbl.Position = UDim2.new(0, 4, 1, -24)
			lbl.BackgroundTransparency = 1
			lbl.Text = grp.Name .. " (" .. #grp:GetChildren() .. ")"
			lbl.Font = Theme.FontTech
			lbl.TextSize = 11
			lbl.TextColor3 = (grp.Name == currentAssetGroup) and Theme.Accent or Theme.Text
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.Parent = btn

			btn.MouseButton1Click:Connect(function()
				currentAssetGroup = grp.Name
				isGroupListView = false
				updateGroupUI()
				updateAssetUIList()
			end)
		end
		return
	end

	-- Normal Asset View
	local targetGroup = assetsFolder:FindFirstChild(currentAssetGroup)
	if not targetGroup then return end

	local children = targetGroup:GetChildren()

	for _, asset in ipairs(children) do
		local isActive = assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end

		local btn = Instance.new("TextButton")
		btn.BackgroundColor3 = isActive and Theme.Panel or Color3.fromHex("151515")
		btn.Text = ""
		btn.Parent = C.assetListFrame
		local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Border; stroke.Parent = btn

		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.new(1, -8, 0, 60)
		vp.Position = UDim2.new(0, 4, 0, 4)
		vp.BackgroundTransparency = 1
		vp.ImageTransparency = isActive and 0 or 0.6
		vp.Parent = btn

		-- Zoom Controls
		local zoomKey = asset.Name .. "_previewZoom"
		local zoom = assetOffsets[zoomKey] or 1.0

		pcall(function() setupViewport(vp, asset, zoom) end)

		local function updateZoom(delta)
			zoom = math.clamp(zoom + delta, 0.5, 5.0)
			assetOffsets[zoomKey] = zoom
			persistOffsets()
			pcall(function() setupViewport(vp, asset, zoom) end)
		end

		local plusBtn = Instance.new("TextButton")
		plusBtn.Size = UDim2.new(0, 20, 0, 20)
		plusBtn.Position = UDim2.new(1, -24, 0, 4)
		plusBtn.Text = "+"
		plusBtn.BackgroundColor3 = Theme.Background
		plusBtn.TextColor3 = Theme.Text
		plusBtn.Visible = isActive
		plusBtn.Parent = btn
		plusBtn.MouseButton1Click:Connect(function() updateZoom(0.1) end)

		local minusBtn = Instance.new("TextButton")
		minusBtn.Size = UDim2.new(0, 20, 0, 20)
		minusBtn.Position = UDim2.new(1, -24, 0, 28)
		minusBtn.Text = "-"
		minusBtn.BackgroundColor3 = Theme.Background
		minusBtn.TextColor3 = Theme.Text
		minusBtn.Visible = isActive
		minusBtn.Parent = btn
		minusBtn.MouseButton1Click:Connect(function() updateZoom(-0.1) end)

		local deleteBtn = Instance.new("TextButton")
		deleteBtn.Size = UDim2.new(0, 20, 0, 20)
		deleteBtn.Position = UDim2.new(0, 4, 0, 4)
		deleteBtn.Text = "X"
		deleteBtn.BackgroundColor3 = Theme.Background
		deleteBtn.TextColor3 = Theme.Destructive
		deleteBtn.Visible = isActive
		deleteBtn.Parent = btn

		local deleteConfirm = false
		deleteBtn.MouseButton1Click:Connect(function()
			if not deleteConfirm then
				deleteConfirm = true
				deleteBtn.Text = "?"
				deleteBtn.BackgroundColor3 = Theme.Destructive
				deleteBtn.TextColor3 = Theme.Text
				task.delay(2, function()
					if deleteConfirm then
						deleteConfirm = false
						if deleteBtn and deleteBtn.Parent then
							deleteBtn.Text = "X"
							deleteBtn.BackgroundColor3 = Theme.Background
							deleteBtn.TextColor3 = Theme.Destructive
						end
					end
				end)
			else
				asset:Destroy()
				updateAssetUIList()
			end
		end)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -8, 0, 20)
		lbl.Position = UDim2.new(0, 4, 1, -24)
		lbl.BackgroundTransparency = 1
		lbl.Text = asset.Name
		lbl.Font = Theme.FontTech
		lbl.TextSize = 11
		lbl.TextColor3 = isActive and Theme.Text or Theme.TextDim
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Parent = btn

		btn.MouseButton1Click:Connect(function()
			selectedAssetInUI = asset.Name
			C.assetSettingsFrame.Visible = true
			C.assetSettingsName.Text = "SELECTED: " .. string.upper(asset.Name)
			C.assetSettingsOffsetY[1].Text = tostring(assetOffsets[asset.Name] or 0)
			C.assetSettingsWeight[1].Text = tostring(assetOffsets[asset.Name.."_weight"] or 1)
			updateAllToggles()
			updateAssetUIList() -- Redraw for highlight
		end)

		if selectedAssetInUI == asset.Name then stroke.Color = Theme.Accent; stroke.Thickness = 2 end
	end
end

updateFillSelection = function()
	if currentMode ~= "Fill" then
		partToFill = nil
		if fillSelectionBox then fillSelectionBox.Adornee = nil end
		C.fillBtn[1].Text = "SELECT TARGET VOLUME"
		C.fillBtn[1].TextColor3 = Theme.Text
		return
	end
	local selection = Selection:Get()
	if #selection == 1 and selection[1]:IsA("BasePart") then
		partToFill = selection[1]
		if not fillSelectionBox then
			fillSelectionBox = Instance.new("SelectionBox")
			fillSelectionBox.Color3 = Theme.Accent
			fillSelectionBox.LineThickness = 0.1
			fillSelectionBox.Parent = previewFolder
		end
		fillSelectionBox.Adornee = partToFill
		C.fillBtn[1].Text = "FILL: " .. partToFill.Name
		C.fillBtn[1].TextColor3 = Theme.Success
	else
		partToFill = nil
		if fillSelectionBox then fillSelectionBox.Adornee = nil end
		C.fillBtn[1].Text = "SELECT TARGET VOLUME"
		C.fillBtn[1].TextColor3 = Theme.Text
	end
end

setMode = function(newMode)
	if currentMode == newMode then return end

	if currentMode == "Replace" then sourceAsset = nil; targetAsset = nil end
	if currentMode == "Erase" and newMode ~= "Erase" then eraseFilter = {} end
	lineStartPoint = nil
	if linePreviewPart then linePreviewPart.Parent = nil end
	if newMode ~= "Path" then clearPath() end

	currentMode = newMode
	updateModeButtonsUI()
	updatePreview()
	updateFillSelection()
end

-- Event Handling & Activation

local function onMove()
	if not active then return end
	updatePreview()
	if isPainting then
		local unitRay = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {previewFolder, getWorkspaceContainer(), pathPreviewFolder}
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
		if result and lastPaintPosition then
			local spacing = math.max(0.1, parseNumber(C.spacingBox[1].Text, 1.0))
			if (result.Position - lastPaintPosition).Magnitude >= spacing then
				if currentMode == "Paint" then paintAt(result.Position, result.Normal)
				elseif currentMode == "Erase" then eraseAt(result.Position)
				elseif currentMode == "Replace" then replaceAt(result.Position)
				end
				lastPaintPosition = result.Position
			end
		end
	end
end

local function onDown()
	if not active or not mouse then return end
	local center, normal, _ = findSurfacePositionAndNormal()

	-- For Volume Mode, we don't need a surface
	if currentMode == "Volume" then
		local unitRay = workspace.CurrentCamera:ViewportPointToRay(mouse.X, mouse.Y)
		local pos = unitRay.Origin + unitRay.Direction * 100
		paintInVolume(pos)
		return
	end

	if not center then return end

	if currentMode == "Line" then
		if not lineStartPoint then lineStartPoint = center
		else paintAlongLine(lineStartPoint, center); lineStartPoint = nil end
	elseif currentMode == "Path" then
		table.insert(pathPoints, center); updatePathPreview()
	elseif currentMode == "Paint" or currentMode == "Stamp" or currentMode == "Erase" or currentMode == "Replace" then
		if currentMode == "Paint" then paintAt(center, normal)
		elseif currentMode == "Stamp" then stampAt(center, normal)
		elseif currentMode == "Erase" then eraseAt(center)
		elseif currentMode == "Replace" then replaceAt(center)
		end

		if currentMode ~= "Stamp" then
			isPainting = true
			lastPaintPosition = center
		end
	end
end

local function onUp()
	isPainting = false
	lastPaintPosition = nil
end

local function updateOnOffButtonUI()
	if active then
		C.activationBtn.Text = "SYSTEM: ONLINE"
		C.activationBtn.TextColor3 = Theme.Background
		C.activationBtn.BackgroundColor3 = Theme.Success
		statusIndicator.BackgroundColor3 = Theme.Success
		titleLabel.Text = "SYSTEM: ONLINE // READY"
		titleLabel.TextColor3 = Theme.Success
	else
		C.activationBtn.Text = "ACTIVATE"
		C.activationBtn.TextColor3 = Theme.Text
		C.activationBtn.BackgroundColor3 = Theme.Background
		statusIndicator.BackgroundColor3 = Theme.Destructive
		titleLabel.Text = "SYSTEM: STANDBY"
		titleLabel.TextColor3 = Theme.Text
	end
end

activate = function()
	if active then return end
	active = true
	previewPart = Instance.new("Part")
	previewPart.Name = "BrushRadiusPreview"
	previewPart.Anchored = true; previewPart.CanCollide = false; previewPart.Transparency = 0.6; previewPart.Material = Enum.Material.Neon
	linePreviewPart = Instance.new("Part")
	linePreviewPart.Name = "BrushLinePreview"
	linePreviewPart.Anchored = true; linePreviewPart.CanCollide = false; linePreviewPart.Transparency = 0.5; linePreviewPart.Material = Enum.Material.Neon

	plugin:Activate(true)
	mouse = plugin:GetMouse()
	moveConn = mouse.Move:Connect(onMove)
	downConn = mouse.Button1Down:Connect(onDown)
	upConn = mouse.Button1Up:Connect(onUp)

	updatePreview()
	updateFillSelection()
	toolbarBtn:SetActive(true)
	updateOnOffButtonUI()
end

deactivate = function()
	if not active then return end
	active = false
	if moveConn then moveConn:Disconnect(); moveConn = nil end
	if downConn then downConn:Disconnect(); downConn = nil end
	if upConn then upConn:Disconnect(); upConn = nil end
	isPainting = false; lastPaintPosition = nil; lineStartPoint = nil
	clearPath(); mouse = nil
	if previewPart then previewPart:Destroy(); previewPart = nil; cyl = nil end
	if linePreviewPart then linePreviewPart:Destroy(); linePreviewPart = nil end
	if fillSelectionBox then fillSelectionBox.Adornee = nil end
	toolbarBtn:SetActive(false)
	updateOnOffButtonUI()
end

-- Final UI Connections

C.activationBtn.MouseButton1Click:Connect(function()
	if active then deactivate() else activate() end
end)

for mode, controls in pairs(C.modeButtons) do
	controls.Button.MouseButton1Click:Connect(function() setMode(mode) end)
end

C.addBtn[1].MouseButton1Click:Connect(addSelectedAssets)

C.savePresetBtn[1].MouseButton1Click:Connect(function()
	local name = trim(C.presetNameInput[1].Text)
	if name == "" then return end
	presets[name] = captureCurrentState()
	savePresetsToStorage()
	updatePresetUIList()
	C.presetNameInput[1].Text = ""
end)

local isClearingConfirm = false
C.clearBtn[1].MouseButton1Click:Connect(function()
	if not isClearingConfirm then
		isClearingConfirm = true
		C.clearBtn[1].Text = "CONFIRM CLEAR?"
		C.clearBtn[1].TextColor3 = Color3.fromRGB(255, 50, 50) -- Bright red warning
		task.delay(3, function()
			if isClearingConfirm then
				isClearingConfirm = false
				C.clearBtn[1].Text = "CLEAR ALL"
				C.clearBtn[1].TextColor3 = Theme.Destructive
			end
		end)
	else
		clearAssetList()
		isClearingConfirm = false
		C.clearBtn[1].Text = "CLEAR ALL"
		C.clearBtn[1].TextColor3 = Theme.Destructive
	end
end)



-- Input Connections (Persistence)
C.assetSettingsOffsetY[1].FocusLost:Connect(function()
	if selectedAssetInUI then
		assetOffsets[selectedAssetInUI] = parseNumber(C.assetSettingsOffsetY[1].Text, 0)
		persistOffsets()
	end
end)
C.assetSettingsWeight[1].FocusLost:Connect(function()
	if selectedAssetInUI then
		assetOffsets[selectedAssetInUI.."_weight"] = parseNumber(C.assetSettingsWeight[1].Text, 1)
		persistOffsets()
	end
end)
C.assetSettingsAlign[1].MouseButton1Click:Connect(function()
	if selectedAssetInUI then
		assetOffsets[selectedAssetInUI.."_align"] = not assetOffsets[selectedAssetInUI.."_align"]
		persistOffsets()
		updateAllToggles()
	end
end)
C.assetSettingsActive[1].MouseButton1Click:Connect(function()
	if selectedAssetInUI then
		local key = selectedAssetInUI.."_active"
		assetOffsets[key] = not (assetOffsets[key] ~= false)
		persistOffsets()
		updateAllToggles()
		updateAssetUIList()
	end
end)

-- Global Settings Toggles

C.smartSnapBtn[1].MouseButton1Click:Connect(function() smartSnapEnabled = not smartSnapEnabled; updateAllToggles() end)
C.snapToGridBtn[1].MouseButton1Click:Connect(function() snapToGridEnabled = not snapToGridEnabled; updateAllToggles() end)

-- Randomization Toggles
C.randomizeScaleToggle[1].MouseButton1Click:Connect(function() randomizeScaleEnabled = not randomizeScaleEnabled; updateAllToggles() end)
C.randomizeRotationToggle[1].MouseButton1Click:Connect(function() randomizeRotationEnabled = not randomizeRotationEnabled; updateAllToggles() end)
C.randomizeColorToggle[1].MouseButton1Click:Connect(function() randomizeColorEnabled = not randomizeColorEnabled; updateAllToggles() end)
C.randomizeTransparencyToggle[1].MouseButton1Click:Connect(function() randomizeTransparencyEnabled = not randomizeTransparencyEnabled; updateAllToggles() end)

C.gridSizeBox[1].FocusLost:Connect(function() gridSize = parseNumber(C.gridSizeBox[1].Text, 4) end)
C.ghostTransparencyBox[1].FocusLost:Connect(function() 
	ghostTransparency = math.clamp(parseNumber(C.ghostTransparencyBox[1].Text, 0.65), 0, 1) 
	C.ghostTransparencyBox[1].Text = tostring(ghostTransparency)
end)

toolbarBtn.Click:Connect(function() widget.Enabled = not widget.Enabled end)

C.newGroupBtn[1].MouseButton1Click:Connect(function()
	C.groupNameLabel[1].Visible = false
	C.groupNameInput.Visible = true
	C.groupNameInput.Text = ""
	C.groupNameInput:CaptureFocus()
end)

C.groupNameInput.FocusLost:Connect(function(enterPressed)
	local txt = trim(C.groupNameInput.Text)
	if txt == "" then
		C.groupNameInput.Visible = false
		C.groupNameLabel[1].Visible = true
		return
	end

	if assetsFolder:FindFirstChild(txt) then
		warn("Group name already exists!")
		C.groupNameInput.Visible = false
		C.groupNameLabel[1].Visible = true
		return 
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = txt
	newFolder.Parent = assetsFolder
	currentAssetGroup = txt

	C.groupNameInput.Visible = false
	C.groupNameLabel[1].Visible = true

	updateGroupUI()
	updateAssetUIList()
end)

local isDeletingGroupConfirm = false
C.deleteGroupBtn[1].MouseButton1Click:Connect(function()
	if currentAssetGroup == "Default" then return end

	if not isDeletingGroupConfirm then
		isDeletingGroupConfirm = true
		C.deleteGroupBtn[1].Text = "?"
		C.deleteGroupBtn[1].TextColor3 = Color3.fromRGB(255, 50, 50) -- Bright red
		task.delay(3, function()
			if isDeletingGroupConfirm then
				isDeletingGroupConfirm = false
				C.deleteGroupBtn[1].Text = "DEL"
				C.deleteGroupBtn[1].TextColor3 = Theme.Destructive
			end
		end)
	else
		local groupToDelete = assetsFolder:FindFirstChild(currentAssetGroup)
		if groupToDelete then
			groupToDelete:Destroy()
			currentAssetGroup = "Default"
			updateGroupUI()
			updateAssetUIList()

			-- Reset confirm state
			isDeletingGroupConfirm = false
			C.deleteGroupBtn[1].Text = "DEL"
			C.deleteGroupBtn[1].TextColor3 = Theme.Destructive
		end
	end
end)

C.groupNameLabel[1].MouseButton1Click:Connect(function()
	isGroupListView = not isGroupListView
	updateAssetUIList()
end)

-- Init
loadOffsets()
loadPresetsFromStorage()
migrateAssetsToGroup()
Selection.SelectionChanged:Connect(updateFillSelection)
updateAssetUIList()
updatePresetUIList()
updateGroupUI()
updateModeButtonsUI()
updateAllToggles()

-- Cleanup
plugin.Unloading:Connect(function()
	deactivate()
	if previewFolder then previewFolder:Destroy() end
	if pathPreviewFolder then pathPreviewFolder:Destroy() end
	if ghostModel then ghostModel:Destroy() end
end)

-- Global Preview Folders
previewFolder = workspace:FindFirstChild("_BrushPreview") or Instance.new("Folder", workspace); previewFolder.Name = "_BrushPreview"
pathPreviewFolder = workspace:FindFirstChild("_PathPreview") or Instance.new("Folder", workspace); pathPreviewFolder.Name = "_PathPreview"

-- Print Status
print("Brush Tool V8 // Cyber-Industrial UI Loaded.")
print("System Status: ONLINE")
