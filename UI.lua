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
				inputBox.TextColor3 = Theme.Text
				child:FindFirstChildOfClass("TextLabel").TextColor3 = Theme.Text
			else
				inputBox.TextColor3 = Theme.TextDim
				child:FindFirstChildOfClass("TextLabel").TextColor3 = Theme.TextDim
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
			randomizeBtn[2].Color = Theme.Border
			randomizeBtn[1].TextColor3 = Theme.TextDim
			randomizeBtn[1].TextTransparency = 0.5
		end
	end
end

-- --- COMPONENT HELPERS (MODERN MINIMALIST STYLE) ---

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
	return corner
end

local function createStyledFrame(parent, size)
	local f = Instance.new("Frame")
	f.Size = size
	f.BackgroundColor3 = Theme.Panel
	f.BorderSizePixel = 0 -- Modern style uses corners/shadows, less borders
	f.Parent = parent
	addCorner(f, 6)
	return f
end

local function createStyledButton(text, parent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32) -- Slightly taller for touch/modern feel
	btn.BackgroundColor3 = Theme.Panel
	btn.Text = text
	btn.TextColor3 = Theme.Text
	btn.Font = Theme.FontMain
	btn.TextSize = 13
	btn.AutoButtonColor = false -- Custom animation
	btn.Parent = parent

	addCorner(btn, 6)

	-- Modern hover animation logic
	btn.MouseEnter:Connect(function()
		if not btn.Active then return end
		if btn:GetAttribute("IsSelected") then
			btn.BackgroundColor3 = Theme.AccentHover
		else
			btn.BackgroundColor3 = Theme.PanelHover
		end
	end)
	btn.MouseLeave:Connect(function()
		if not btn.Active then return end
		if btn:GetAttribute("IsSelected") then
			btn.BackgroundColor3 = Theme.Accent
		else
			btn.BackgroundColor3 = Theme.Panel
		end
	end)
	btn.MouseButton1Down:Connect(function()
		if not btn.Active then return end
		if not btn:GetAttribute("IsSelected") then
			btn.BackgroundColor3 = Theme.Border -- Pressed state
		end
	end)
	btn.MouseButton1Up:Connect(function()
		if not btn.Active then return end
		if not btn:GetAttribute("IsSelected") then
			btn.BackgroundColor3 = Theme.PanelHover
		end
	end)

	-- Proxy for border color (API compatibility)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Border
	stroke.Thickness = 1
	stroke.Transparency = 1 -- Hidden by default
	stroke.Parent = btn

	return btn, stroke 
end

