local UI = {}
local Selection = game:GetService("Selection")

-- Dependencies
local State, Constants, Utils, Core

UI.widget = nil
UI.C = {} -- Component references
UI.allTabs = {}

local Theme -- Shortcut

local function updateToggle(btn, inner, label, state, activeText, inactiveText)
	inner.Visible = state
	if state then
		inner.BackgroundColor3 = Theme.Accent
		if activeText then label.Text = activeText end
	else
		if inactiveText then label.Text = inactiveText end
	end
end

local function updateInputGroupEnabled(grid, enabled, randomizeBtn)
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
	if randomizeBtn then
		randomizeBtn[1].Active = enabled
		pcall(function() randomizeBtn[1].Interactable = enabled end)
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
		if btn:GetAttribute("IsSelected") then
			stroke.Color = Theme.AccentHover
			btn.BackgroundColor3 = Theme.AccentHover
			btn.TextColor3 = Theme.Background
		else
			stroke.Color = Theme.Accent
			btn.TextColor3 = Theme.Accent
		end
	end)
	btn.MouseLeave:Connect(function()
		if not btn.Active then return end
		if btn:GetAttribute("IsSelected") then
			stroke.Color = Theme.Accent
			btn.BackgroundColor3 = Theme.Accent
			btn.TextColor3 = Theme.Background
		else
			stroke.Color = Theme.Border
			btn.TextColor3 = Theme.Text
		end
	end)
	btn.MouseButton1Down:Connect(function()
		if not btn.Active then return end
		if btn:GetAttribute("IsSelected") then
			stroke.Color = Theme.Accent
			btn.BackgroundColor3 = Theme.Accent
		else
			stroke.Color = Theme.AccentHover
			btn.BackgroundColor3 = Theme.Border
			btn.TextColor3 = Theme.Accent
		end
	end)
	btn.MouseButton1Up:Connect(function()
		if not btn.Active then return end
		if btn:GetAttribute("IsSelected") then
			stroke.Color = Theme.AccentHover
			btn.BackgroundColor3 = Theme.AccentHover
		else
			stroke.Color = Theme.Accent
			btn.BackgroundColor3 = Theme.Panel
			btn.TextColor3 = Theme.Accent
		end
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

	return btn, inner, label, container
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

local function createCollapsibleSection(text, parent, isOpen, layoutOrder)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.BackgroundTransparency = 1
	if layoutOrder then container.LayoutOrder = layoutOrder end
	container.Parent = parent

	-- Layout for the container (Header + Content)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = container

	-- Header Button
	local headerBtn = Instance.new("TextButton")
	headerBtn.LayoutOrder = 1
	headerBtn.Size = UDim2.new(1, 0, 0, 28)
	headerBtn.BackgroundColor3 = Theme.Panel
	headerBtn.AutoButtonColor = false
	headerBtn.Text = ""
	headerBtn.Parent = container

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = Theme.Border
	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerStroke.Parent = headerBtn

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 28, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Text = isOpen and "v" or ">"
	icon.Font = Theme.FontTech
	icon.TextSize = 12
	icon.TextColor3 = Theme.Accent
	icon.Parent = headerBtn

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -36, 1, 0)
	title.Position = UDim2.new(0, 32, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = string.upper(text)
	title.Font = Theme.FontTech
	title.TextSize = 12
	title.TextColor3 = Theme.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = headerBtn

	-- Content Frame
	local content = Instance.new("Frame")
	content.LayoutOrder = 2
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Visible = isOpen
	content.Parent = container

	-- Padding inside content
	local contentPad = Instance.new("UIPadding")
	contentPad.PaddingTop = UDim.new(0, 8)
	contentPad.PaddingBottom = UDim.new(0, 8)
	contentPad.PaddingLeft = UDim.new(0, 4)
	contentPad.PaddingRight = UDim.new(0, 4)
	contentPad.Parent = content

	-- List layout for content items
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.Parent = content

	-- Toggle Logic
	headerBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		content.Visible = isOpen
		icon.Text = isOpen and "v" or ">"
		if isOpen then
			headerBtn.BackgroundColor3 = Color3.fromHex("2a2a2a")
			title.TextColor3 = Theme.Accent
		else
			headerBtn.BackgroundColor3 = Theme.Panel
			title.TextColor3 = Theme.Text
		end
	end)

	-- Hover Effect
	headerBtn.MouseEnter:Connect(function()
		if not isOpen then headerBtn.BackgroundColor3 = Color3.fromHex("252525") end
	end)
	headerBtn.MouseLeave:Connect(function()
		if not isOpen then headerBtn.BackgroundColor3 = Theme.Panel end
	end)

	return container, content
end

local function switchTab(tabName)
	for _, t in pairs(UI.allTabs) do
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

local function createTab(name, label, tabBar, tabContent)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.25, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = label
	btn.Font = Theme.FontHeader
	-- Updated for better fit
	btn.TextScaled = true
	btn.TextColor3 = Theme.TextDim
	btn.ClipsDescendants = true
	btn.Parent = tabBar

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MaxTextSize = 12
	sizeConstraint.Parent = btn

	-- Padding to prevent text touching borders
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = btn

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
	frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
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
	table.insert(UI.allTabs, {Name = name, Button = btn, Indicator = indicator, Frame = frame})
	return {frame = frame}
end

local function createOrderedRandomizerGroup(parent, toggleText, layoutOrder)
	local container = Instance.new("Frame")
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Size = UDim2.new(1, 0, 0, 0)
	container.BackgroundTransparency = 1
	if layoutOrder then container.LayoutOrder = layoutOrder end
	container.Parent = parent

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

function UI.init(plugin, pState, pConstants, pUtils)
	State = pState
	Constants = pConstants
	Utils = pUtils
	Theme = Constants.Theme

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false, false, 400, 650, 350, 400
	)
	UI.widget = plugin:CreateDockWidgetPluginGui("BrushToolWidgetV8", widgetInfo)
	UI.widget.Title = "BRUSH TOOL // PROTOCOL"

	UI.buildInterface()
	UI.updateAllToggles()
	UI.updateModeButtonsUI()
	UI.updateGroupUI()
	UI.updateAssetUIList()
end

function UI.setCore(pCore)
	Core = pCore
end

