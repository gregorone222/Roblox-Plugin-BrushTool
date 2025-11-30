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
-- Group Signals
UI.C.groupNameLabel[1].MouseButton1Click:Connect(function()
	State.isGroupListView = true
	UI.updateAssetUIList()
end)

local function commitNewGroup()
	local name = Utils.trim(UI.C.groupNameInput.Text)
	if name ~= "" then
		if not State.assetsFolder:FindFirstChild(name) then
			local nf = Instance.new("Folder")
			nf.Name = name
			nf.Parent = State.assetsFolder
			State.currentAssetGroup = name
			State.isGroupListView = false
		end
	end
	UI.C.groupNameInput.Text = ""
	UI.C.groupNameInput.Visible = false
	UI.C.groupNameLabel[1].Visible = true
	UI.updateGroupUI()
	UI.updateAssetUIList()
end

UI.C.newGroupBtn[1].MouseButton1Click:Connect(function()
	if not UI.C.groupNameInput.Visible then
		UI.C.groupNameInput.Visible = true
		UI.C.groupNameLabel[1].Visible = false
		UI.C.groupNameInput:CaptureFocus()
	else
		commitNewGroup()
	end
end)

UI.C.groupNameInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then commitNewGroup() end
end)

UI.C.deleteGroupBtn[1].MouseButton1Click:Connect(function()
	if State.currentAssetGroup == "Default" then return end
	local target = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if target then target:Destroy() end
	State.currentAssetGroup = "Default"
	State.isGroupListView = false
	UI.updateGroupUI()
	UI.updateAssetUIList()
end)

-- Fill Signal
UI.C.fillBtn[1].MouseButton1Click:Connect(function()
	Core.fillSelectedPart()
end)

-- Biome Signal
UI.C.biomeRunBtn[1].MouseButton1Click:Connect(function()
	Core.populateBiome()
end)

UI.C.biomeMaterialBtn[1].MouseButton1Click:Connect(function()
	UI.C.biomeMaterialList.Visible = not UI.C.biomeMaterialList.Visible
end)

local function updateBiomeButtonVisuals()
	local count = 0
	for mat, _ in pairs(State.Biome.Whitelist) do
		count = count + 1
	end
	UI.C.biomeMaterialBtn[1].Text = "TARGETS: " .. tostring(count)

	for _, child in ipairs(UI.C.biomeMaterialList:GetChildren()) do
		if child:IsA("TextButton") then
			local mat = Enum.Material[child.Name]
			if mat then
				local isSelected = State.Biome.Whitelist[mat] == true
				local check = child:FindFirstChild("CheckFrame")
				if check then
					local inner = check:FindFirstChild("Inner")
					if inner then inner.Visible = isSelected end
				end
				if isSelected then
					child.TextColor3 = Constants.Theme.Text
					child.BackgroundColor3 = Color3.fromHex("25252A")
				else
					child.TextColor3 = Constants.Theme.TextDim
					child.BackgroundColor3 = Constants.Theme.Panel
				end
			end
		end
	end
end

-- Populate Material List
local function updateBiomeMaterialList()
	for _, c in ipairs(UI.C.biomeMaterialList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local materials = Enum.Material:GetEnumItems()
	table.sort(materials, function(a,b) return a.Name < b.Name end)

	for _, mat in ipairs(materials) do
		if mat ~= Enum.Material.Air then
			local btn = Instance.new("TextButton")
			btn.Name = mat.Name
			btn.BackgroundColor3 = Constants.Theme.Panel
			btn.Text = "      " .. mat.Name -- Space for check
			btn.TextColor3 = Constants.Theme.TextDim
			btn.Font = Constants.Theme.FontTech
			btn.TextSize = 10
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.Parent = UI.C.biomeMaterialList

			local stroke = Instance.new("UIStroke")
			stroke.Color = Constants.Theme.Border
			stroke.Parent = btn

			local checkFrame = Instance.new("Frame")
			checkFrame.Name = "CheckFrame"
			checkFrame.Size = UDim2.new(0, 10, 0, 10)
			checkFrame.Position = UDim2.new(0, 4, 0.5, -5)
			checkFrame.BackgroundColor3 = Constants.Theme.Background
			checkFrame.BorderSizePixel = 0
			checkFrame.Parent = btn
			local cfStroke = Instance.new("UIStroke")
			cfStroke.Color = Constants.Theme.Border
			cfStroke.Parent = checkFrame

			local inner = Instance.new("Frame")
			inner.Name = "Inner"
			inner.Size = UDim2.new(1, -2, 1, -2)
			inner.Position = UDim2.new(0, 1, 0, 1)
			inner.BackgroundColor3 = Constants.Theme.Accent
			inner.BorderSizePixel = 0
			inner.Visible = false
			inner.Parent = checkFrame

			btn.MouseButton1Click:Connect(function()
				if State.Biome.Whitelist[mat] then
					State.Biome.Whitelist[mat] = nil
				else
					State.Biome.Whitelist[mat] = true
				end
				updateBiomeButtonVisuals()
			end)
		end
	end
	updateBiomeButtonVisuals()
end
updateBiomeMaterialList()

-- Path Signal
UI.C.applyPathBtn[1].MouseButton1Click:Connect(function()
	Core.generatePathAssets()
end)

UI.C.clearPathBtn[1].MouseButton1Click:Connect(function()
	Core.clearPath()
end)

UI.C.addBtn[1].MouseButton1Click:Connect(function()
	local selection = Selection:Get()
	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then return end

	for _, v in ipairs(selection) do
		if (v:IsA("Model") or v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture")) and not targetGroup:FindFirstChild(v.Name) then
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
