local Constants = require(script:WaitForChild("Constants"))
local Utils = require(script:WaitForChild("Utils"))
local State = require(script:WaitForChild("State"))
local UI = require(script:WaitForChild("UI"))
local Core = require(script:WaitForChild("Core"))

local Selection = game:GetService("Selection")

-- Initialize Modules
State.init(plugin, Constants)
UI.init(plugin, State, Constants, Utils)
Core.init(plugin, State, UI, Constants, Utils)

-- Main Toolbar
local toolbar = plugin:CreateToolbar("Brush Tool V8")
local toolbarBtn = toolbar:CreateButton("Brush", "Open Brush Tool", "rbxassetid://1507949203")

toolbarBtn.Click:Connect(function()
	UI.widget.Enabled = not UI.widget.Enabled
end)

-- Connect UI Signals to Core Logic
UI.C.activationBtn.MouseButton1Click:Connect(function()
	if State.active then
		Core.deactivate()
		toolbarBtn:SetActive(false)
	else
		Core.activate()
		toolbarBtn:SetActive(true)
	end
end)

for mode, controls in pairs(UI.C.modeButtons) do
	controls.Button.MouseButton1Click:Connect(function() Core.setMode(mode) end)
end

-- Asset Management Signals
UI.C.addBtn[1].MouseButton1Click:Connect(function()
	local selection = Selection:Get()
	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then return end

	for _, v in ipairs(selection) do
		if (v:IsA("Model") or v:IsA("BasePart")) and not targetGroup:FindFirstChild(v.Name) then
			local clone = v:Clone()
			clone.Parent = targetGroup
		end
	end
	UI.updateAssetUIList()
end)

UI.C.clearBtn[1].MouseButton1Click:Connect(function()
	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if targetGroup then targetGroup:ClearAllChildren() end
	UI.updateAssetUIList()
end)

-- Preset Signals
UI.C.savePresetBtn[1].MouseButton1Click:Connect(function()
	local name = Utils.trim(UI.C.presetNameInput[1].Text)
	if name == "" then return end

	-- Capture State
	local stateSnapshot = {
		brush = {
			radius = Utils.parseNumber(UI.C.radiusBox[1].Text, 10),
			density = Utils.parseNumber(UI.C.densityBox[1].Text, 10),
			spacing = Utils.parseNumber(UI.C.spacingBox[1].Text, 1.5)
		},
		environment = {
			smartSnap = State.smartSnapEnabled,
			snapGrid = State.snapToGridEnabled,
			gridSize = State.gridSize,
			surfaceMode = State.surfaceAngleMode,
			ghostTransparency = State.ghostTransparency
		},
		randomizer = State.Randomizer,
		-- Could add assets config here too
	}

	State.presets[name] = stateSnapshot
	State.savePresetsToStorage()
	UI.updatePresetUIList(function(savedState)
		-- Apply Preset Callback
		if savedState.brush then
			UI.C.radiusBox[1].Text = tostring(savedState.brush.radius)
			UI.C.densityBox[1].Text = tostring(savedState.brush.density)
			UI.C.spacingBox[1].Text = tostring(savedState.brush.spacing)
		end
		if savedState.environment then
			State.smartSnapEnabled = savedState.environment.smartSnap
			State.snapToGridEnabled = savedState.environment.snapGrid
			State.gridSize = savedState.environment.gridSize
			UI.C.gridSizeBox[1].Text = tostring(State.gridSize)
			State.surfaceAngleMode = savedState.environment.surfaceMode
			State.ghostTransparency = savedState.environment.ghostTransparency
			UI.C.ghostTransparencyBox[1].Text = tostring(State.ghostTransparency)
		end
		if savedState.randomizer then
			State.Randomizer = savedState.randomizer
		end
		UI.updateAllToggles()
	end)
	UI.C.presetNameInput[1].Text = ""
end)

UI.updatePresetUIList(function(savedState)
	-- Apply Preset Callback (Duplicated for init load, ideally move to function)
	if savedState.brush then
		UI.C.radiusBox[1].Text = tostring(savedState.brush.radius)
		UI.C.densityBox[1].Text = tostring(savedState.brush.density)
		UI.C.spacingBox[1].Text = tostring(savedState.brush.spacing)
	end
	if savedState.environment then
		State.smartSnapEnabled = savedState.environment.smartSnap
		State.snapToGridEnabled = savedState.environment.snapGrid
		State.gridSize = savedState.environment.gridSize
		UI.C.gridSizeBox[1].Text = tostring(State.gridSize)
		State.surfaceAngleMode = savedState.environment.surfaceMode
		State.ghostTransparency = savedState.environment.ghostTransparency
		UI.C.ghostTransparencyBox[1].Text = tostring(State.ghostTransparency)
	end
	if savedState.randomizer then
		State.Randomizer = savedState.randomizer
	end
	UI.updateAllToggles()
end)

-- Selection Changed
Selection.SelectionChanged:Connect(Core.updateFillSelection)

-- Cleanup
plugin.Unloading:Connect(function()
	Core.deactivate()
	if State.previewFolder then State.previewFolder:Destroy() end
	if State.pathPreviewFolder then State.pathPreviewFolder:Destroy() end
	if State.ghostModel then State.ghostModel:Destroy() end
end)

print("Brush Tool V8 (Modular) // Loaded Successfully.")