function UI.buildInterface()
	local uiRoot = Instance.new("Frame")
	uiRoot.Size = UDim2.new(1, 0, 1, 0)
	uiRoot.BackgroundColor3 = Theme.Background
	uiRoot.Parent = UI.widget

	-- Top Bar
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 40)
	topBar.BackgroundColor3 = Theme.Panel
	topBar.BorderSizePixel = 0
	topBar.Parent = uiRoot

	UI.statusIndicator = Instance.new("Frame")
	UI.statusIndicator.Size = UDim2.new(0, 8, 0, 8)
	UI.statusIndicator.Position = UDim2.new(0, 12, 0.5, -4)
	UI.statusIndicator.BackgroundColor3 = Theme.Destructive
	UI.statusIndicator.Parent = topBar
	Instance.new("UICorner", UI.statusIndicator).CornerRadius = UDim.new(1, 0)

	UI.titleLabel = Instance.new("TextLabel")
	UI.titleLabel.Size = UDim2.new(1, -40, 1, 0)
	UI.titleLabel.Position = UDim2.new(0, 28, 0, 0)
	UI.titleLabel.BackgroundTransparency = 1
	UI.titleLabel.Text = "SYSTEM: STANDBY"
	UI.titleLabel.Font = Theme.FontTech
	UI.titleLabel.TextSize = 14
	UI.titleLabel.TextColor3 = Theme.Text
	UI.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	UI.titleLabel.Parent = topBar

	UI.C.activationBtn = Instance.new("TextButton")
	UI.C.activationBtn.Size = UDim2.new(0, 100, 0, 24)
	UI.C.activationBtn.AnchorPoint = Vector2.new(1, 0.5)
	UI.C.activationBtn.Position = UDim2.new(1, -12, 0.5, 0)
	UI.C.activationBtn.BackgroundColor3 = Theme.Background
	UI.C.activationBtn.Text = "ACTIVATE"
	UI.C.activationBtn.Font = Theme.FontHeader
	UI.C.activationBtn.TextSize = 11
	UI.C.activationBtn.TextColor3 = Theme.Text
	UI.C.activationBtn.Parent = topBar
	Instance.new("UIStroke", UI.C.activationBtn).Color = Theme.Border

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

	-- Shortened labels for better fit
	local TabTools = createTab("Tools", "TOOLS", tabBar, tabContent)
	local TabAssets = createTab("Assets", "ASSETS", tabBar, tabContent)
	local TabPresets = createTab("Presets", "PRESETS", tabBar, tabContent)
	local TabTuning = createTab("Tuning", "TUNING", tabBar, tabContent)

	-- TOOLS TAB
	-- OUTPUT SETTINGS UI
	createSectionHeader("OUTPUT ORGANIZATION", TabTools.frame)
	local outputFrame = Instance.new("Frame")
	outputFrame.Size = UDim2.new(1, 0, 0, 0)
	outputFrame.AutomaticSize = Enum.AutomaticSize.Y
	outputFrame.BackgroundTransparency = 1
	outputFrame.Parent = TabTools.frame
	local ol = Instance.new("UIListLayout")
	ol.Padding = UDim.new(0, 8)
	ol.Parent = outputFrame

	UI.C.outputModeBtn = {createTechButton("MODE: PER STROKE", outputFrame)}
	UI.C.outputFolderNameInput = {createTechInput("FOLDER NAME", "BrushOutput", outputFrame)}

	-- Initial State
	UI.C.outputFolderNameInput[2].Visible = false

	UI.C.outputModeBtn[1].MouseButton1Click:Connect(function()
		if State.Output.Mode == "PerStroke" then
			State.Output.Mode = "Fixed"
			UI.C.outputModeBtn[1].Text = "MODE: FIXED FOLDER"
			UI.C.outputFolderNameInput[2].Visible = true
		elseif State.Output.Mode == "Fixed" then
			State.Output.Mode = "Grouped"
			UI.C.outputModeBtn[1].Text = "MODE: GROUP BY ASSET"
			UI.C.outputFolderNameInput[2].Visible = false
		else
			State.Output.Mode = "PerStroke"
			UI.C.outputModeBtn[1].Text = "MODE: PER STROKE"
			UI.C.outputFolderNameInput[2].Visible = false
		end
	end)

	UI.C.outputFolderNameInput[1].FocusLost:Connect(function()
		local txt = Utils.trim(UI.C.outputFolderNameInput[1].Text)
		if txt == "" then txt = "BrushOutput" end
		State.Output.FixedFolderName = txt
		UI.C.outputFolderNameInput[1].Text = txt
	end)

	createSectionHeader("MODE SELECT", TabTools.frame)
	local modeGrid = Instance.new("Frame")
	modeGrid.Size = UDim2.new(1, 0, 0, 0)
	modeGrid.AutomaticSize = Enum.AutomaticSize.Y
	modeGrid.BackgroundTransparency = 1
	modeGrid.Parent = TabTools.frame
	local mgLayout = Instance.new("UIGridLayout")
	mgLayout.CellSize = UDim2.new(0.48, 0, 0, 36)
	mgLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	mgLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mgLayout.Parent = modeGrid

	UI.C.modeButtons = {}
	local modeNames = {"Paint", "Line", "Path", "Fill", "Replace", "Stamp", "Volume", "Erase"}
	for _, m in ipairs(modeNames) do
		local b, s = createTechButton(string.upper(m), modeGrid)
		b.TextSize = 11
		UI.C.modeButtons[m] = {Button = b, Stroke = s}
	end

	createSectionHeader("BRUSH PARAMETERS", TabTools.frame)
	local brushParamsContainer = Instance.new("Frame")
	brushParamsContainer.Size = UDim2.new(1, 0, 0, 0)
	brushParamsContainer.AutomaticSize = Enum.AutomaticSize.Y
	brushParamsContainer.BackgroundTransparency = 1
	brushParamsContainer.Parent = TabTools.frame
	local bpLayout = Instance.new("UIGridLayout")
	bpLayout.CellSize = UDim2.new(0.48, 0, 0, 40)
	bpLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	bpLayout.Parent = brushParamsContainer

	UI.C.radiusBox = {createTechInput("RADIUS (Studs)", "10", brushParamsContainer)}
	UI.C.densityBox = {createTechInput("DENSITY (Count)", "10", brushParamsContainer)}
	UI.C.spacingBox = {createTechInput("SPACING (Studs)", "1.5", brushParamsContainer)}
	UI.C.distanceBox = {createTechInput("DISTANCE (Studs)", "30", brushParamsContainer)}

	UI.C.contextContainer = Instance.new("Frame")
	UI.C.contextContainer.Size = UDim2.new(1, 0, 0, 0)
	UI.C.contextContainer.AutomaticSize = Enum.AutomaticSize.Y
	UI.C.contextContainer.BackgroundTransparency = 1
	UI.C.contextContainer.Parent = TabTools.frame

	-- Path Context
	UI.C.pathFrame = Instance.new("Frame")
	UI.C.pathFrame.AutomaticSize = Enum.AutomaticSize.Y
	UI.C.pathFrame.Size = UDim2.new(1, 0, 0, 0)
	UI.C.pathFrame.BackgroundTransparency = 1
	UI.C.pathFrame.Visible = false
	UI.C.pathFrame.Parent = UI.C.contextContainer
	local pathLayout = Instance.new("UIListLayout", UI.C.pathFrame)
	pathLayout.Padding = UDim.new(0, 8)
	pathLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local pathHeader = createSectionHeader("PATH SETTINGS", UI.C.pathFrame)
	pathHeader.LayoutOrder = 1
	local pathBtnGrid = Instance.new("Frame")
	pathBtnGrid.LayoutOrder = 2
	pathBtnGrid.Size = UDim2.new(1, 0, 0, 32)
	pathBtnGrid.BackgroundTransparency = 1
	pathBtnGrid.Parent = UI.C.pathFrame
	local pgl = Instance.new("UIGridLayout")
	pgl.CellSize = UDim2.new(0.48, 0, 0, 32)
	pgl.CellPadding = UDim2.new(0.04, 0, 0, 0)
	pgl.Parent = pathBtnGrid
	UI.C.applyPathBtn = {createTechButton("GENERATE", pathBtnGrid)}
	UI.C.clearPathBtn = {createTechButton("CLEAR", pathBtnGrid)}
	UI.C.clearPathBtn[1].TextColor3 = Theme.Destructive

	-- Path Undo/Redo
	local pathHistoryGrid = Instance.new("Frame")
	pathHistoryGrid.LayoutOrder = 3
	pathHistoryGrid.Size = UDim2.new(1, 0, 0, 32)
	pathHistoryGrid.BackgroundTransparency = 1
	pathHistoryGrid.Parent = UI.C.pathFrame
	local phgl = Instance.new("UIGridLayout")
	phgl.CellSize = UDim2.new(0.48, 0, 0, 32)
	phgl.CellPadding = UDim2.new(0.04, 0, 0, 0)
	phgl.Parent = pathHistoryGrid

	UI.C.undoPathBtn = {createTechButton("UNDO", pathHistoryGrid)}
	UI.C.redoPathBtn = {createTechButton("REDO", pathHistoryGrid)}

	UI.C.undoPathBtn[1].MouseButton1Click:Connect(function()
		if Core and Core.pathUndo then Core.pathUndo() end
	end)

	UI.C.redoPathBtn[1].MouseButton1Click:Connect(function()
		if Core and Core.pathRedo then Core.pathRedo() end
	end)

	-- Fill Context
	UI.C.fillFrame = Instance.new("Frame")
	UI.C.fillFrame.AutomaticSize = Enum.AutomaticSize.Y
	UI.C.fillFrame.Size = UDim2.new(1, 0, 0, 0)
	UI.C.fillFrame.BackgroundTransparency = 1
	UI.C.fillFrame.Visible = false
	UI.C.fillFrame.Parent = UI.C.contextContainer
	UI.C.fillBtn = {createTechButton("SELECT TARGET VOLUME", UI.C.fillFrame)}

	-- Eraser Context
	UI.C.eraserFrame = Instance.new("Frame")
	UI.C.eraserFrame.AutomaticSize = Enum.AutomaticSize.Y
	UI.C.eraserFrame.Size = UDim2.new(1, 0, 0, 0)
	UI.C.eraserFrame.BackgroundTransparency = 1
	UI.C.eraserFrame.Visible = false
	UI.C.eraserFrame.Parent = UI.C.contextContainer

	UI.C.eraserFilterBtn = {createTechToggle("Filter: Everything", UI.C.eraserFrame)}

	UI.C.eraserFilterBtn[1].MouseButton1Click:Connect(function()
		if State.SmartEraser.FilterMode == "All" then
			State.SmartEraser.FilterMode = "CurrentGroup"
			updateToggle(UI.C.eraserFilterBtn[1], UI.C.eraserFilterBtn[2], UI.C.eraserFilterBtn[3], true, "Filter: Current Group", "Filter: Everything")
		elseif State.SmartEraser.FilterMode == "CurrentGroup" then
			State.SmartEraser.FilterMode = "ActiveOnly"
			updateToggle(UI.C.eraserFilterBtn[1], UI.C.eraserFilterBtn[2], UI.C.eraserFilterBtn[3], true, "Filter: Active Only", "Filter: Everything")
		else
			State.SmartEraser.FilterMode = "All"
			updateToggle(UI.C.eraserFilterBtn[1], UI.C.eraserFilterBtn[2], UI.C.eraserFilterBtn[3], false, "Filter: Current Group", "Filter: Everything")
		end
	end)

	-- ASSETS TAB
	createSectionHeader("ASSET GROUPS", TabAssets.frame)
	local groupActions = Instance.new("Frame")
	groupActions.Size = UDim2.new(1, 0, 0, 32)
	groupActions.BackgroundTransparency = 1
	groupActions.Parent = TabAssets.frame
	groupActions.ZIndex = 10
	local gal = Instance.new("UIListLayout")
	gal.FillDirection = Enum.FillDirection.Horizontal
	gal.Parent = groupActions

	UI.C.groupNameLabel = {createTechButton("GROUP: DEFAULT", groupActions)}
	UI.C.groupNameLabel[1].Size = UDim2.new(1, 0, 1, 0)
	UI.C.groupNameLabel[1].AutoButtonColor = true

	UI.C.groupNameInput = Instance.new("TextBox")
	UI.C.groupNameInput.Size = UDim2.new(1, 0, 1, 0)
	UI.C.groupNameInput.BackgroundColor3 = Theme.Background
	UI.C.groupNameInput.TextColor3 = Theme.Accent
	UI.C.groupNameInput.Font = Theme.FontTech
	UI.C.groupNameInput.TextSize = 14
	UI.C.groupNameInput.Text = ""
	UI.C.groupNameInput.PlaceholderText = "ENTER NAME..."
	UI.C.groupNameInput.Visible = false
	UI.C.groupNameInput.Parent = groupActions
	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = Theme.Accent
	inputStroke.Thickness = 1
	inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inputStroke.Parent = UI.C.groupNameInput

	local groupButtonsContainer = Instance.new("Frame")
	groupButtonsContainer.Size = UDim2.new(1, 0, 0, 32)
	groupButtonsContainer.BackgroundTransparency = 1
	groupButtonsContainer.Parent = TabAssets.frame
	local gbl = Instance.new("UIGridLayout")
	gbl.CellSize = UDim2.new(0.5, -2, 1, 0)
	gbl.CellPadding = UDim2.new(0, 4, 0, 0)
	gbl.Parent = groupButtonsContainer

	UI.C.newGroupBtn = {createTechButton("ADD", groupButtonsContainer)}
	UI.C.newGroupBtn[1].Size = UDim2.new(1, 0, 1, 0)
	UI.C.newGroupBtn[1].TextColor3 = Theme.Success

	UI.C.deleteGroupBtn = {createTechButton("DEL", groupButtonsContainer)}
	UI.C.deleteGroupBtn[1].Size = UDim2.new(1, 0, 1, 0)
	UI.C.deleteGroupBtn[1].TextColor3 = Theme.Destructive

	createSectionHeader("ASSET MANAGEMENT", TabAssets.frame)
	local assetActions = Instance.new("Frame")
	assetActions.Size = UDim2.new(1, 0, 0, 32)
	assetActions.BackgroundTransparency = 1
	assetActions.Parent = TabAssets.frame
	local aal = Instance.new("UIListLayout")
	aal.FillDirection = Enum.FillDirection.Horizontal
	aal.Padding = UDim.new(0, 8)
	aal.Parent = assetActions
	UI.C.addBtn = {createTechButton("+ ADD SELECTED", assetActions)}
	UI.C.addBtn[1].Size = UDim2.new(0.5, -4, 1, 0)
	UI.C.addBtn[1].TextColor3 = Theme.Success
	UI.C.clearBtn = {createTechButton("CLEAR ALL", assetActions)}
	UI.C.clearBtn[1].Size = UDim2.new(0.5, -4, 1, 0)
	UI.C.clearBtn[1].TextColor3 = Theme.Destructive

	UI.C.assetListFrame = Instance.new("Frame")
	UI.C.assetListFrame.Size = UDim2.new(1, 0, 0, 0)
	UI.C.assetListFrame.AutomaticSize = Enum.AutomaticSize.Y
	UI.C.assetListFrame.BackgroundTransparency = 1
	UI.C.assetListFrame.Parent = TabAssets.frame
	local alGrid = Instance.new("UIGridLayout")
	alGrid.CellSize = UDim2.new(0.48, 0, 0, 100)
	alGrid.CellPadding = UDim2.new(0.03, 0, 0, 8)
	alGrid.Parent = UI.C.assetListFrame

	UI.C.assetSettingsFrame = Instance.new("Frame")
	UI.C.assetSettingsFrame.Size = UDim2.new(1, 0, 0, 0)
	UI.C.assetSettingsFrame.AutomaticSize = Enum.AutomaticSize.Y
	UI.C.assetSettingsFrame.BackgroundTransparency = 1
	UI.C.assetSettingsFrame.Visible = false
	UI.C.assetSettingsFrame.Parent = TabAssets.frame
	Instance.new("UIListLayout", UI.C.assetSettingsFrame).Padding = UDim.new(0, 8)
	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.BackgroundColor3 = Theme.Border
	sep.BorderSizePixel = 0
	sep.Parent = UI.C.assetSettingsFrame
	UI.C.assetSettingsName = createSectionHeader("SELECTED: ???", UI.C.assetSettingsFrame)
	local asGrid = Instance.new("Frame")
	asGrid.Size = UDim2.new(1, 0, 0, 0)
	asGrid.AutomaticSize = Enum.AutomaticSize.Y
	asGrid.BackgroundTransparency = 1
	asGrid.Parent = UI.C.assetSettingsFrame
	local asgl = Instance.new("UIGridLayout")
	asgl.CellSize = UDim2.new(0.48, 0, 0, 40)
	asgl.CellPadding = UDim2.new(0.04, 0, 0, 8)
	asgl.Parent = asGrid
	UI.C.assetSettingsOffsetY = {createTechInput("Y-OFFSET", "0", asGrid)}
	UI.C.assetSettingsWeight = {createTechInput("PROBABILITY", "1", asGrid)}
	UI.C.assetSettingsBaseScale = {createTechInput("BASE SCALE", "1", asGrid)}
	UI.C.assetSettingsBaseRotation = {createTechInput("BASE ROT (Y)", "0", asGrid)}
	UI.C.assetSettingsBaseRotationX = {createTechInput("BASE ROT (X)", "0", asGrid)}

	UI.C.assetSettingsActive = {createTechToggle("Active in Brush", UI.C.assetSettingsFrame)}

	UI.C.assetSettingsActive[1].MouseButton1Click:Connect(function()
		if State.selectedAssetInUI then
			local key = State.selectedAssetInUI .. "_active"
			local current = State.assetOffsets[key]
			if current == nil then current = true end
			State.assetOffsets[key] = not current
			State.persistOffsets()
			UI.updateAllToggles()
			UI.updateAssetUIList()
		end
	end)

	UI.C.assetSettingsOffsetY[1].FocusLost:Connect(function()
		if State.selectedAssetInUI then
			local val = Utils.parseNumber(UI.C.assetSettingsOffsetY[1].Text, 0)
			State.assetOffsets[State.selectedAssetInUI] = val
			State.persistOffsets()
		end
	end)

	UI.C.assetSettingsBaseScale[1].FocusLost:Connect(function()
		if State.selectedAssetInUI then
			local val = Utils.parseNumber(UI.C.assetSettingsBaseScale[1].Text, 1)
			State.assetOffsets[State.selectedAssetInUI .. "_scale"] = val
			State.persistOffsets()
		end
	end)

	UI.C.assetSettingsBaseRotation[1].FocusLost:Connect(function()
		if State.selectedAssetInUI then
			local val = Utils.parseNumber(UI.C.assetSettingsBaseRotation[1].Text, 0)
			State.assetOffsets[State.selectedAssetInUI .. "_rotation"] = val
			State.persistOffsets()
		end
	end)

	UI.C.assetSettingsBaseRotationX[1].FocusLost:Connect(function()
		if State.selectedAssetInUI then
			local val = Utils.parseNumber(UI.C.assetSettingsBaseRotationX[1].Text, 0)
			State.assetOffsets[State.selectedAssetInUI .. "_rotationX"] = val
			State.persistOffsets()
		end
	end)

	UI.C.assetSettingsWeight[1].FocusLost:Connect(function()
		if State.selectedAssetInUI then
			local val = Utils.parseNumber(UI.C.assetSettingsWeight[1].Text, 1)
			State.assetOffsets[State.selectedAssetInUI .. "_weight"] = val
			State.persistOffsets()
		end
	end)

	-- PRESETS TAB
	createSectionHeader("NEW PRESET", TabPresets.frame)
	local presetCreationFrame = Instance.new("Frame")
	presetCreationFrame.Size = UDim2.new(1, 0, 0, 80)
	presetCreationFrame.BackgroundTransparency = 1
	presetCreationFrame.Parent = TabPresets.frame
	local pcl = Instance.new("UIListLayout")
	pcl.Padding = UDim.new(0, 8)
	pcl.Parent = presetCreationFrame

	UI.C.presetNameInput = {createTechInput("PRESET NAME", "", presetCreationFrame)}
	UI.C.savePresetBtn = {createTechButton("SAVE CURRENT CONFIG", presetCreationFrame)}
	UI.C.savePresetBtn[1].TextColor3 = Theme.Success

	createSectionHeader("SAVED PROFILES", TabPresets.frame)
	UI.C.presetListFrame = Instance.new("Frame")
	UI.C.presetListFrame.Size = UDim2.new(1, 0, 0, 300)
	UI.C.presetListFrame.BackgroundTransparency = 1
	UI.C.presetListFrame.Parent = TabPresets.frame
	local plGrid = Instance.new("UIGridLayout")
	plGrid.CellSize = UDim2.new(1, 0, 0, 36)
	plGrid.CellPadding = UDim2.new(0, 0, 0, 4)
	plGrid.Parent = UI.C.presetListFrame

	-- TUNING TAB
	local tuningLayoutOrder = 1

	-- TRANSFORMATION RANDOMIZER SECTION
	local randWrapper, randContent = createCollapsibleSection("TRANSFORMATION RANDOMIZER", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1

	local randOrder = 1
	-- Scale
	UI.C.randomizeScaleToggle, UI.C.scaleGrid, UI.C.randomizeScaleBtn = createOrderedRandomizerGroup(randContent, "Randomize Scale", randOrder)
	randOrder = randOrder + 1
	UI.C.scaleMinBox = {createTechInput("SCALE MIN", "0.8", UI.C.scaleGrid)}
	UI.C.scaleMaxBox = {createTechInput("SCALE MAX", "1.2", UI.C.scaleGrid)}

	-- Rotation
	UI.C.randomizeRotationToggle, UI.C.rotationGrid, UI.C.randomizeRotationBtn = createOrderedRandomizerGroup(randContent, "Randomize Rotation (X/Z)", randOrder)
	randOrder = randOrder + 1
	UI.C.rotXMinBox = {createTechInput("ROT X MIN", "0", UI.C.rotationGrid)}
	UI.C.rotXMaxBox = {createTechInput("ROT X MAX", "0", UI.C.rotationGrid)}
	UI.C.rotZMinBox = {createTechInput("ROT Z MIN", "0", UI.C.rotationGrid)}
	UI.C.rotZMaxBox = {createTechInput("ROT Z MAX", "0", UI.C.rotationGrid)}

	-- Color
	UI.C.randomizeColorToggle, UI.C.colorGrid, UI.C.randomizeColorBtn = createOrderedRandomizerGroup(randContent, "Randomize Color (HSV)", randOrder)
	randOrder = randOrder + 1
	UI.C.hueMinBox = {createTechInput("HUE MIN", "0", UI.C.colorGrid)}
	UI.C.hueMaxBox = {createTechInput("HUE MAX", "0", UI.C.colorGrid)}
	UI.C.satMinBox = {createTechInput("SAT MIN", "0", UI.C.colorGrid)}
	UI.C.satMaxBox = {createTechInput("SAT MAX", "0", UI.C.colorGrid)}
	UI.C.valMinBox = {createTechInput("VAL MIN", "0", UI.C.colorGrid)}
	UI.C.valMaxBox = {createTechInput("VAL MAX", "0", UI.C.colorGrid)}

	-- Transparency
	UI.C.randomizeTransparencyToggle, UI.C.transparencyGrid, UI.C.randomizeTransparencyBtn = createOrderedRandomizerGroup(randContent, "Randomize Transparency", randOrder)
	randOrder = randOrder + 1
	UI.C.transMinBox = {createTechInput("TRNS MIN", "0", UI.C.transparencyGrid)}
	UI.C.transMaxBox = {createTechInput("TRNS MAX", "0", UI.C.transparencyGrid)}

	-- Wobble
	UI.C.randomizeWobbleToggle, UI.C.wobbleGrid, UI.C.randomizeWobbleBtn = createOrderedRandomizerGroup(randContent, "Wobble (Tilt)", randOrder)
	randOrder = randOrder + 1
	UI.C.wobbleXMaxBox = {createTechInput("X ANGLE (Deg)", "0", UI.C.wobbleGrid)}
	UI.C.wobbleZMaxBox = {createTechInput("Z ANGLE (Deg)", "0", UI.C.wobbleGrid)}

	-- ENVIRONMENT CONTROL SECTION
	local envWrapper, envContent = createCollapsibleSection("ENVIRONMENT CONTROL", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local envOrder = 1

	UI.C.smartSnapBtn = {createTechToggle("Smart Surface Snap", envContent)}
	UI.C.smartSnapBtn[4].LayoutOrder = envOrder; envOrder = envOrder + 1

	UI.C.snapToGridBtn = {createTechToggle("Snap to Grid", envContent)}
	UI.C.snapToGridBtn[4].LayoutOrder = envOrder; envOrder = envOrder + 1

	UI.C.gridSizeBox = {createTechInput("GRID SIZE", "4", envContent)}
	UI.C.gridSizeBox[2].LayoutOrder = envOrder; envOrder = envOrder + 1

	UI.C.ghostTransparencyBox = {createTechInput("GHOST TRANS", "0.65", envContent)}
	UI.C.ghostTransparencyBox[2].LayoutOrder = envOrder; envOrder = envOrder + 1

	UI.C.ghostLimitBox = {createTechInput("GHOST LIMIT", "20", envContent)}
	UI.C.ghostLimitBox[2].LayoutOrder = envOrder; envOrder = envOrder + 1


	-- SURFACE LOCK SECTION
	local surfWrapper, surfContent = createCollapsibleSection("SURFACE LOCK", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local surfOrder = 1

	UI.C.assetSettingsAlign = {createTechToggle("Align Asset to Surface", surfContent)}
	UI.C.assetSettingsAlign[4].LayoutOrder = surfOrder; surfOrder = surfOrder + 1

	UI.C.assetSettingsAlign[1].MouseButton1Click:Connect(function()
		State.alignToSurface = not State.alignToSurface
		UI.updateAllToggles()
	end)

	local surfaceGrid = Instance.new("Frame")
	surfaceGrid.Size = UDim2.new(1, 0, 0, 80)
	surfaceGrid.BackgroundTransparency = 1
	surfaceGrid.LayoutOrder = surfOrder; surfOrder = surfOrder + 1
	surfaceGrid.Parent = surfContent
	local slLayout = Instance.new("UIGridLayout")
	slLayout.CellSize = UDim2.new(0.48, 0, 0, 32)
	slLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	slLayout.Parent = surfaceGrid

	UI.C.surfaceButtons = {}
	local surfaceModes = {"Off", "Floor", "Wall", "Ceiling"}
	for _, m in ipairs(surfaceModes) do
		local b, s = createTechButton(string.upper(m), surfaceGrid)
		UI.C.surfaceButtons[m] = {Button = b, Stroke = s}
		b.MouseButton1Click:Connect(function()
			State.surfaceAngleMode = m
			UI.updateAllToggles()
		end)
	end

	-- MATERIAL FILTER UI SECTION
	local matWrapper, matContent = createCollapsibleSection("SURFACE MATERIAL FILTER", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local matOrder = 1

	UI.C.materialFilterToggle = {createTechToggle("Enable Material Filter", matContent)}
	UI.C.materialFilterToggle[4].LayoutOrder = matOrder; matOrder = matOrder + 1

	UI.C.materialFilterToggle[1].MouseButton1Click:Connect(function()
		State.MaterialFilter.Enabled = not State.MaterialFilter.Enabled
		UI.updateAllToggles()
	end)

	local matFilterContainer = Instance.new("Frame")
	matFilterContainer.Size = UDim2.new(1, 0, 0, 160)
	matFilterContainer.BackgroundTransparency = 1
	matFilterContainer.LayoutOrder = matOrder; matOrder = matOrder + 1
	matFilterContainer.Parent = matContent

	local mfTools = Instance.new("Frame")
	mfTools.Size = UDim2.new(1, 0, 0, 24)
	mfTools.BackgroundTransparency = 1
	mfTools.Parent = matFilterContainer

	local mfToolsLayout = Instance.new("UIListLayout")
	mfToolsLayout.FillDirection = Enum.FillDirection.Horizontal
	mfToolsLayout.Padding = UDim.new(0, 8)
	mfToolsLayout.Parent = mfTools

	local selectAllMat = Instance.new("TextButton")
	selectAllMat.Size = UDim2.new(0.5, -4, 1, 0)
	selectAllMat.BackgroundColor3 = Theme.Panel
	selectAllMat.Text = "SELECT ALL"
	selectAllMat.Font = Theme.FontTech
	selectAllMat.TextSize = 10
	selectAllMat.TextColor3 = Theme.Text
	selectAllMat.Parent = mfTools
	Instance.new("UIStroke", selectAllMat).Color = Theme.Border

	local selectNoneMat = Instance.new("TextButton")
	selectNoneMat.Size = UDim2.new(0.5, -4, 1, 0)
	selectNoneMat.BackgroundColor3 = Theme.Panel
	selectNoneMat.Text = "SELECT NONE"
	selectNoneMat.Font = Theme.FontTech
	selectNoneMat.TextSize = 10
	selectNoneMat.TextColor3 = Theme.Text
	selectNoneMat.Parent = mfTools
	Instance.new("UIStroke", selectNoneMat).Color = Theme.Border

	local matListScroll = Instance.new("ScrollingFrame")
	matListScroll.Size = UDim2.new(1, 0, 1, -28)
	matListScroll.Position = UDim2.new(0, 0, 0, 28)
	matListScroll.BackgroundTransparency = 1
	matListScroll.BackgroundColor3 = Theme.Panel -- Slight bg for list
	matListScroll.BackgroundTransparency = 0.8
	matListScroll.ScrollBarThickness = 4
	matListScroll.ScrollBarImageColor3 = Theme.Border
	matListScroll.Parent = matFilterContainer

	local matListLayout = Instance.new("UIGridLayout")
	matListLayout.CellSize = UDim2.new(0.48, 0, 0, 24)
	matListLayout.CellPadding = UDim2.new(0.04, 0, 0, 4)
	matListLayout.Parent = matListScroll

	UI.C.materialButtons = {}

	local allMaterials = Enum.Material:GetEnumItems()
	table.sort(allMaterials, function(a,b) return a.Name < b.Name end)

	for _, mat in ipairs(allMaterials) do
		-- Skip Air or other non-surface mats if needed, but keeping all is safer
		if mat ~= Enum.Material.Air then
			local btn = Instance.new("TextButton")
			btn.BackgroundColor3 = Theme.Panel
			btn.Text = ""
			btn.Parent = matListScroll

			local stroke = Instance.new("UIStroke")
			stroke.Color = Theme.Border
			stroke.Parent = btn

			local check = Instance.new("Frame")
			check.Size = UDim2.new(0, 14, 0, 14)
			check.Position = UDim2.new(0, 5, 0.5, -7)
			check.BackgroundColor3 = Theme.Background
			check.BorderSizePixel = 0
			check.Parent = btn
			local checkStroke = Instance.new("UIStroke")
			checkStroke.Color = Theme.Border
			checkStroke.Parent = check

			local innerCheck = Instance.new("Frame")
			innerCheck.Size = UDim2.new(1, -4, 1, -4)
			innerCheck.Position = UDim2.new(0, 2, 0, 2)
			innerCheck.BackgroundColor3 = Theme.Accent
			innerCheck.BorderSizePixel = 0
			innerCheck.Visible = false -- Toggled
			innerCheck.Parent = check

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -24, 1, 0)
			label.Position = UDim2.new(0, 24, 0, 0)
			label.BackgroundTransparency = 1
			label.Text = mat.Name
			label.Font = Theme.FontMain
			label.TextSize = 10
			label.TextColor3 = Theme.TextDim
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Parent = btn

			UI.C.materialButtons[mat] = {Button = btn, Inner = innerCheck, Label = label}

			btn.MouseButton1Click:Connect(function()
				if State.MaterialFilter.Whitelist[mat] then
					State.MaterialFilter.Whitelist[mat] = nil
				else
					State.MaterialFilter.Whitelist[mat] = true
				end
				UI.updateAllToggles()
			end)
		end
	end

	selectAllMat.MouseButton1Click:Connect(function()
		for _, mat in ipairs(allMaterials) do
			if mat ~= Enum.Material.Air then
				State.MaterialFilter.Whitelist[mat] = true
			end
		end
		UI.updateAllToggles()
	end)

	selectNoneMat.MouseButton1Click:Connect(function()
		State.MaterialFilter.Whitelist = {}
		UI.updateAllToggles()
	end)

	-- SLOPE MASK UI SECTION
	local slopeWrapper, slopeContent = createCollapsibleSection("SLOPE MASK", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local slopeOrder = 1

	UI.C.slopeMaskToggle = {createTechToggle("Enable Slope Mask", slopeContent)}
	UI.C.slopeMaskToggle[4].LayoutOrder = slopeOrder; slopeOrder = slopeOrder + 1

	UI.C.slopeMaskToggle[1].MouseButton1Click:Connect(function()
		State.SlopeFilter.Enabled = not State.SlopeFilter.Enabled
		UI.updateAllToggles()
	end)

	UI.C.slopeGrid = Instance.new("Frame")
	UI.C.slopeGrid.Size = UDim2.new(1, 0, 0, 40)
	UI.C.slopeGrid.BackgroundTransparency = 1
	UI.C.slopeGrid.LayoutOrder = slopeOrder; slopeOrder = slopeOrder + 1
	UI.C.slopeGrid.Parent = slopeContent

	local slopeLayout = Instance.new("UIGridLayout")
	slopeLayout.CellSize = UDim2.new(0.48, 0, 0, 40)
	slopeLayout.CellPadding = UDim2.new(0.04, 0, 0, 0)
	slopeLayout.Parent = UI.C.slopeGrid

	UI.C.slopeMinBox = {createTechInput("MIN ANGLE", "0", UI.C.slopeGrid)}
	UI.C.slopeMaxBox = {createTechInput("MAX ANGLE", "45", UI.C.slopeGrid)}

	UI.C.slopeMinBox[1].FocusLost:Connect(function()
		State.SlopeFilter.MinAngle = Utils.parseNumber(UI.C.slopeMinBox[1].Text, 0)
	end)

	UI.C.slopeMaxBox[1].FocusLost:Connect(function()
		State.SlopeFilter.MaxAngle = Utils.parseNumber(UI.C.slopeMaxBox[1].Text, 45)
	end)

	-- HEIGHT MASK UI SECTION
	local heightWrapper, heightContent = createCollapsibleSection("HEIGHT MASK (Y-LEVEL)", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local heightOrder = 1

	UI.C.heightMaskToggle = {createTechToggle("Enable Height Mask", heightContent)}
	UI.C.heightMaskToggle[4].LayoutOrder = heightOrder; heightOrder = heightOrder + 1

	UI.C.heightMaskToggle[1].MouseButton1Click:Connect(function()
		State.HeightFilter.Enabled = not State.HeightFilter.Enabled
		UI.updateAllToggles()
	end)

	UI.C.heightGrid = Instance.new("Frame")
	UI.C.heightGrid.Size = UDim2.new(1, 0, 0, 40)
	UI.C.heightGrid.BackgroundTransparency = 1
	UI.C.heightGrid.LayoutOrder = heightOrder; heightOrder = heightOrder + 1
	UI.C.heightGrid.Parent = heightContent

	local heightLayout = Instance.new("UIGridLayout")
	heightLayout.CellSize = UDim2.new(0.48, 0, 0, 40)
	heightLayout.CellPadding = UDim2.new(0.04, 0, 0, 0)
	heightLayout.Parent = UI.C.heightGrid

	UI.C.minHeightBox = {createTechInput("MIN Y", "-500", UI.C.heightGrid)}
	UI.C.maxHeightBox = {createTechInput("MAX Y", "500", UI.C.heightGrid)}

	UI.C.minHeightBox[1].FocusLost:Connect(function()
		State.HeightFilter.MinHeight = Utils.parseNumber(UI.C.minHeightBox[1].Text, -500)
	end)

	UI.C.maxHeightBox[1].FocusLost:Connect(function()
		State.HeightFilter.MaxHeight = Utils.parseNumber(UI.C.maxHeightBox[1].Text, 500)
	end)

	-- PHYSICS DROP UI SECTION
	local physWrapper, physContent = createCollapsibleSection("PHYSICS SIMULATION", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local physOrder = 1

	UI.C.physicsDropToggle = {createTechToggle("Enable Physics Drop", physContent)}
	UI.C.physicsDropToggle[4].LayoutOrder = physOrder; physOrder = physOrder + 1

	UI.C.physicsDropToggle[1].MouseButton1Click:Connect(function()
		State.PhysicsDrop.Enabled = not State.PhysicsDrop.Enabled
		UI.updateAllToggles()
	end)

	UI.C.physicsGrid = Instance.new("Frame")
	UI.C.physicsGrid.Size = UDim2.new(1, 0, 0, 40)
	UI.C.physicsGrid.BackgroundTransparency = 1
	UI.C.physicsGrid.LayoutOrder = physOrder; physOrder = physOrder + 1
	UI.C.physicsGrid.Parent = physContent

	local physLayout = Instance.new("UIGridLayout")
	physLayout.CellSize = UDim2.new(0.48, 0, 0, 40)
	physLayout.CellPadding = UDim2.new(0.04, 0, 0, 0)
	physLayout.Parent = UI.C.physicsGrid

	UI.C.physDurationBox = {createTechInput("DURATION (Sec)", "1.0", UI.C.physicsGrid)}

	UI.C.physDurationBox[1].FocusLost:Connect(function()
		State.PhysicsDrop.Duration = math.max(0.1, Utils.parseNumber(UI.C.physDurationBox[1].Text, 1.0))
	end)

	-- Connect Tuning Toggles & Inputs (Moved to end to ensure elements exist)
	-- Environment
	UI.C.smartSnapBtn[1].MouseButton1Click:Connect(function()
		State.smartSnapEnabled = not State.smartSnapEnabled
		UI.updateAllToggles()
	end)

	UI.C.snapToGridBtn[1].MouseButton1Click:Connect(function()
		State.snapToGridEnabled = not State.snapToGridEnabled
		UI.updateAllToggles()
	end)

	UI.C.gridSizeBox[1].FocusLost:Connect(function()
		State.gridSize = Utils.parseNumber(UI.C.gridSizeBox[1].Text, 4)
	end)

	UI.C.ghostTransparencyBox[1].FocusLost:Connect(function()
		State.ghostTransparency = Utils.parseNumber(UI.C.ghostTransparencyBox[1].Text, 0.65)
		if Core then Core.updatePreview() end
	end)

	UI.C.ghostLimitBox[1].FocusLost:Connect(function()
		State.MaxPreviewGhosts = math.floor(math.max(1, Utils.parseNumber(UI.C.ghostLimitBox[1].Text, 20)))
		if Core then Core.updatePreview() end
	end)

	-- Randomizers
	local function bindRandomizer(toggleGroup, btnGroup, stateKey, randomizeAction)
		toggleGroup[1].MouseButton1Click:Connect(function()
			if stateKey == "Wobble" then
				State.Wobble.Enabled = not State.Wobble.Enabled
			else
				State.Randomizer[stateKey].Enabled = not State.Randomizer[stateKey].Enabled
			end
			UI.updateAllToggles()
		end)
		btnGroup[1].MouseButton1Click:Connect(function()
			local enabled = false
			if stateKey == "Wobble" then enabled = State.Wobble.Enabled
			else enabled = State.Randomizer[stateKey].Enabled end

			if not enabled then return end

			-- Execute specific randomization action (filling inputs with random numbers)
			if randomizeAction then randomizeAction() end

			-- Force new randomization
			State.nextStampScale = nil
			State.nextStampRotation = nil
			State.nextStampColorShift = nil
			State.nextStampTransparencyShift = nil
			State.nextStampWobble = nil
			if Core then Core.updatePreview() end
		end)
	end

	bindRandomizer(UI.C.randomizeScaleToggle, UI.C.randomizeScaleBtn, "Scale", function()
		-- Randomize Scale Min/Max (0.5 to 1.5 range typically)
		local minVal = math.floor((0.5 + math.random() * 0.4) * 10) / 10 -- 0.5 to 0.9
		local maxVal = math.floor((minVal + 0.1 + math.random() * 0.5) * 10) / 10 -- minVal+0.1 to minVal+0.6
		UI.C.scaleMinBox[1].Text = tostring(minVal)
		UI.C.scaleMaxBox[1].Text = tostring(maxVal)
	end)

	bindRandomizer(UI.C.randomizeRotationToggle, UI.C.randomizeRotationBtn, "Rotation", function()
		-- Randomize Rotation Limits (-45 to 45 deg range typically)
		local limit = math.random(5, 45)
		UI.C.rotXMinBox[1].Text = tostring(-limit)
		UI.C.rotXMaxBox[1].Text = tostring(limit)

		limit = math.random(5, 45)
		UI.C.rotZMinBox[1].Text = tostring(-limit)
		UI.C.rotZMaxBox[1].Text = tostring(limit)
	end)

	bindRandomizer(UI.C.randomizeColorToggle, UI.C.randomizeColorBtn, "Color", function()
		-- Randomize Color Shifts (Small jitter)
		-- Hue
		local hRange = math.random() * 0.1
		UI.C.hueMinBox[1].Text = string.format("%.2f", -hRange/2)
		UI.C.hueMaxBox[1].Text = string.format("%.2f", hRange/2)
		-- Sat
		local sRange = math.random() * 0.2
		UI.C.satMinBox[1].Text = string.format("%.2f", -sRange/2)
		UI.C.satMaxBox[1].Text = string.format("%.2f", sRange/2)
		-- Val
		local vRange = math.random() * 0.2
		UI.C.valMinBox[1].Text = string.format("%.2f", -vRange/2)
		UI.C.valMaxBox[1].Text = string.format("%.2f", vRange/2)
	end)

	bindRandomizer(UI.C.randomizeTransparencyToggle, UI.C.randomizeTransparencyBtn, "Transparency", function()
		-- Randomize Transparency Range
		local minVal = math.floor((math.random() * 0.3) * 100) / 100 -- 0 to 0.3
		local maxVal = math.floor((minVal + math.random() * 0.4) * 100) / 100 -- min to min+0.4
		UI.C.transMinBox[1].Text = tostring(minVal)
		UI.C.transMaxBox[1].Text = tostring(maxVal)
	end)

	bindRandomizer(UI.C.randomizeWobbleToggle, UI.C.randomizeWobbleBtn, "Wobble", function()
		local xMax = math.random(5, 30)
		local zMax = math.random(5, 30)
		UI.C.wobbleXMaxBox[1].Text = tostring(xMax)
		UI.C.wobbleZMaxBox[1].Text = tostring(zMax)
	end)

	switchTab("Tools")
end

function UI.updateModeButtonsUI()
	for mode, controls in pairs(UI.C.modeButtons) do
		local isSelected = (mode == State.currentMode)
		controls.Button:SetAttribute("IsSelected", isSelected)

		if isSelected then
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
	UI.C.pathFrame.Visible = (State.currentMode == "Path")
	UI.C.fillFrame.Visible = (State.currentMode == "Fill")
	UI.C.eraserFrame.Visible = (State.currentMode == "Erase" or State.currentMode == "Replace")

	-- Input visibility
	local showBrush = (State.currentMode == "Paint" or State.currentMode == "Erase" or State.currentMode == "Replace" or State.currentMode == "Volume" or State.currentMode == "Fill")
	local showDensity = (State.currentMode == "Paint" or State.currentMode == "Volume" or State.currentMode == "Fill")
	local showSpacing = (State.currentMode == "Paint" or State.currentMode == "Line" or State.currentMode == "Path")
	local showDistance = (State.currentMode == "Volume")

	UI.C.radiusBox[2].Visible = showBrush
	UI.C.densityBox[2].Visible = showDensity
	UI.C.spacingBox[2].Visible = showSpacing
	UI.C.distanceBox[2].Visible = showDistance
end

function UI.updateOnOffButtonUI()
	if State.active then
		UI.C.activationBtn.Text = "SYSTEM: ONLINE"
		UI.C.activationBtn.TextColor3 = Theme.Background
		UI.C.activationBtn.BackgroundColor3 = Theme.Success
		UI.statusIndicator.BackgroundColor3 = Theme.Success
		UI.titleLabel.Text = "SYSTEM: ONLINE // READY"
		UI.titleLabel.TextColor3 = Theme.Success
	else
		UI.C.activationBtn.Text = "ACTIVATE"
		UI.C.activationBtn.TextColor3 = Theme.Text
		UI.C.activationBtn.BackgroundColor3 = Theme.Background
		UI.statusIndicator.BackgroundColor3 = Theme.Destructive
		UI.titleLabel.Text = "SYSTEM: STANDBY"
		UI.titleLabel.TextColor3 = Theme.Text
	end
end

function UI.updateGroupUI()
	UI.C.groupNameLabel[1].Text = "GROUP: " .. string.upper(State.currentAssetGroup)
end

function UI.updateAllToggles()
	local activeState = false
	if State.selectedAssetInUI then
		activeState = State.assetOffsets[State.selectedAssetInUI .. "_active"] ~= false
	end

	updateToggle(UI.C.assetSettingsAlign[1], UI.C.assetSettingsAlign[2], UI.C.assetSettingsAlign[3], State.alignToSurface)
	updateToggle(UI.C.assetSettingsActive[1], UI.C.assetSettingsActive[2], UI.C.assetSettingsActive[3], activeState)

	updateToggle(UI.C.smartSnapBtn[1], UI.C.smartSnapBtn[2], UI.C.smartSnapBtn[3], State.smartSnapEnabled)
	updateToggle(UI.C.snapToGridBtn[1], UI.C.snapToGridBtn[2], UI.C.snapToGridBtn[3], State.snapToGridEnabled)

	updateToggle(UI.C.materialFilterToggle[1], UI.C.materialFilterToggle[2], UI.C.materialFilterToggle[3], State.MaterialFilter.Enabled)

	updateToggle(UI.C.slopeMaskToggle[1], UI.C.slopeMaskToggle[2], UI.C.slopeMaskToggle[3], State.SlopeFilter.Enabled)
	updateInputGroupEnabled(UI.C.slopeGrid, State.SlopeFilter.Enabled)

	updateToggle(UI.C.heightMaskToggle[1], UI.C.heightMaskToggle[2], UI.C.heightMaskToggle[3], State.HeightFilter.Enabled)
	updateInputGroupEnabled(UI.C.heightGrid, State.HeightFilter.Enabled)

	updateToggle(UI.C.physicsDropToggle[1], UI.C.physicsDropToggle[2], UI.C.physicsDropToggle[3], State.PhysicsDrop.Enabled)
	updateInputGroupEnabled(UI.C.physicsGrid, State.PhysicsDrop.Enabled)

	if UI.C.materialButtons then
		for mat, controls in pairs(UI.C.materialButtons) do
			local isWhitelisted = State.MaterialFilter.Whitelist[mat] == true
			controls.Inner.Visible = isWhitelisted
			if isWhitelisted then
				controls.Label.TextColor3 = Theme.Text
				controls.Button.BackgroundColor3 = Color3.fromHex("25252A")
			else
				controls.Label.TextColor3 = Theme.TextDim
				controls.Button.BackgroundColor3 = Theme.Panel
			end
		end
	end

	updateToggle(UI.C.randomizeScaleToggle[1], UI.C.randomizeScaleToggle[2], UI.C.randomizeScaleToggle[3], State.Randomizer.Scale.Enabled)
	updateToggle(UI.C.randomizeRotationToggle[1], UI.C.randomizeRotationToggle[2], UI.C.randomizeRotationToggle[3], State.Randomizer.Rotation.Enabled)
	updateToggle(UI.C.randomizeColorToggle[1], UI.C.randomizeColorToggle[2], UI.C.randomizeColorToggle[3], State.Randomizer.Color.Enabled)
	updateToggle(UI.C.randomizeTransparencyToggle[1], UI.C.randomizeTransparencyToggle[2], UI.C.randomizeTransparencyToggle[3], State.Randomizer.Transparency.Enabled)

	updateInputGroupEnabled(UI.C.scaleGrid, State.Randomizer.Scale.Enabled, UI.C.randomizeScaleBtn)
	updateInputGroupEnabled(UI.C.rotationGrid, State.Randomizer.Rotation.Enabled, UI.C.randomizeRotationBtn)
	updateInputGroupEnabled(UI.C.colorGrid, State.Randomizer.Color.Enabled, UI.C.randomizeColorBtn)
	updateInputGroupEnabled(UI.C.transparencyGrid, State.Randomizer.Transparency.Enabled, UI.C.randomizeTransparencyBtn)

	updateToggle(UI.C.randomizeWobbleToggle[1], UI.C.randomizeWobbleToggle[2], UI.C.randomizeWobbleToggle[3], State.Wobble.Enabled)
	updateInputGroupEnabled(UI.C.wobbleGrid, State.Wobble.Enabled, UI.C.randomizeWobbleBtn)

	for mode, controls in pairs(UI.C.surfaceButtons) do
		local isSelected = (mode == State.surfaceAngleMode)
		controls.Button:SetAttribute("IsSelected", isSelected)

		if isSelected then
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

local function setupViewport(viewport, asset, zoomScale)
	zoomScale = zoomScale or 1.0
	for _, c in ipairs(viewport:GetChildren()) do c:Destroy() end
	local cam = Instance.new("Camera"); cam.Parent = viewport; viewport.CurrentCamera = cam
	local worldModel = Instance.new("WorldModel"); worldModel.Parent = viewport

	local c
	if asset:IsA("Decal") or asset:IsA("Texture") then
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 4, 1)
		part.Anchored = true
		part.Color = Color3.fromRGB(200, 200, 200)
		part.Transparency = 0
		c = asset:Clone()
		c.Parent = part
		part.Parent = worldModel

		-- Point camera at front face (Back, because decal is usually on Front but camera looks at Back? Wait.)
		-- Decal default face is Front (-Z).
		-- So Camera needs to be at -Z (looking at +Z) or +Z (looking at -Z)?
		-- Default camera looks at -Z.
		-- To look at the Front face (-Z relative to part center), camera should be at -Z * distance? No.
		-- Standard Roblox Front face is -Z.
		-- If we place camera at -Z * 6, and look at 0, we are looking in +Z direction.
		-- So we see the Front face.
		cam.CFrame = CFrame.new(part.Position + Vector3.new(0, 0, -6 / zoomScale), part.Position)
	else
		c = asset:Clone(); c.Parent = worldModel
		local cf, size = c:GetBoundingBox()
		local maxDim = math.max(size.X, size.Y, size.Z)
		local dist = (maxDim / 2) / math.tan(math.rad(35))
		dist = (dist * 1.2) / zoomScale
		cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist, dist*0.8, dist), cf.Position)
	end
end

function UI.updateAssetUIList()
	for _, v in pairs(UI.C.assetListFrame:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end

	if State.isGroupListView then
		local groups = {}
		for _, c in ipairs(State.assetsFolder:GetChildren()) do if c:IsA("Folder") then table.insert(groups, c) end end
		table.sort(groups, function(a,b) return a.Name < b.Name end)

		for _, grp in ipairs(groups) do
			local btn = Instance.new("TextButton")
			btn.BackgroundColor3 = (grp.Name == State.currentAssetGroup) and Theme.Panel or Theme.Background
			btn.Text = ""
			btn.Parent = UI.C.assetListFrame
			local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Border; stroke.Parent = btn
			if grp.Name == State.currentAssetGroup then stroke.Color = Theme.Accent end

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
			lbl.TextColor3 = (grp.Name == State.currentAssetGroup) and Theme.Accent or Theme.Text
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.Parent = btn

			btn.MouseButton1Click:Connect(function()
				State.currentAssetGroup = grp.Name
				State.isGroupListView = false
				UI.updateGroupUI()
				UI.updateAssetUIList()
			end)
		end
		return
	end

	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then return end

	local children = targetGroup:GetChildren()

	-- Sort children: Favorites first, then Alphabetical
	table.sort(children, function(a, b)
		local favA = State.assetOffsets[a.Name .. "_isFavorite"] or false
		local favB = State.assetOffsets[b.Name .. "_isFavorite"] or false
		if favA ~= favB then
			return favA -- true comes before false
		end
		return a.Name < b.Name
	end)

	for _, asset in ipairs(children) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end

		local btn = Instance.new("TextButton")
		btn.BackgroundColor3 = isActive and Theme.Panel or Color3.fromHex("151515")
		btn.Text = ""
		btn.Parent = UI.C.assetListFrame
		local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Border; stroke.Parent = btn

		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.new(1, -8, 0, 60)
		vp.Position = UDim2.new(0, 4, 0, 4)
		vp.BackgroundTransparency = 1
		vp.ImageTransparency = isActive and 0 or 0.6
		vp.Parent = btn

		local zoomKey = asset.Name .. "_previewZoom"
		local zoom = State.assetOffsets[zoomKey] or 1.0

		pcall(function() setupViewport(vp, asset, zoom) end)

		local function updateZoom(delta)
			zoom = math.clamp(zoom + delta, 0.5, 5.0)
			State.assetOffsets[zoomKey] = zoom
			State.persistOffsets()
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

		-- Favorites Button
		local isFav = State.assetOffsets[asset.Name .. "_isFavorite"] or false
		local favBtn = Instance.new("TextButton")
		favBtn.Size = UDim2.new(0, 20, 0, 20)
		favBtn.Position = UDim2.new(0, 4, 0, 28)
		favBtn.Text = isFav and "★" or "☆"
		favBtn.BackgroundColor3 = Theme.Background
		favBtn.TextColor3 = isFav and Theme.Warning or Theme.TextDim
		favBtn.Visible = isActive
		favBtn.Parent = btn

		favBtn.MouseButton1Click:Connect(function()
			State.assetOffsets[asset.Name .. "_isFavorite"] = not isFav
			State.persistOffsets()
			UI.updateAssetUIList()
		end)

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
				UI.updateAssetUIList()
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
			State.selectedAssetInUI = asset.Name
			UI.C.assetSettingsFrame.Visible = true
			UI.C.assetSettingsName.Text = "SELECTED: " .. string.upper(asset.Name)
			UI.C.assetSettingsOffsetY[1].Text = tostring(State.assetOffsets[asset.Name] or 0)
			UI.C.assetSettingsWeight[1].Text = tostring(State.assetOffsets[asset.Name.."_weight"] or 1)
			UI.C.assetSettingsBaseScale[1].Text = tostring(State.assetOffsets[asset.Name.."_scale"] or 1)
			UI.C.assetSettingsBaseRotation[1].Text = tostring(State.assetOffsets[asset.Name.."_rotation"] or 0)
			UI.C.assetSettingsBaseRotationX[1].Text = tostring(State.assetOffsets[asset.Name.."_rotationX"] or 0)

			-- Toggle visibility based on asset type
			local isSticker = asset:IsA("Decal") or asset:IsA("Texture")
			UI.C.assetSettingsBaseScale[2].Visible = isSticker
			UI.C.assetSettingsBaseRotation[2].Visible = isSticker
			UI.C.assetSettingsBaseRotationX[2].Visible = isSticker

			UI.updateAllToggles()
			UI.updateAssetUIList() 
		end)

		if State.selectedAssetInUI == asset.Name then stroke.Color = Theme.Accent; stroke.Thickness = 2 end
	end
end

function UI.updatePresetUIList(applyCallback)
	for _, c in ipairs(UI.C.presetListFrame:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end

	local sortedNames = {}
	for name, _ in pairs(State.presets) do table.insert(sortedNames, name) end
	table.sort(sortedNames)

	for _, name in ipairs(sortedNames) do
		local container = Instance.new("Frame")
		container.BackgroundTransparency = 1
		container.BackgroundColor3 = Theme.Panel
		container.Parent = UI.C.presetListFrame

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
			if applyCallback then applyCallback(State.presets[name]) end
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
				State.presets[name] = nil
				State.savePresetsToStorage()
				UI.updatePresetUIList(applyCallback)
			end
		end)
	end
end

return UI