local function createCheckbox(text, parent)
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 28)
	container.Parent = parent

	-- Modern Switch Style
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 36, 0, 20)
	btn.Position = UDim2.new(0, 0, 0.5, -10)
	btn.BackgroundColor3 = Theme.PanelHover
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = container
	addCorner(btn, 10) -- Capsule shape

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(0, 2, 0.5, -8)
	knob.BackgroundColor3 = Theme.TextDim
	knob.BorderSizePixel = 0
	knob.Parent = btn
	addCorner(knob, 8) -- Circle

	-- Proxy 'inner' logic to switch animation
	local proxyInner = {}
	local isOn = false

	setmetatable(proxyInner, {
		__newindex = function(t, k, v)
			if k == "Visible" then
				isOn = v
				if isOn then
					btn.BackgroundColor3 = Theme.Accent
					knob.Position = UDim2.new(1, -18, 0.5, -8)
					knob.BackgroundColor3 = Theme.Background
				else
					btn.BackgroundColor3 = Theme.PanelHover
					knob.Position = UDim2.new(0, 2, 0.5, -8)
					knob.BackgroundColor3 = Theme.TextDim
				end
			elseif k == "BackgroundColor3" then
				-- Ignore custom colors from old logic
			end
		end,
		__index = function(t, k)
			if k == "Visible" then return isOn end
		end
	})

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -44, 1, 0)
	label.Position = UDim2.new(0, 44, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Theme.FontMain
	label.TextSize = 13
	label.TextColor3 = Theme.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	-- Click Area overlay (to forward clicks)
	local clickArea = Instance.new("TextButton")
	clickArea.Size = UDim2.new(1, 0, 1, 0)
	clickArea.BackgroundTransparency = 1
	clickArea.Text = ""
	clickArea.ZIndex = 5
	clickArea.Parent = container

	return clickArea, proxyInner, label, container
end

-- Default limits map for known parameters
local SLIDER_LIMITS = {
	-- Tools
	["Radius (Studs)"] = {min=0.1, max=50, step=0.1},
	["Density (Count)"] = {min=1, max=100, step=1},
	["Spacing (Studs)"] = {min=0.1, max=20, step=0.1},
	["Distance (Studs)"] = {min=1, max=100, step=1},

	-- Asset Settings
	["Y-Offset"] = {min=-10, max=10, step=0.1},
	["Probability"] = {min=0, max=10, step=0.1},
	["Base Scale"] = {min=0.1, max=5, step=0.1},
	["Base Rot (Y)"] = {min=0, max=360, step=1},
	["Base Rot (X)"] = {min=0, max=360, step=1},

	-- Tuning Environment
	["Grid Size"] = {min=0.1, max=16, step=0.1},
	["Ghost Trans"] = {min=0, max=1, step=0.05},
	["Ghost Limit"] = {min=1, max=50, step=1},

	-- Randomizers
	["Scale Min"] = {min=0.1, max=3, step=0.1},
	["Scale Max"] = {min=0.1, max=5, step=0.1},
	["Rot X Min"] = {min=-180, max=180, step=1},
	["Rot X Max"] = {min=-180, max=180, step=1},
	["Rot Z Min"] = {min=-180, max=180, step=1},
	["Rot Z Max"] = {min=-180, max=180, step=1},

	-- Color
	["Hue Min"] = {min=0, max=1, step=0.01}, -- Usually relative shift, so small range might be better, but generic 0-1 ok
	["Hue Max"] = {min=0, max=1, step=0.01},
	["Sat Min"] = {min=-1, max=1, step=0.05},
	["Sat Max"] = {min=-1, max=1, step=0.05},
	["Val Min"] = {min=-1, max=1, step=0.05},
	["Val Max"] = {min=-1, max=1, step=0.05},

	-- Trans
	["Trns Min"] = {min=-1, max=1, step=0.05},
	["Trns Max"] = {min=-1, max=1, step=0.05},

	-- Wobble
	["X Angle (Deg)"] = {min=0, max=90, step=1},
	["Z Angle (Deg)"] = {min=0, max=90, step=1},
	["Min Angle"] = {min=0, max=90, step=1},
	["Max Angle"] = {min=0, max=90, step=1},
	["Min Y"] = {min=-1000, max=1000, step=10},
	["Max Y"] = {min=-1000, max=1000, step=10},
}

local function createSliderWithInput(labelText, defaultValue, parent)
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 52) -- Increased height for slider
	container.Parent = parent

	-- Top Row: Label + Input
	local topRow = Instance.new("Frame")
	topRow.Size = UDim2.new(1, 0, 0, 26)
	topRow.BackgroundTransparency = 1
	topRow.Parent = container

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -60, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.Font = Theme.FontMain
	label.TextColor3 = Theme.TextDim
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	label.Parent = topRow

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 12
	constraint.MinTextSize = 8
	constraint.Parent = label

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(0, 50, 1, 0)
	inputBox.Position = UDim2.new(1, -50, 0, 0)
	inputBox.BackgroundColor3 = Theme.Panel
	inputBox.Text = tostring(defaultValue)
	inputBox.TextColor3 = Theme.Text
	inputBox.Font = Theme.FontMain
	inputBox.TextSize = 12
	inputBox.TextXAlignment = Enum.TextXAlignment.Center
	inputBox.BorderSizePixel = 0
	inputBox.ClearTextOnFocus = false
	inputBox.Parent = topRow
	addCorner(inputBox, 4)

	inputBox.Focused:Connect(function() inputBox.BackgroundColor3 = Theme.PanelHover; inputBox.TextColor3 = Theme.Accent end)
	inputBox.FocusLost:Connect(function() inputBox.BackgroundColor3 = Theme.Panel; inputBox.TextColor3 = Theme.Text end)

	-- Logic
	local limits = SLIDER_LIMITS[labelText] or {min=0, max=100, step=1}

	-- Stepper Layout
	-- [ - ] [=========|=========] [ + ]
	local minusBtn = Instance.new("TextButton")
	minusBtn.Size = UDim2.new(0, 24, 0, 24)
	minusBtn.Position = UDim2.new(0, 0, 0, 28)
	minusBtn.BackgroundColor3 = Theme.Panel
	minusBtn.Text = "-"
	minusBtn.TextColor3 = Theme.Text
	minusBtn.Font = Theme.FontHeader
	minusBtn.TextSize = 14
	minusBtn.AutoButtonColor = false
	minusBtn.Parent = container
	addCorner(minusBtn, 6)

	local plusBtn = Instance.new("TextButton")
	plusBtn.Size = UDim2.new(0, 24, 0, 24)
	plusBtn.Position = UDim2.new(1, -24, 0, 28)
	plusBtn.BackgroundColor3 = Theme.Panel
	plusBtn.Text = "+"
	plusBtn.TextColor3 = Theme.Text
	plusBtn.Font = Theme.FontHeader
	plusBtn.TextSize = 14
	plusBtn.AutoButtonColor = false
	plusBtn.Parent = container
	addCorner(plusBtn, 6)

	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -56, 0, 4) -- Space for buttons
	sliderBg.Position = UDim2.new(0, 28, 0, 38)
	sliderBg.BackgroundColor3 = Theme.Panel
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = container
	addCorner(sliderBg, 2)

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
	sliderFill.BackgroundColor3 = Theme.Accent
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg
	addCorner(sliderFill, 2)

	-- Visual Update Only (No Drag)
	local function updateVisualsFromValue(val)
		local pct = math.clamp((val - limits.min) / (limits.max - limits.min), 0, 1)
		sliderFill.Size = UDim2.new(pct, 0, 1, 0)
	end

	local function setValue(val)
		val = math.clamp(val, limits.min, limits.max)
		if limits.step then
			val = math.floor(val / limits.step + 0.5) * limits.step
		end
		local fmt = (limits.step and limits.step < 1) and "%.2f" or "%d"
		inputBox.Text = string.format(fmt, val)
		updateVisualsFromValue(val)
	end

	-- Init
	setValue(tonumber(defaultValue) or limits.min)

	-- Input Listener
	inputBox.FocusLost:Connect(function()
		local n = tonumber(inputBox.Text)
		if n then setValue(n) else setValue(limits.min) end
	end)

	-- Stepper Logic
	local function adjustValue(sign)
		local current = tonumber(inputBox.Text) or limits.min
		local step = limits.step or ((limits.max - limits.min) * 0.01)
		if step == 0 then step = 1 end
		setValue(current + (step * sign))
	end

	local function setupStepperButton(btn, sign)
		local holding = false

		btn.MouseButton1Down:Connect(function()
			holding = true
			btn.BackgroundColor3 = Theme.PanelHover
			adjustValue(sign)

			task.delay(0.4, function()
				while holding do
					adjustValue(sign)
					task.wait(0.1)
				end
			end)
		end)

		btn.MouseButton1Up:Connect(function()
			holding = false
			btn.BackgroundColor3 = Theme.Panel
		end)

		btn.MouseLeave:Connect(function()
			holding = false
			btn.BackgroundColor3 = Theme.Panel
		end)
	end

	setupStepperButton(minusBtn, -1)
	setupStepperButton(plusBtn, 1)

	return inputBox, container
end

-- Renamed original to keep if needed, but we replace usage
local function createStyledInput(labelText, defaultValue, parent)
    -- Check if we have limits for this label, if so use slider
    if SLIDER_LIMITS[labelText] then
        return createSliderWithInput(labelText, defaultValue, parent)
    else
        -- Fallback to old style
        local container = Instance.new("Frame")
        container.BackgroundTransparency = 1
        container.Size = UDim2.new(1, 0, 0, 44)
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
        inputBox.Size = UDim2.new(1, 0, 0, 26)
        inputBox.Position = UDim2.new(0, 0, 0, 18)
        inputBox.BackgroundColor3 = Theme.Panel
        inputBox.Text = tostring(defaultValue)
        inputBox.TextColor3 = Theme.Text
        inputBox.Font = Theme.FontMain
        inputBox.TextSize = 14
        inputBox.TextXAlignment = Enum.TextXAlignment.Left
        inputBox.BorderSizePixel = 0
        inputBox.ClearTextOnFocus = false
        inputBox.Parent = container

        addCorner(inputBox, 6)

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 10)
        padding.Parent = inputBox

        inputBox.Focused:Connect(function()
            inputBox.BackgroundColor3 = Theme.PanelHover
            inputBox.TextColor3 = Theme.Accent
        end)
        inputBox.FocusLost:Connect(function()
            inputBox.BackgroundColor3 = Theme.Panel
            inputBox.TextColor3 = Theme.Text
        end)

        return inputBox, container
    end
end

local function createSectionHeader(text, parent)
	local h = Instance.new("TextLabel")
	h.Size = UDim2.new(1, 0, 0, 28)
	h.BackgroundTransparency = 1
	h.Text = text
	h.Font = Theme.FontHeader
	h.TextSize = 14
	h.TextColor3 = Theme.Accent
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

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = container

	local headerBtn = Instance.new("TextButton")
	headerBtn.LayoutOrder = 1
	headerBtn.Size = UDim2.new(1, 0, 0, 32)
	headerBtn.BackgroundTransparency = 1
	headerBtn.AutoButtonColor = false
	headerBtn.Text = ""
	headerBtn.Parent = container

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(0, 20, 1, 0)
	arrow.BackgroundTransparency = 1
	arrow.Text = isOpen and "▼" or "▶"
	arrow.Font = Theme.FontMain
	arrow.TextSize = 12
	arrow.TextColor3 = Theme.TextDim
	arrow.Parent = headerBtn

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 1, 0)
	title.Position = UDim2.new(0, 24, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = text
	title.Font = Theme.FontHeader
	title.TextSize = 14
	title.TextColor3 = Theme.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = headerBtn

	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 1, -1)
	line.BackgroundColor3 = Theme.Border
	line.BorderSizePixel = 0
	line.Parent = headerBtn

	local content = Instance.new("Frame")
	content.LayoutOrder = 2
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Visible = isOpen
	content.Parent = container

	local contentPad = Instance.new("UIPadding")
	contentPad.PaddingTop = UDim.new(0, 8)
	contentPad.PaddingBottom = UDim.new(0, 8)
	contentPad.PaddingLeft = UDim.new(0, 4)
	contentPad.PaddingRight = UDim.new(0, 4)
	contentPad.Parent = content

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.Parent = content

	headerBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		content.Visible = isOpen
		arrow.Text = isOpen and "▼" or "▶"
		title.TextColor3 = isOpen and Theme.Accent or Theme.Text
	end)

	return container, content
end

local function switchTab(tabName)
	for _, t in pairs(UI.allTabs) do
		if t.Name == tabName then
			t.Button.TextColor3 = Theme.Accent
			t.Indicator.Visible = true
			t.Frame.Visible = true
			t.Button.Font = Theme.FontHeader
		else
			t.Button.TextColor3 = Theme.TextDim
			t.Indicator.Visible = false
			t.Frame.Visible = false
			t.Button.Font = Theme.FontMain
		end
	end
end

local function createTab(name, label, tabBar, tabContent)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0.2, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = label
	btn.Font = Theme.FontMain
	btn.TextSize = 13
	btn.TextColor3 = Theme.TextDim
	btn.Parent = tabBar

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0.6, 0, 0, 3)
	indicator.Position = UDim2.new(0.2, 0, 1, -3)
	indicator.BackgroundColor3 = Theme.Accent
	indicator.BorderSizePixel = 0
	indicator.Visible = false
	indicator.Parent = btn
	addCorner(indicator, 2)

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
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
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
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	local btn, inner, label, toggleContainer = createCheckbox(toggleText, container)

	local grid = Instance.new("Frame")
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Size = UDim2.new(1,0,0,0)
	grid.BackgroundTransparency = 1
	grid.Parent = container

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.48, 0, 0, 52) -- Adjusted for Slider
	gridLayout.CellPadding = UDim2.new(0.04, 0, 0, 16) -- Adjusted padding
	gridLayout.Parent = grid

	local randomizeBtn = {createStyledButton("Randomize", container)}
	randomizeBtn[1].Size = UDim2.new(1, 0, 0, 28)

	return {btn, inner, label, toggleContainer}, grid, randomizeBtn
end

function UI.init(plugin, pState, pConstants, pUtils)
	State = pState
	Constants = pConstants
	Utils = pUtils
	Theme = Constants.Theme

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false, false, 300, 500, 250, 300
	)
	UI.widget = plugin:CreateDockWidgetPluginGui("AssetFluxWidgetV1", widgetInfo)
	UI.widget.Title = "AssetFlux"

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

	-- Top Bar (Activation)
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 48) -- Taller header
	topBar.BackgroundColor3 = Theme.Background
	topBar.BorderSizePixel = 0
	topBar.Parent = uiRoot

	local headerLine = Instance.new("Frame")
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.Position = UDim2.new(0, 0, 1, -1)
	headerLine.BackgroundColor3 = Theme.Border
	headerLine.BorderSizePixel = 0
	headerLine.Parent = topBar

	UI.C.activationBtn = Instance.new("TextButton")
	UI.C.activationBtn.Size = UDim2.new(1, -32, 0, 32)
	UI.C.activationBtn.Position = UDim2.new(0, 16, 0.5, -16)
	UI.C.activationBtn.BackgroundColor3 = Theme.Panel
	UI.C.activationBtn.Text = "Activate AssetFlux"
	UI.C.activationBtn.Font = Theme.FontHeader
	UI.C.activationBtn.TextSize = 14
	UI.C.activationBtn.TextColor3 = Theme.Text
	UI.C.activationBtn.AutoButtonColor = false
	UI.C.activationBtn.Parent = topBar
	addCorner(UI.C.activationBtn, 8)

	-- Tabs
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, 0, 0, 40)
	tabBar.Position = UDim2.new(0, 0, 0, 48)
	tabBar.BackgroundColor3 = Theme.Background
	tabBar.BorderSizePixel = 0
	tabBar.Parent = uiRoot

	local tabBarLayout = Instance.new("UIListLayout")
	tabBarLayout.FillDirection = Enum.FillDirection.Horizontal
	tabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabBarLayout.Parent = tabBar

	local tabContent = Instance.new("Frame")
	tabContent.Size = UDim2.new(1, 0, 1, -88)
	tabContent.Position = UDim2.new(0, 0, 0, 88)
	tabContent.BackgroundTransparency = 1
	tabContent.Parent = uiRoot

	local TabTools = createTab("Tools", "Tools", tabBar, tabContent)
	local TabAssets = createTab("Assets", "Assets", tabBar, tabContent)
	local TabPresets = createTab("Presets", "Presets", tabBar, tabContent)
	local TabTuning = createTab("Tuning", "Tuning", tabBar, tabContent)
	local TabHelp = createTab("Help", "Help", tabBar, tabContent)

	-- TOOLS TAB
	createSectionHeader("Output Settings", TabTools.frame)
	local outputFrame = Instance.new("Frame")
	outputFrame.Size = UDim2.new(1, 0, 0, 0)
	outputFrame.AutomaticSize = Enum.AutomaticSize.Y
	outputFrame.BackgroundTransparency = 1
	outputFrame.Parent = TabTools.frame
	local ol = Instance.new("UIListLayout")
	ol.Padding = UDim.new(0, 8)
	ol.Parent = outputFrame

	UI.C.outputModeBtn = {createStyledButton("Mode: Per Stroke", outputFrame)}
	UI.C.outputFolderNameInput = {createStyledInput("Folder Name", "AssetFlux_Output", outputFrame)}

	-- Initial State
	UI.C.outputFolderNameInput[2].Visible = false

	UI.C.outputModeBtn[1].MouseButton1Click:Connect(function()
		if State.Output.Mode == "PerStroke" then
			State.Output.Mode = "Fixed"
			UI.C.outputModeBtn[1].Text = "Mode: Fixed Folder"
			UI.C.outputFolderNameInput[2].Visible = true
		elseif State.Output.Mode == "Fixed" then
			State.Output.Mode = "Grouped"
			UI.C.outputModeBtn[1].Text = "Mode: Group by Asset"
			UI.C.outputFolderNameInput[2].Visible = false
		else
			State.Output.Mode = "PerStroke"
			UI.C.outputModeBtn[1].Text = "Mode: Per Stroke"
			UI.C.outputFolderNameInput[2].Visible = false
		end
	end)

	UI.C.outputFolderNameInput[1].FocusLost:Connect(function()
		local txt = Utils.trim(UI.C.outputFolderNameInput[1].Text)
		if txt == "" then txt = "AssetFlux_Output" end
		State.Output.FixedFolderName = txt
		UI.C.outputFolderNameInput[1].Text = txt
	end)

	createSectionHeader("Brush Mode", TabTools.frame)
	local modeGrid = Instance.new("Frame")
	modeGrid.Size = UDim2.new(1, 0, 0, 0)
	modeGrid.AutomaticSize = Enum.AutomaticSize.Y
	modeGrid.BackgroundTransparency = 1
	modeGrid.Parent = TabTools.frame
	local mgLayout = Instance.new("UIGridLayout")
	mgLayout.CellSize = UDim2.new(0.48, 0, 0, 32)
	mgLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	mgLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mgLayout.Parent = modeGrid

	UI.C.modeButtons = {}
	local modeNames = {"Paint", "Line", "Path", "Fill", "Volume", "Stamp", "Replace", "Erase"}
	for _, m in ipairs(modeNames) do
		local b, s = createStyledButton(m, modeGrid)
		b.TextSize = 13
		UI.C.modeButtons[m] = {Button = b, Stroke = s}
	end

	createSectionHeader("Parameters", TabTools.frame)
	local brushParamsContainer = Instance.new("Frame")
	brushParamsContainer.Size = UDim2.new(1, 0, 0, 0)
	brushParamsContainer.AutomaticSize = Enum.AutomaticSize.Y
	brushParamsContainer.BackgroundTransparency = 1
	brushParamsContainer.Parent = TabTools.frame
	local bpLayout = Instance.new("UIGridLayout")
	bpLayout.CellSize = UDim2.new(0.48, 0, 0, 52) -- Slider height
	bpLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	bpLayout.Parent = brushParamsContainer

	UI.C.radiusBox = {createStyledInput("Radius (Studs)", "10", brushParamsContainer)}
	UI.C.densityBox = {createStyledInput("Density (Count)", "10", brushParamsContainer)}
	UI.C.spacingBox = {createStyledInput("Spacing (Studs)", "1.5", brushParamsContainer)}
	UI.C.distanceBox = {createStyledInput("Distance (Studs)", "30", brushParamsContainer)}

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
	local pathHeader = createSectionHeader("Path Settings", UI.C.pathFrame)
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
	UI.C.applyPathBtn = {createStyledButton("Generate", pathBtnGrid)}
	UI.C.clearPathBtn = {createStyledButton("Clear", pathBtnGrid)}
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

	UI.C.undoPathBtn = {createStyledButton("Undo", pathHistoryGrid)}
	UI.C.redoPathBtn = {createStyledButton("Redo", pathHistoryGrid)}

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
	UI.C.fillBtn = {createStyledButton("Select Target Volume", UI.C.fillFrame)}

	-- Eraser Context
	UI.C.eraserFrame = Instance.new("Frame")
	UI.C.eraserFrame.AutomaticSize = Enum.AutomaticSize.Y
	UI.C.eraserFrame.Size = UDim2.new(1, 0, 0, 0)
	UI.C.eraserFrame.BackgroundTransparency = 1
	UI.C.eraserFrame.Visible = false
	UI.C.eraserFrame.Parent = UI.C.contextContainer

	UI.C.eraserFilterBtn = {createCheckbox("Filter: Everything", UI.C.eraserFrame)}

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
	createSectionHeader("Asset Groups", TabAssets.frame)
	local groupActions = Instance.new("Frame")
	groupActions.Size = UDim2.new(1, 0, 0, 32)
	groupActions.BackgroundTransparency = 1
	groupActions.Parent = TabAssets.frame
	groupActions.ZIndex = 10
	local gal = Instance.new("UIListLayout")
	gal.FillDirection = Enum.FillDirection.Horizontal
	gal.Parent = groupActions

	UI.C.groupNameLabel = {createStyledButton("Group: Default", groupActions)}
	UI.C.groupNameLabel[1].Size = UDim2.new(1, 0, 1, 0)
	UI.C.groupNameLabel[1].AutoButtonColor = true

	UI.C.groupNameInput = Instance.new("TextBox")
	UI.C.groupNameInput.Size = UDim2.new(1, 0, 1, 0)
	UI.C.groupNameInput.BackgroundColor3 = Theme.Background
	UI.C.groupNameInput.TextColor3 = Theme.Text
	UI.C.groupNameInput.Font = Theme.FontMain
	UI.C.groupNameInput.TextSize = 14
	UI.C.groupNameInput.Text = ""
	UI.C.groupNameInput.PlaceholderText = "Enter Name..."
	UI.C.groupNameInput.Visible = false
	UI.C.groupNameInput.Parent = groupActions

	addCorner(UI.C.groupNameInput, 6)

	local groupButtonsContainer = Instance.new("Frame")
	groupButtonsContainer.Size = UDim2.new(1, 0, 0, 32)
	groupButtonsContainer.BackgroundTransparency = 1
	groupButtonsContainer.Parent = TabAssets.frame
	local gbl = Instance.new("UIGridLayout")
	gbl.CellSize = UDim2.new(0.48, 0, 1, 0)
	gbl.CellPadding = UDim2.new(0.04, 0, 0, 0)
	gbl.Parent = groupButtonsContainer

	UI.C.newGroupBtn = {createStyledButton("Add", groupButtonsContainer)}
	UI.C.newGroupBtn[1].Size = UDim2.new(1, 0, 1, 0)
	UI.C.newGroupBtn[1].TextColor3 = Theme.Success

	UI.C.deleteGroupBtn = {createStyledButton("Del", groupButtonsContainer)}
	UI.C.deleteGroupBtn[1].Size = UDim2.new(1, 0, 1, 0)
	UI.C.deleteGroupBtn[1].TextColor3 = Theme.Destructive

	createSectionHeader("Asset Management", TabAssets.frame)
	local assetActions = Instance.new("Frame")
	assetActions.Size = UDim2.new(1, 0, 0, 32)
	assetActions.BackgroundTransparency = 1
	assetActions.Parent = TabAssets.frame
	local aal = Instance.new("UIListLayout")
	aal.FillDirection = Enum.FillDirection.Horizontal
	aal.Padding = UDim.new(0, 8)
	aal.Parent = assetActions
	UI.C.addBtn = {createStyledButton("+ Add Selected", assetActions)}
	UI.C.addBtn[1].Size = UDim2.new(0.5, -4, 1, 0)
	UI.C.addBtn[1].TextColor3 = Theme.Success
	UI.C.clearBtn = {createStyledButton("Clear All", assetActions)}
	UI.C.clearBtn[1].Size = UDim2.new(0.5, -4, 1, 0)
	UI.C.clearBtn[1].TextColor3 = Theme.Destructive

	local clearConfirm = false
	UI.C.clearBtn[1].MouseButton1Click:Connect(function()
		if not clearConfirm then
			clearConfirm = true
			UI.C.clearBtn[1].Text = "Confirm?"
			UI.C.clearBtn[1].BackgroundColor3 = Theme.Destructive
			UI.C.clearBtn[1].TextColor3 = Theme.Text
			task.delay(2, function()
				if clearConfirm then
					clearConfirm = false
					if UI.C.clearBtn and UI.C.clearBtn[1] and UI.C.clearBtn[1].Parent then
						UI.C.clearBtn[1].Text = "Clear All"
						UI.C.clearBtn[1].BackgroundColor3 = Theme.Panel
						UI.C.clearBtn[1].TextColor3 = Theme.Destructive
					end
				end
			end)
		else
			clearConfirm = false
			local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
			if targetGroup then targetGroup:ClearAllChildren() end
			UI.updateAssetUIList()

			-- Reset button
			UI.C.clearBtn[1].Text = "Clear All"
			UI.C.clearBtn[1].BackgroundColor3 = Theme.Panel
			UI.C.clearBtn[1].TextColor3 = Theme.Destructive
		end
	end)

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
	UI.C.assetSettingsName = createSectionHeader("Selected: ???", UI.C.assetSettingsFrame)
	local asGrid = Instance.new("Frame")
	asGrid.Size = UDim2.new(1, 0, 0, 0)
	asGrid.AutomaticSize = Enum.AutomaticSize.Y
	asGrid.BackgroundTransparency = 1
	asGrid.Parent = UI.C.assetSettingsFrame
	local asgl = Instance.new("UIGridLayout")
	asgl.CellSize = UDim2.new(0.48, 0, 0, 52) -- Slider height
	asgl.CellPadding = UDim2.new(0.04, 0, 0, 8)
	asgl.Parent = asGrid
	UI.C.assetSettingsOffsetY = {createStyledInput("Y-Offset", "0", asGrid)}
	UI.C.assetSettingsWeight = {createStyledInput("Probability", "1", asGrid)}
	UI.C.assetSettingsBaseScale = {createStyledInput("Base Scale", "1", asGrid)}
	UI.C.assetSettingsBaseRotation = {createStyledInput("Base Rot (Y)", "0", asGrid)}
	UI.C.assetSettingsBaseRotationX = {createStyledInput("Base Rot (X)", "0", asGrid)}

	UI.C.assetSettingsPlacementMode = {createStyledButton("Mode: Bounding Box", UI.C.assetSettingsFrame)}
	UI.C.assetSettingsPlacementMode[1].Size = UDim2.new(1, 0, 0, 32)

	UI.C.assetSettingsActive = {createCheckbox("Active in Brush", UI.C.assetSettingsFrame)}

	UI.C.assetSettingsPlacementMode[1].MouseButton1Click:Connect(function()
		if State.selectedAssetInUI then
			local key = State.selectedAssetInUI .. "_placementMode"
			local current = State.assetOffsets[key] or "BoundingBox"
			local nextMode = "BoundingBox"
			if current == "BoundingBox" then nextMode = "PrimaryPart"
			elseif current == "PrimaryPart" then nextMode = "Raycast"
			else nextMode = "BoundingBox" end

			State.assetOffsets[key] = nextMode
			State.persistOffsets()
			UI.C.assetSettingsPlacementMode[1].Text = "Mode: " .. nextMode
		end
	end)

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
	createSectionHeader("New Preset", TabPresets.frame)
	local presetCreationFrame = Instance.new("Frame")
	presetCreationFrame.Size = UDim2.new(1, 0, 0, 80)
	presetCreationFrame.BackgroundTransparency = 1
	presetCreationFrame.Parent = TabPresets.frame
	local pcl = Instance.new("UIListLayout")
	pcl.Padding = UDim.new(0, 8)
	pcl.Parent = presetCreationFrame

	UI.C.presetNameInput = {createStyledInput("Preset Name", "", presetCreationFrame)}
	UI.C.savePresetBtn = {createStyledButton("Save Current Config", presetCreationFrame)}
	UI.C.savePresetBtn[1].TextColor3 = Theme.Success

	createSectionHeader("Saved Profiles", TabPresets.frame)
	UI.C.presetListFrame = Instance.new("Frame")
	UI.C.presetListFrame.Size = UDim2.new(1, 0, 0, 300)
	UI.C.presetListFrame.BackgroundTransparency = 1
	UI.C.presetListFrame.Parent = TabPresets.frame
	local plGrid = Instance.new("UIGridLayout")
	plGrid.CellSize = UDim2.new(1, 0, 0, 32)
	plGrid.CellPadding = UDim2.new(0, 0, 0, 4)
	plGrid.Parent = UI.C.presetListFrame

	-- TUNING TAB
	local tuningLayoutOrder = 1

	-- TRANSFORMATION RANDOMIZER SECTION
	local randWrapper, randContent = createCollapsibleSection("Transformation Randomizer", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1

	local randOrder = 1
	-- Scale
	UI.C.randomizeScaleToggle, UI.C.scaleGrid, UI.C.randomizeScaleBtn = createOrderedRandomizerGroup(randContent, "Randomize Scale", randOrder)
	randOrder = randOrder + 1
	UI.C.scaleMinBox = {createStyledInput("Scale Min", "0.8", UI.C.scaleGrid)}
	UI.C.scaleMaxBox = {createStyledInput("Scale Max", "1.2", UI.C.scaleGrid)}

	-- Rotation
	UI.C.randomizeRotationToggle, UI.C.rotationGrid, UI.C.randomizeRotationBtn = createOrderedRandomizerGroup(randContent, "Randomize Rotation (X/Z)", randOrder)
	randOrder = randOrder + 1
	UI.C.rotXMinBox = {createStyledInput("Rot X Min", "0", UI.C.rotationGrid)}
	UI.C.rotXMaxBox = {createStyledInput("Rot X Max", "0", UI.C.rotationGrid)}
	UI.C.rotZMinBox = {createStyledInput("Rot Z Min", "0", UI.C.rotationGrid)}
	UI.C.rotZMaxBox = {createStyledInput("Rot Z Max", "0", UI.C.rotationGrid)}

	-- Color
	UI.C.randomizeColorToggle, UI.C.colorGrid, UI.C.randomizeColorBtn = createOrderedRandomizerGroup(randContent, "Randomize Color (HSV)", randOrder)
	randOrder = randOrder + 1
	UI.C.hueMinBox = {createStyledInput("Hue Min", "0", UI.C.colorGrid)}
	UI.C.hueMaxBox = {createStyledInput("Hue Max", "0", UI.C.colorGrid)}
	UI.C.satMinBox = {createStyledInput("Sat Min", "0", UI.C.colorGrid)}
	UI.C.satMaxBox = {createStyledInput("Sat Max", "0", UI.C.colorGrid)}
	UI.C.valMinBox = {createStyledInput("Val Min", "0", UI.C.colorGrid)}
	UI.C.valMaxBox = {createStyledInput("Val Max", "0", UI.C.colorGrid)}

	-- Transparency
	UI.C.randomizeTransparencyToggle, UI.C.transparencyGrid, UI.C.randomizeTransparencyBtn = createOrderedRandomizerGroup(randContent, "Randomize Transparency", randOrder)
	randOrder = randOrder + 1
	UI.C.transMinBox = {createStyledInput("Trns Min", "0", UI.C.transparencyGrid)}
	UI.C.transMaxBox = {createStyledInput("Trns Max", "0", UI.C.transparencyGrid)}

	-- Wobble
	UI.C.randomizeWobbleToggle, UI.C.wobbleGrid, UI.C.randomizeWobbleBtn = createOrderedRandomizerGroup(randContent, "Wobble (Tilt)", randOrder)
	randOrder = randOrder + 1
	UI.C.wobbleXMaxBox = {createStyledInput("X Angle (Deg)", "0", UI.C.wobbleGrid)}
	UI.C.wobbleZMaxBox = {createStyledInput("Z Angle (Deg)", "0", UI.C.wobbleGrid)}

	-- ENVIRONMENT CONTROL SECTION
	local envWrapper, envContent = createCollapsibleSection("Environment Control", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local envOrder = 1

	UI.C.snapToGridBtn = {createCheckbox("Snap to Grid", envContent)}
	UI.C.snapToGridBtn[4].LayoutOrder = envOrder; envOrder = envOrder + 1

	UI.C.gridSizeBox = {createStyledInput("Grid Size", "4", envContent)}
	UI.C.gridSizeBox[2].LayoutOrder = envOrder; envOrder = envOrder + 1

	UI.C.ghostTransparencyBox = {createStyledInput("Ghost Trans", "0.65", envContent)}
	UI.C.ghostTransparencyBox[2].LayoutOrder = envOrder; envOrder = envOrder + 1

	UI.C.ghostLimitBox = {createStyledInput("Ghost Limit", "20", envContent)}
	UI.C.ghostLimitBox[2].LayoutOrder = envOrder; envOrder = envOrder + 1


	-- SURFACE LOCK SECTION
	local surfWrapper, surfContent = createCollapsibleSection("Surface Lock", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local surfOrder = 1

	UI.C.assetSettingsAlign = {createCheckbox("Align Asset to Surface", surfContent)}
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
	slLayout.CellSize = UDim2.new(0.48, 0, 0, 28)
	slLayout.CellPadding = UDim2.new(0.04, 0, 0, 8)
	slLayout.Parent = surfaceGrid

	UI.C.surfaceButtons = {}
	local surfaceModes = {"Off", "Floor", "Wall", "Ceiling"}
	for _, m in ipairs(surfaceModes) do
		local b, s = createStyledButton(m, surfaceGrid)
		UI.C.surfaceButtons[m] = {Button = b, Stroke = s}
		b.MouseButton1Click:Connect(function()
			State.surfaceAngleMode = m
			UI.updateAllToggles()
		end)
	end

	-- MATERIAL FILTER UI SECTION
	local matWrapper, matContent = createCollapsibleSection("Surface Material Filter", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local matOrder = 1

	UI.C.materialFilterToggle = {createCheckbox("Enable Material Filter", matContent)}
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
	selectAllMat.Text = "Select All"
	selectAllMat.Font = Theme.FontMain
	selectAllMat.TextSize = 12
	selectAllMat.TextColor3 = Theme.Text
	selectAllMat.Parent = mfTools
	addCorner(selectAllMat, 6)

	local selectNoneMat = Instance.new("TextButton")
	selectNoneMat.Size = UDim2.new(0.5, -4, 1, 0)
	selectNoneMat.BackgroundColor3 = Theme.Panel
	selectNoneMat.Text = "Select None"
	selectNoneMat.Font = Theme.FontMain
	selectNoneMat.TextSize = 12
	selectNoneMat.TextColor3 = Theme.Text
	selectNoneMat.Parent = mfTools
	addCorner(selectNoneMat, 6)

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
			btn.BorderColor3 = Theme.Border
			btn.Parent = matListScroll
			addCorner(btn, 6)

			local check = Instance.new("Frame")
			check.Size = UDim2.new(0, 14, 0, 14)
			check.Position = UDim2.new(0, 5, 0.5, -7)
			check.BackgroundColor3 = Theme.Background
			check.BorderSizePixel = 0
			check.Parent = btn
			addCorner(check, 4)

			local innerCheck = Instance.new("Frame")
			innerCheck.Size = UDim2.new(1, -4, 1, -4)
			innerCheck.Position = UDim2.new(0, 2, 0, 2)
			innerCheck.BackgroundColor3 = Theme.Accent
			innerCheck.BorderSizePixel = 0
			innerCheck.Visible = false -- Toggled
			innerCheck.Parent = check
			addCorner(innerCheck, 2)

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -24, 1, 0)
			label.Position = UDim2.new(0, 24, 0, 0)
			label.BackgroundTransparency = 1
			label.Text = mat.Name
			label.Font = Theme.FontMain
			label.TextSize = 12
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
	local slopeWrapper, slopeContent = createCollapsibleSection("Slope Mask", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local slopeOrder = 1

	UI.C.slopeMaskToggle = {createCheckbox("Enable Slope Mask", slopeContent)}
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
	slopeLayout.CellSize = UDim2.new(0.48, 0, 0, 52) -- Slider height
	slopeLayout.CellPadding = UDim2.new(0.04, 0, 0, 0)
	slopeLayout.Parent = UI.C.slopeGrid

	UI.C.slopeMinBox = {createStyledInput("Min Angle", "0", UI.C.slopeGrid)}
	UI.C.slopeMaxBox = {createStyledInput("Max Angle", "45", UI.C.slopeGrid)}

	UI.C.slopeMinBox[1].FocusLost:Connect(function()
		State.SlopeFilter.MinAngle = Utils.parseNumber(UI.C.slopeMinBox[1].Text, 0)
	end)

	UI.C.slopeMaxBox[1].FocusLost:Connect(function()
		State.SlopeFilter.MaxAngle = Utils.parseNumber(UI.C.slopeMaxBox[1].Text, 45)
	end)

	-- HEIGHT MASK UI SECTION
	local heightWrapper, heightContent = createCollapsibleSection("Height Mask (Y-Level)", TabTuning.frame, false, tuningLayoutOrder)
	tuningLayoutOrder = tuningLayoutOrder + 1
	local heightOrder = 1

	UI.C.heightMaskToggle = {createCheckbox("Enable Height Mask", heightContent)}
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
	heightLayout.CellSize = UDim2.new(0.48, 0, 0, 52) -- Slider height
	heightLayout.CellPadding = UDim2.new(0.04, 0, 0, 0)
	heightLayout.Parent = UI.C.heightGrid

	UI.C.minHeightBox = {createStyledInput("Min Y", "-500", UI.C.heightGrid)}
	UI.C.maxHeightBox = {createStyledInput("Max Y", "500", UI.C.heightGrid)}

	UI.C.minHeightBox[1].FocusLost:Connect(function()
		State.HeightFilter.MinHeight = Utils.parseNumber(UI.C.minHeightBox[1].Text, -500)
	end)

	UI.C.maxHeightBox[1].FocusLost:Connect(function()
		State.HeightFilter.MaxHeight = Utils.parseNumber(UI.C.maxHeightBox[1].Text, 500)
	end)

	-- Connect Tuning Toggles & Inputs (Moved to end to ensure elements exist)
	-- Environment
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

	-- HELP TAB
	local helpFrame = TabHelp.frame

	createSectionHeader("About AssetFlux", helpFrame)
	local aboutText = Instance.new("TextLabel")
	aboutText.Size = UDim2.new(1, 0, 0, 0)
	aboutText.AutomaticSize = Enum.AutomaticSize.Y
	aboutText.BackgroundTransparency = 1
	aboutText.Text = "AssetFlux is a professional asset placement system designed for fluid creativity. Place models, decals, and textures with advanced randomizers, smart surface snapping, and masking tools.\n\nVersion: 1.0.0 (Release)"
	aboutText.Font = Theme.FontMain
	aboutText.TextSize = 13
	aboutText.TextColor3 = Theme.TextDim
	aboutText.TextXAlignment = Enum.TextXAlignment.Left
	aboutText.TextWrapped = true
	aboutText.Parent = helpFrame

	createSectionHeader("Modes Guide", helpFrame)

	local function addHelpItem(title, desc)
		local container = Instance.new("Frame")
		container.Size = UDim2.new(1, 0, 0, 0)
		container.AutomaticSize = Enum.AutomaticSize.Y
		container.BackgroundTransparency = 1
		container.Parent = helpFrame

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0, 20)
		t.BackgroundTransparency = 1
		t.Text = "• " .. title
		t.Font = Theme.FontHeader
		t.TextSize = 13
		t.TextColor3 = Theme.Text
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Parent = container

		local d = Instance.new("TextLabel")
		d.Size = UDim2.new(1, -10, 0, 0)
		d.Position = UDim2.new(0, 10, 0, 20)
		d.AutomaticSize = Enum.AutomaticSize.Y
		d.BackgroundTransparency = 1
		d.Text = desc
		d.Font = Theme.FontMain
		d.TextSize = 12
		d.TextColor3 = Theme.TextDim
		d.TextXAlignment = Enum.TextXAlignment.Left
		d.TextWrapped = true
		d.Parent = container

		local pad = Instance.new("UIPadding")
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = container
	end

	addHelpItem("Paint", "Click and drag to scatter assets within the radius. Adjust Density for more assets per stroke.")
	addHelpItem("Line", "Click start point, then click end point to place a row of assets. Uses 'Spacing' parameter.")
	addHelpItem("Path", "Click multiple points to draw a curve. Press 'Generate' to place assets along it. Use Undo/Redo to fix points.")
	addHelpItem("Volume", "Fills a spherical area in 3D space. Useful for floating debris or clouds.")
	addHelpItem("Fill", "Select a Part, then click 'Fill' to populate its volume with assets.")
	addHelpItem("Stamp", "Places a single asset at a time with precision.")
	addHelpItem("Erase / Replace", "Remove or Swap assets within the brush radius. Use 'Filter' to target specific groups.")

	createSectionHeader("Tuning Guide", helpFrame)
	addHelpItem("Transformation Randomizer", "Randomize Scale, Rotation, Color, and Transparency. Use 'Wobble' to add tilt variation.")
	addHelpItem("Environment", "Control Ghost opacity/limits.")
	addHelpItem("Surface Lock", "Force asset alignment to Floors, Walls, or Ceilings.")
	addHelpItem("Filters", "Limit placement to specific Materials, Slope angles, or Height (Y-Level) ranges.")

	createSectionHeader("Pro Tips", helpFrame)
	local tipsText = Instance.new("TextLabel")
	tipsText.Size = UDim2.new(1, 0, 0, 0)
	tipsText.AutomaticSize = Enum.AutomaticSize.Y
	tipsText.BackgroundTransparency = 1
	tipsText.Text = "1. 'Slope Mask' prevents placement on steep cliffs.\n2. Save your favorite setups in the 'Presets' tab.\n3. Organize outputs using 'Grouped' mode in Output Settings."
	tipsText.Font = Theme.FontMain
	tipsText.TextSize = 13
	tipsText.TextColor3 = Theme.TextDim
	tipsText.TextXAlignment = Enum.TextXAlignment.Left
	tipsText.TextWrapped = true
	tipsText.Parent = helpFrame

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
			-- controls.Stroke.Thickness = 2 -- Not used in new native style, accent border handled by color
		else
			controls.Stroke.Color = Theme.Border
			controls.Button.TextColor3 = Theme.Text
			controls.Button.BackgroundColor3 = Theme.Panel
			-- controls.Stroke.Thickness = 1
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
		UI.C.activationBtn.Text = "System: Online"
		UI.C.activationBtn.TextColor3 = Theme.Background
		UI.C.activationBtn.BackgroundColor3 = Theme.Success
	else
		UI.C.activationBtn.Text = "Activate AssetFlux"
		UI.C.activationBtn.TextColor3 = Theme.Text
		UI.C.activationBtn.BackgroundColor3 = Theme.Panel
	end
end

function UI.updateGroupUI()
	UI.C.groupNameLabel[1].Text = "Group: " .. string.upper(State.currentAssetGroup)
end

function UI.updateAllToggles()
	local activeState = false
	if State.selectedAssetInUI then
		activeState = State.assetOffsets[State.selectedAssetInUI .. "_active"] ~= false
	end

	updateToggle(UI.C.assetSettingsAlign[1], UI.C.assetSettingsAlign[2], UI.C.assetSettingsAlign[3], State.alignToSurface)
	updateToggle(UI.C.assetSettingsActive[1], UI.C.assetSettingsActive[2], UI.C.assetSettingsActive[3], activeState)

	updateToggle(UI.C.snapToGridBtn[1], UI.C.snapToGridBtn[2], UI.C.snapToGridBtn[3], State.snapToGridEnabled)

	updateToggle(UI.C.materialFilterToggle[1], UI.C.materialFilterToggle[2], UI.C.materialFilterToggle[3], State.MaterialFilter.Enabled)

	updateToggle(UI.C.slopeMaskToggle[1], UI.C.slopeMaskToggle[2], UI.C.slopeMaskToggle[3], State.SlopeFilter.Enabled)
	updateInputGroupEnabled(UI.C.slopeGrid, State.SlopeFilter.Enabled)

	updateToggle(UI.C.heightMaskToggle[1], UI.C.heightMaskToggle[2], UI.C.heightMaskToggle[3], State.HeightFilter.Enabled)
	updateInputGroupEnabled(UI.C.heightGrid, State.HeightFilter.Enabled)

	if UI.C.materialButtons then
		for mat, controls in pairs(UI.C.materialButtons) do
			local isWhitelisted = State.MaterialFilter.Whitelist[mat] == true
			controls.Inner.Visible = isWhitelisted
			if isWhitelisted then
				controls.Label.TextColor3 = Theme.Text
				controls.Button.BackgroundColor3 = Theme.Panel
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
			controls.Stroke.Transparency = 1
			controls.Button.TextColor3 = Theme.Background
			controls.Button.BackgroundColor3 = Theme.Accent
			-- controls.Stroke.Thickness = 2
		else
			controls.Stroke.Transparency = 1
			controls.Button.TextColor3 = Theme.Text
			controls.Button.BackgroundColor3 = Theme.Panel
			-- controls.Stroke.Thickness = 1
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
		-- To look at the Front face (-Z relative to part center), camera should be at -Z * 6, and look at 0, we are looking in +Z direction.
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
			addCorner(btn, 8)

			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.new(1, 0, 1, -20)
			icon.BackgroundTransparency = 1
			icon.Text = "📁"
			icon.TextSize = 32
			icon.TextColor3 = Theme.TextDim
			icon.Parent = btn

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -8, 0, 20)
			lbl.Position = UDim2.new(0, 4, 1, -24)
			lbl.BackgroundTransparency = 1
			lbl.Text = grp.Name .. " (" .. #grp:GetChildren() .. ")"
			lbl.Font = Theme.FontMain -- Clean font
			lbl.TextSize = 12
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
		btn.BackgroundColor3 = isActive and Theme.Panel or Color3.fromRGB(30,30,30)
		btn.Text = ""
		btn.Parent = UI.C.assetListFrame
		local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Border; stroke.Parent = btn
		addCorner(btn, 8)

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
		addCorner(plusBtn, 4)
		plusBtn.MouseButton1Click:Connect(function() updateZoom(0.1) end)

		local minusBtn = Instance.new("TextButton")
		minusBtn.Size = UDim2.new(0, 20, 0, 20)
		minusBtn.Position = UDim2.new(1, -24, 0, 28)
		minusBtn.Text = "-"
		minusBtn.BackgroundColor3 = Theme.Background
		minusBtn.TextColor3 = Theme.Text
		minusBtn.Visible = isActive
		minusBtn.Parent = btn
		addCorner(minusBtn, 4)
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
		addCorner(favBtn, 4)

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
		addCorner(deleteBtn, 4)

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
		lbl.Font = Theme.FontMain -- Clean font
		lbl.TextSize = 12
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

			local pMode = State.assetOffsets[asset.Name .. "_placementMode"] or "BoundingBox"
			UI.C.assetSettingsPlacementMode[1].Text = "Mode: " .. pMode

			-- Toggle visibility based on asset type
			local isSticker = asset:IsA("Decal") or asset:IsA("Texture")
			UI.C.assetSettingsBaseScale[2].Visible = isSticker
			UI.C.assetSettingsBaseRotation[2].Visible = isSticker
			UI.C.assetSettingsBaseRotationX[2].Visible = isSticker
			-- Hide Placement Mode for Stickers (always top face)
			UI.C.assetSettingsPlacementMode[1].Visible = not isSticker

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
		loadBtn.Font = Theme.FontMain
		loadBtn.TextSize = 12
		loadBtn.TextColor3 = Theme.Text
		loadBtn.TextXAlignment = Enum.TextXAlignment.Left
		loadBtn.AutoButtonColor = false
		loadBtn.Parent = container
		addCorner(loadBtn, 6)

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
		addCorner(delBtn, 6)
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
