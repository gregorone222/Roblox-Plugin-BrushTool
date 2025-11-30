local Core = {}
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")

-- Dependencies
local State, UI, Constants, Utils, pluginInstance

local moveConn, downConn, upConn

function Core.init(pPlugin, pState, pUI, pConstants, pUtils)
	pluginInstance = pPlugin
	State = pState
	UI = pUI
	Constants = pConstants
	Utils = pUtils

	UI.setCore(Core)
end

-- Helper functions used internally
local function getWorkspaceContainer()
	local container = workspace:FindFirstChild(Constants.WORKSPACE_FOLDER_NAME)
	if not container or not container:IsA("Folder") then
		container = Instance.new("Folder")
		container.Name = Constants.WORKSPACE_FOLDER_NAME
		container.Parent = workspace
	end
	return container
end

function Core.isMaterialAllowed(material)
	if not State.MaterialFilter.Enabled then return true end
	return State.MaterialFilter.Whitelist[material] == true
end

function Core.isSlopeAllowed(normal)
	if not State.SlopeFilter.Enabled then return true end
	-- Calculate angle between normal and UP (0,1,0)
	-- Dot Product: A . B = |A||B| cos(theta)
	-- Since both are unit vectors (mostly), theta = acos(A . B)
	local dot = math.clamp(normal:Dot(Vector3.new(0, 1, 0)), -1, 1)
	local angle = math.deg(math.acos(dot))
	return angle >= State.SlopeFilter.MinAngle and angle <= State.SlopeFilter.MaxAngle
end

function Core.isHeightAllowed(position)
	if not State.HeightFilter.Enabled then return true end
	return position.Y >= State.HeightFilter.MinHeight and position.Y <= State.HeightFilter.MaxHeight
end

local function getRandomWeightedAsset(assetList)
	local totalWeight = 0
	for _, asset in ipairs(assetList) do
		local weight = State.assetOffsets[asset.Name .. "_weight"] or 1
		totalWeight = totalWeight + weight
	end
	if totalWeight == 0 then return assetList[math.random(1, #assetList)] end
	local randomNum = math.random() * totalWeight
	local currentWeight = 0
	for _, asset in ipairs(assetList) do
		local weight = State.assetOffsets[asset.Name .. "_weight"] or 1
		currentWeight = currentWeight + weight
		if randomNum <= currentWeight then return asset end
	end
	return assetList[#assetList]
end

local function getAssetsInRadius(center, radius)
	local container = getWorkspaceContainer()
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {container}
	overlapParams.FilterType = Enum.RaycastFilterType.Include

	local parts = workspace:GetPartBoundsInRadius(center, radius, overlapParams)
	local assets = {}
	local seen = {}

	for _, part in ipairs(parts) do
		local asset = part
		while asset.Parent and asset.Parent.Parent ~= container and asset.Parent ~= container do
			asset = asset.Parent
		end
		if asset.Parent and (asset.Parent == container or asset.Parent.Parent == container) then
			if not seen[asset] then
				seen[asset] = true
				-- Check if the asset's pivot is within the radius (stricter check than simple overlap)
				if (asset:GetPivot().Position - center).Magnitude <= radius then
					table.insert(assets, asset)
				end
			end
		end
	end
	return assets
end

local function randomizeProperties(target)
	local r = State.Randomizer
	if not r.Color.Enabled and not r.Transparency.Enabled then return end

	local parts = {}
	if target:IsA("BasePart") then table.insert(parts, target) else
		for _, descendant in ipairs(target:GetDescendants()) do
			if descendant:IsA("BasePart") then table.insert(parts, descendant) end
		end
	end

	for _, part in ipairs(parts) do
		if r.Color.Enabled then
			local hmin = Utils.parseNumber(UI.C.hueMinBox[1].Text, 0)
			local hmax = Utils.parseNumber(UI.C.hueMaxBox[1].Text, 0)
			local smin = Utils.parseNumber(UI.C.satMinBox[1].Text, 0)
			local smax = Utils.parseNumber(UI.C.satMaxBox[1].Text, 0)
			local vmin = Utils.parseNumber(UI.C.valMinBox[1].Text, 0)
			local vmax = Utils.parseNumber(UI.C.valMaxBox[1].Text, 0)

			local h, s, v = part.Color:ToHSV()
			h = (h + Utils.randFloat(hmin, hmax)) % 1
			s = math.clamp(s + Utils.randFloat(smin, smax), 0, 1)
			v = math.clamp(v + Utils.randFloat(vmin, vmax), 0, 1)
			part.Color = Color3.fromHSV(h, s, v)
		end
		if r.Transparency.Enabled then
			local tmin = Utils.parseNumber(UI.C.transMinBox[1].Text, 0)
			local tmax = Utils.parseNumber(UI.C.transMaxBox[1].Text, 0)
			part.Transparency = math.clamp(part.Transparency + Utils.randFloat(tmin, tmax), 0, 1)
		end
	end
end

local function applyAssetTransform(asset, position, normal, overrideScale, overrideRotation, overrideWobble)
	local s = overrideScale
	if not s then
		s = 1.0 
		if State.Randomizer.Scale.Enabled then
			local smin = Utils.parseNumber(UI.C.scaleMinBox[1].Text, 0.8)
			local smax = Utils.parseNumber(UI.C.scaleMaxBox[1].Text, 1.2)
			if smin <= 0 then smin = 0.1 end; if smax < smin then smax = smin end
			s = Utils.randFloat(smin, smax)
		end
	end

	local effectiveNormal = normal or Vector3.new(0, 1, 0)
	local randomRotation = overrideRotation

	if not randomRotation then
		local xrot, yrot, zrot
		yrot = 0
		xrot, zrot = 0, 0

		if State.Randomizer.Rotation.Enabled then
			yrot = math.rad(math.random() * 360) -- Randomize Y only if enabled

			if normal and State.surfaceAngleMode == "Floor" then
				effectiveNormal = Vector3.new(0, 1, 0)
			elseif normal and State.surfaceAngleMode == "Ceiling" then
				xrot = math.pi
				effectiveNormal = Vector3.new(0, -1, 0)
			else
				local rotXMin = math.rad(Utils.parseNumber(UI.C.rotXMinBox[1].Text, 0))
				local rotXMax = math.rad(Utils.parseNumber(UI.C.rotXMaxBox[1].Text, 0))
				local rotZMin = math.rad(Utils.parseNumber(UI.C.rotZMinBox[1].Text, 0))
				local rotZMax = math.rad(Utils.parseNumber(UI.C.rotZMaxBox[1].Text, 0))
				xrot = Utils.randFloat(rotXMin, rotXMax)
				zrot = Utils.randFloat(rotZMin, rotZMax)
			end
		end
		randomRotation = CFrame.Angles(xrot, yrot, zrot)
	end

	local assetName = asset.Name:gsub("^GHOST_", "")
	local isSticker = false
	if assetName:match("^Sticker_") then
		assetName = assetName:gsub("^Sticker_", "")
		isSticker = true
	end

	local customOffset = State.assetOffsets[assetName] or 0

	if isSticker then
		local baseScale = State.assetOffsets[assetName .. "_scale"] or 1
		local baseRotation = math.rad(State.assetOffsets[assetName .. "_rotation"] or 0)
		local baseRotationX = math.rad(State.assetOffsets[assetName .. "_rotationX"] or 0)

		-- Apply Base Scale to Random Scale
		s = s * baseScale

		-- Apply Base Rotation
		if randomRotation then
			randomRotation = randomRotation * CFrame.Angles(baseRotationX, baseRotation, 0)
		end
	end

	-- "Align to Surface" is now a global setting toggled in UI
	local shouldAlign = State.alignToSurface

	if asset:IsA("Model") and asset.PrimaryPart then
		if math.abs(s - 1) > 0.0001 then Utils.scaleModel(asset, s) end

		local finalPosition = position + (effectiveNormal * customOffset)

		if State.smartSnapEnabled then
			local downDir = -effectiveNormal
			if (not normal) or (State.surfaceAngleMode == "Off" and not shouldAlign) then downDir = Vector3.new(0, -1, 0) end

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
				rayParams.FilterDescendantsInstances = { State.previewFolder, getWorkspaceContainer(), State.pathPreviewFolder, asset }
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				local snapResult = workspace:Raycast(rayStart, downDir * 20, rayParams)
				if snapResult then
					local shift = (snapResult.Position - (finalPosition + downDir * maxDistAlongDown))
					finalPosition = finalPosition + (downDir * (shift:Dot(downDir)))
				end
			end
			asset:SetPrimaryPartCFrame(tempCFrame)
		end

		if State.snapToGridEnabled then finalPosition = Utils.snapPositionToGrid(finalPosition, State.gridSize) end

		local finalCFrame
		local forceAlign = (State.surfaceAngleMode == "Wall")
		if (forceAlign or (shouldAlign and State.surfaceAngleMode == "Off")) and normal then
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
		-- Wobble
		local wobble = overrideWobble
		if not wobble and State.Wobble.Enabled then
			local xMax = math.rad(Utils.parseNumber(UI.C.wobbleXMaxBox[1].Text, 0))
			local zMax = math.rad(Utils.parseNumber(UI.C.wobbleZMaxBox[1].Text, 0))
			wobble = CFrame.Angles(Utils.randFloat(-xMax, xMax), 0, Utils.randFloat(-zMax, zMax))
		end
		if wobble then finalCFrame = finalCFrame * wobble end

		asset:SetPrimaryPartCFrame(finalCFrame)

	elseif asset:IsA("BasePart") then
		asset.Size = asset.Size * s
		local finalYOffset = (asset.Size.Y / 2) + customOffset
		local finalPos = position + (effectiveNormal * finalYOffset)

		if State.smartSnapEnabled then
			local downDir = -effectiveNormal
			if (not normal) or (State.surfaceAngleMode == "Off" and not shouldAlign) then downDir = Vector3.new(0, -1, 0) end
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = { State.previewFolder, getWorkspaceContainer(), State.pathPreviewFolder, asset }
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			local rayStart = finalPos + (downDir * (asset.Size.Y/2 - 1))
			local snapResult = workspace:Raycast(rayStart, downDir * 20, rayParams)
			if snapResult then
				local currentBottom = finalPos + (downDir * (asset.Size.Y/2))
				local shift = snapResult.Position - currentBottom
				finalPos = finalPos + shift
			end
		end

		if State.snapToGridEnabled then finalPos = Utils.snapPositionToGrid(finalPos, State.gridSize) end
		local finalCFrame
		local forceAlign = (State.surfaceAngleMode == "Wall")
		if (forceAlign or (shouldAlign and State.surfaceAngleMode == "Off")) and normal then
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
		-- Wobble
		local wobble = overrideWobble
		if not wobble and State.Wobble.Enabled then
			local xMax = math.rad(Utils.parseNumber(UI.C.wobbleXMaxBox[1].Text, 0))
			local zMax = math.rad(Utils.parseNumber(UI.C.wobbleZMaxBox[1].Text, 0))
			wobble = CFrame.Angles(Utils.randFloat(-xMax, xMax), 0, Utils.randFloat(-zMax, zMax))
		end
		if wobble then finalCFrame = finalCFrame * wobble end

		asset.CFrame = finalCFrame
	end
	return asset
end

local function animateAssetSpawn(target)
	-- Helper to animate asset spawning (Pop effect)
	local isModel = target:IsA("Model")
	local finalSize
	if not isModel then finalSize = target.Size end

	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = 0.01 -- Start tiny

	-- Initialize at small scale
	if isModel then
		target:ScaleTo(0.01)
	else
		target.Size = finalSize * 0.01
	end

	local tw = game:GetService("TweenService"):Create(scaleValue, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Value = 1})

	local conn
	conn = scaleValue.Changed:Connect(function(val)
		-- Safety check: use pcall in case model is destroyed mid-tween
		pcall(function()
			if isModel then
				target:ScaleTo(val)
			else
				target.Size = finalSize * val
			end
		end)
	end)

	tw.Completed:Connect(function()
		conn:Disconnect()
		scaleValue:Destroy()
	end)

	tw:Play()
end

local function placeAsset(assetToClone, position, normal, overrideScale, overrideRotation, overrideWobble)
	local clone

	if assetToClone:IsA("Decal") or assetToClone:IsA("Texture") then
		-- "Sticker Mode" logic: Create a host part
		local hostPart = Instance.new("Part")
		hostPart.Name = "Sticker_" .. assetToClone.Name
		hostPart.Transparency = 1
		hostPart.Size = Vector3.new(1, 0.05, 1) -- Thin plate
		hostPart.CanCollide = false
		hostPart.Anchored = true
		hostPart.CastShadow = false

		local sticker = assetToClone:Clone()
		sticker.Parent = hostPart
		if sticker:IsA("Decal") then sticker.Face = Enum.NormalId.Top end
		if sticker:IsA("Texture") then sticker.Face = Enum.NormalId.Top end

		clone = hostPart
	else
		clone = assetToClone:Clone()
	end

	randomizeProperties(clone)
	if clone:IsA("Model") and not clone.PrimaryPart then
		for _, v in ipairs(clone:GetDescendants()) do if v:IsA("BasePart") then clone.PrimaryPart = v; break end end
	end

	-- Physics Drop Logic
	if State.PhysicsDrop.Enabled then
		-- Spawn higher for drop
		local dropHeight = 2.0 -- Studs
		local targetPos = position

		-- Use existing transform logic but override position locally if needed, 
		-- but applyAssetTransform sets the CFrame directly.
		-- We need to let applyAssetTransform do its thing, then offset it, or pass offset position.

		-- Let's pass the drop position to applyAssetTransform
		applyAssetTransform(clone, position + (normal * dropHeight), normal, overrideScale, overrideRotation, overrideWobble)

		-- Unanchor descendants for physics
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = false
				desc.CanCollide = true
			end
		end
		if clone:IsA("BasePart") then
			clone.Anchored = false
			clone.CanCollide = true
		end

		-- Schedule freezing
		task.delay(State.PhysicsDrop.Duration, function()
			if clone and clone.Parent then
				if clone:IsA("Model") then
					for _, d in ipairs(clone:GetDescendants()) do
						if d:IsA("BasePart") then 
							d.Anchored = true 
							d.CanCollide = false -- Revert to decorative collision usually, or keep true? 
							-- Standard brush behavior is usually CanCollide false for scattering debris, 
							-- but if it's a big rock, maybe true. Let's stick to Anchored=true.
							-- For now we leave CanCollide as is (true) so players can walk on it, or false?
							-- Existing logic in updateGhostPreview sets CanCollide=false for ghost.
							-- Real assets usually inherit their source properties.
							-- Let's just Anchor it.
						end
					end
				elseif clone:IsA("BasePart") then
					clone.Anchored = true
				end
			end
		end)
	else
		applyAssetTransform(clone, position, normal, overrideScale, overrideRotation, overrideWobble)
	end

	-- Trigger Juice immediately (sync) so it starts small before being parented
	animateAssetSpawn(clone)

	return clone
end

function Core.findSurfacePositionAndNormal()
	if not State.mouse then return nil, nil, nil end
	local camera = workspace.CurrentCamera
	local unitRay = camera:ViewportPointToRay(State.mouse.X, State.mouse.Y)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { State.previewFolder, getWorkspaceContainer(), State.pathPreviewFolder }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 2000, params)
	if result then
		if State.surfaceAngleMode == "Floor" and result.Normal.Y < 0.7 then return nil, nil, nil
		elseif State.surfaceAngleMode == "Wall" and math.abs(result.Normal.Y) > 0.3 then return nil, nil, nil
		elseif State.surfaceAngleMode == "Ceiling" and result.Normal.Y > -0.7 then return nil, nil, nil end
		return result.Position, result.Normal, result.Instance, result.Material
	end
	return nil, nil, nil, nil
end

-- Business Logic Functions

function Core.updateGhostPreview(position, normal)
	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then return end
	local allAssets = targetGroup:GetChildren()
	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then 
		if State.ghostModel then State.ghostModel:Destroy(); State.ghostModel = nil end
		return 
	end

	if not State.nextStampAsset or not State.nextStampAsset.Parent then
		State.nextStampAsset = getRandomWeightedAsset(activeAssets)
		State.nextStampScale = nil
		State.nextStampRotation = nil
	end

	if not State.nextStampScale then
		if State.Randomizer.Scale.Enabled then
			local smin = Utils.parseNumber(UI.C.scaleMinBox[1].Text, 0.8)
			local smax = Utils.parseNumber(UI.C.scaleMaxBox[1].Text, 1.2)
			if smin <= 0 then smin = 0.1 end; if smax < smin then smax = smin end
			State.nextStampScale = Utils.randFloat(smin, smax)
		else
			State.nextStampScale = 1.0
		end
	end

	if not State.nextStampRotation then
		local xrot, yrot, zrot = 0, 0, 0

		if State.Randomizer.Rotation.Enabled then
			local rotXMin = math.rad(Utils.parseNumber(UI.C.rotXMinBox[1].Text, 0))
			local rotXMax = math.rad(Utils.parseNumber(UI.C.rotXMaxBox[1].Text, 0))
			local rotZMin = math.rad(Utils.parseNumber(UI.C.rotZMinBox[1].Text, 0))
			local rotZMax = math.rad(Utils.parseNumber(UI.C.rotZMaxBox[1].Text, 0))
			xrot = Utils.randFloat(rotXMin, rotXMax)
			yrot = math.rad(math.random() * 360)
			zrot = Utils.randFloat(rotZMin, rotZMax)
		end

		if State.surfaceAngleMode == "Floor" and normal then
			xrot = 0; zrot = 0
		elseif State.surfaceAngleMode == "Ceiling" and normal then
			xrot = math.pi; zrot = 0
		end
		State.nextStampRotation = CFrame.Angles(xrot, yrot, zrot)
	end

	if State.Wobble.Enabled and not State.nextStampWobble then
		local xMax = math.rad(Utils.parseNumber(UI.C.wobbleXMaxBox[1].Text, 0))
		local zMax = math.rad(Utils.parseNumber(UI.C.wobbleZMaxBox[1].Text, 0))
		State.nextStampWobble = CFrame.Angles(Utils.randFloat(-xMax, xMax), 0, Utils.randFloat(-zMax, zMax))
	end

	if State.ghostModel then State.ghostModel:Destroy() end

	if State.nextStampAsset:IsA("Decal") or State.nextStampAsset:IsA("Texture") then
		local hostPart = Instance.new("Part")
		hostPart.Name = "GHOST_Sticker_" .. State.nextStampAsset.Name
		hostPart.Size = Vector3.new(1, 0.05, 1)
		hostPart.Transparency = 1
		hostPart.CanCollide = false
		hostPart.Anchored = true
		local sticker = State.nextStampAsset:Clone()
		sticker.Parent = hostPart
		if sticker:IsA("Decal") then sticker.Face = Enum.NormalId.Top end
		if sticker:IsA("Texture") then sticker.Face = Enum.NormalId.Top end
		State.ghostModel = hostPart
	else
		State.ghostModel = State.nextStampAsset:Clone()
		State.ghostModel.Name = "GHOST_" .. State.nextStampAsset.Name
	end

	if State.ghostModel:IsA("Model") and not State.ghostModel.PrimaryPart then
		for _, v in ipairs(State.ghostModel:GetDescendants()) do if v:IsA("BasePart") then State.ghostModel.PrimaryPart = v; break end end
	end

	local partsToStyle = {}
	if State.ghostModel:IsA("Model") then
		for _, d in ipairs(State.ghostModel:GetDescendants()) do table.insert(partsToStyle, d) end
	elseif State.ghostModel:IsA("BasePart") then
		table.insert(partsToStyle, State.ghostModel)
	elseif State.ghostModel:IsA("Decal") or State.ghostModel:IsA("Texture") then
		-- This case shouldn't be reached if we wrap them in parts in updateGhostPreview
		-- But we need to handle the creation of the Ghost for Decals/Textures first.
	end

	-- Calculate Color/Transparency random shifts once per "Stamp cycle" to avoid flickering
	if State.Randomizer.Transparency.Enabled and not State.nextStampTransparencyShift then
		local tmin = Utils.parseNumber(UI.C.transMinBox[1].Text, 0)
		local tmax = Utils.parseNumber(UI.C.transMaxBox[1].Text, 0)
		State.nextStampTransparencyShift = Utils.randFloat(tmin, tmax)
	end

	if State.Randomizer.Color.Enabled and not State.nextStampColorShift then
		local hmin = Utils.parseNumber(UI.C.hueMinBox[1].Text, 0)
		local hmax = Utils.parseNumber(UI.C.hueMaxBox[1].Text, 0)
		local smin = Utils.parseNumber(UI.C.satMinBox[1].Text, 0)
		local smax = Utils.parseNumber(UI.C.satMaxBox[1].Text, 0)
		local vmin = Utils.parseNumber(UI.C.valMinBox[1].Text, 0)
		local vmax = Utils.parseNumber(UI.C.valMaxBox[1].Text, 0)
		State.nextStampColorShift = {
			h = Utils.randFloat(hmin, hmax),
			s = Utils.randFloat(smin, smax),
			v = Utils.randFloat(vmin, vmax)
		}
	end

	for _, desc in ipairs(partsToStyle) do
		if desc:IsA("BasePart") then
			desc.CastShadow = false
			desc.CanCollide = false
			desc.Anchored = true
			desc.Material = Enum.Material.ForceField

			if State.Randomizer.Transparency.Enabled then
				-- Assuming ghostModel was freshly cloned from source asset, 
				-- desc.Transparency is the original asset transparency.
				-- We add the shift to it.
				local shift = State.nextStampTransparencyShift or 0
				desc.Transparency = math.clamp(desc.Transparency + shift, 0, 1)
			else
				desc.Transparency = State.ghostTransparency
			end

			if State.Randomizer.Color.Enabled then
				-- Since we re-clone the ghost model every update (lines 313-315), 
				-- desc.Color is always the original asset color.
				-- We can safely apply the shift without accumulation.
				local shift = State.nextStampColorShift or {h=0,s=0,v=0}
				local h, s, v = desc.Color:ToHSV()
				h = (h + shift.h) % 1
				s = math.clamp(s + shift.s, 0, 1)
				v = math.clamp(v + shift.v, 0, 1)
				desc.Color = Color3.fromHSV(h, s, v)
			else
				-- Only override color for actual parts if it's not a Sticker Host
				-- We know it's a Sticker Host if it has a child Decal or Texture named same as source?
				-- Or just check if the model name starts with GHOST_Sticker
				if not State.ghostModel.Name:find("Sticker") then
					desc.Color = Constants.Theme.Accent
				end
			end
		elseif (desc:IsA("Decal") or desc:IsA("Texture")) and not State.ghostModel.Name:find("Sticker") then
			desc:Destroy()
		end
	end

	State.ghostModel.Parent = State.previewFolder
	applyAssetTransform(State.ghostModel, position, normal, State.nextStampScale, State.nextStampRotation, State.nextStampWobble)
end

function Core.updatePreview()
	if not State.mouse or not State.previewPart then return end

	local showGhost = (State.currentMode ~= "Replace" and State.currentMode ~= "Erase")

	if not showGhost and State.ghostModel then
		State.ghostModel:Destroy()
		State.ghostModel = nil
	end

	if State.currentMode == "Line" and State.lineStartPoint then State.previewPart.Parent = nil
	elseif State.currentMode == "Volume" then
		State.previewPart.Parent = State.previewFolder
		local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
		local distance = math.max(1, Utils.parseNumber(UI.C.distanceBox[1].Text, 30))

		-- Always float in air for Volume mode (Space Brush behavior)
		local unitRay = workspace.CurrentCamera:ViewportPointToRay(State.mouse.X, State.mouse.Y)
		local positionInSpace = unitRay.Origin + unitRay.Direction * distance

		State.previewPart.Shape = Enum.PartType.Ball
		State.previewPart.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		State.previewPart.CFrame = CFrame.new(positionInSpace)
		State.previewPart.Color = Color3.fromRGB(150, 150, 255)
		if State.cyl then State.cyl.Parent = nil end

		if showGhost then
			Core.updateGhostPreview(positionInSpace, nil)
		end
	else
		if State.currentMode == "Paint" or State.currentMode == "Line" or State.currentMode == "Path" or State.currentMode == "Fill" then State.previewPart.Color = Color3.fromRGB(80, 255, 80)
		elseif State.currentMode == "Replace" then State.previewPart.Color = Color3.fromRGB(80, 180, 255)
		else State.previewPart.Color = Color3.fromRGB(255, 80, 80) end

		State.previewPart.Shape = Enum.PartType.Cylinder
		local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
		local surfacePos, normal = Core.findSurfacePositionAndNormal()

		if not surfacePos or not normal or State.currentMode == "Line" or State.currentMode == "Path" then
			State.previewPart.Parent = nil
			if not surfacePos and showGhost and State.ghostModel then
				State.ghostModel:Destroy(); State.ghostModel = nil
			elseif surfacePos and showGhost then
				Core.updateGhostPreview(surfacePos, normal)
			end
		else
			if State.currentMode == "Stamp" then
				State.previewPart.Parent = nil
			else
				State.previewPart.Parent = State.previewFolder
				local pos = surfacePos
				local look = Vector3.new(1, 0, 0)
				if math.abs(look:Dot(normal)) > 0.99 then look = Vector3.new(0, 0, 1) end
				local right = look:Cross(normal).Unit
				local lookActual = normal:Cross(right).Unit
				State.previewPart.CFrame = CFrame.fromMatrix(pos + normal * 0.05, normal, right, lookActual)
				State.previewPart.Size = Vector3.new(0.02, radius*2, radius*2)
			end
			if showGhost then
				Core.updateGhostPreview(surfacePos, normal)
			end
		end
	end
	if State.currentMode == "Line" and State.lineStartPoint and State.linePreviewPart then
		local endPoint, _ = Core.findSurfacePositionAndNormal()
		if endPoint then
			State.linePreviewPart.Parent = State.previewFolder
			local mag = (endPoint - State.lineStartPoint).Magnitude
			State.linePreviewPart.Size = Vector3.new(0.2, 0.2, mag)
			State.linePreviewPart.CFrame = CFrame.new(State.lineStartPoint, endPoint) * CFrame.new(0, 0, -mag/2)
		else State.linePreviewPart.Parent = nil end
	elseif State.linePreviewPart then State.linePreviewPart.Parent = nil end
end

function Core.paintAt(center, surfaceNormal)
	local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
	local density = math.max(1, math.floor(Utils.parseNumber(UI.C.densityBox[1].Text, 10)))
	local spacing = math.max(0.1, Utils.parseNumber(UI.C.spacingBox[1].Text, 1.0))

	ChangeHistoryService:SetWaypoint("Brush - Before Paint")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder")
	groupFolder.Name = "BrushGroup_" .. tostring(math.floor(os.time()))
	groupFolder.Parent = container
	local placed = {}

	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end

	local allAssets = targetGroup:GetChildren()
	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
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
			local offset2D = Utils.randomPointInCircle(radius)
			local spawnPos = planeCFrame:PointToWorldSpace(Vector3.new(offset2D.X, 0, offset2D.Z))
			local rayOrigin = spawnPos + surfaceNormal * 5; local rayDir = -surfaceNormal * 10
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { State.previewFolder, container }; params.FilterType = Enum.RaycastFilterType.Exclude
			local result = workspace:Raycast(rayOrigin, rayDir, params)
			if result and result.Instance then
				if Core.isMaterialAllowed(result.Material) and Core.isSlopeAllowed(result.Normal) and Core.isHeightAllowed(result.Position) then
					local posOnSurface = result.Position
					local ok = true
					for _, p in ipairs(placed) do if (p - posOnSurface).Magnitude < spacing then ok = false; break end end
					if ok then found = true; candidatePos = posOnSurface; candidateNormal = result.Normal end
				end
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

function Core.stampAt(center, surfaceNormal)
	-- center and surfaceNormal are passed from onDown which calls findSurfacePositionAndNormal
	-- But we need the Material, so we might need to re-find or rely on what's passed.
	-- Core.findSurfacePositionAndNormal() relies on Mouse position.

	local pos, norm, _, mat = Core.findSurfacePositionAndNormal()

	if not pos then return end -- Safety check if aiming at void
	if not Core.isMaterialAllowed(mat) then return end
	if not Core.isSlopeAllowed(norm) then return end
	if not Core.isHeightAllowed(pos) then return end

	ChangeHistoryService:SetWaypoint("Brush - Before Stamp")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder"); groupFolder.Name = "BrushStamp_" .. tostring(math.floor(os.time())); groupFolder.Parent = container

	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end
	local allAssets = targetGroup:GetChildren()

	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then groupFolder:Destroy(); return end

	local assetToPlace = State.nextStampAsset or getRandomWeightedAsset(activeAssets)
	if assetToPlace then
		local placedAsset = placeAsset(assetToPlace, center, surfaceNormal, State.nextStampScale, State.nextStampRotation, State.nextStampWobble)
		if placedAsset then placedAsset.Parent = groupFolder end
	end
	State.nextStampAsset = nil 
	State.nextStampScale = nil
	State.nextStampRotation = nil
	State.nextStampColorShift = nil
	State.nextStampTransparencyShift = nil
	State.nextStampWobble = nil
	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Stamp")
end

function Core.paintAlongLine(startPos, endPos)
	local spacing = math.max(0.1, Utils.parseNumber(UI.C.spacingBox[1].Text, 1.0))
	local vector = endPos - startPos
	local dist = vector.Magnitude
	local direction = vector.Unit
	local count = math.floor(dist / spacing)

	ChangeHistoryService:SetWaypoint("Brush - Before Line Paint")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder")
	groupFolder.Name = "BrushLine_" .. tostring(math.floor(os.time()))
	groupFolder.Parent = container

	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end
	local allAssets = targetGroup:GetChildren()
	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end

	if #activeAssets > 0 then
		for i = 0, count do
			local alpha = 0
			if count > 0 then alpha = i / count end
			-- If single point (dist < spacing), just paint once at end
			if count == 0 then alpha = 1 end

			local pointOnLine = startPos + (direction * (dist * alpha))

			-- Raycast down/against normal to find surface
			-- We assume 'Down' is generally -Y, but we can try to be smart if we had normal info.
			-- For a line drawn on surface, we typically want to project it onto the geometry.
			local rayOrigin = pointOnLine + Vector3.new(0, 5, 0) 
			local rayDir = Vector3.new(0, -10, 0)

			-- Use a broader raycast to catch walls if the line is vertical?
			-- For now, let's assume standard "drape line over terrain" behavior (Top-down projection)
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { State.previewFolder, container, State.pathPreviewFolder }
			params.FilterType = Enum.RaycastFilterType.Exclude

			local result = workspace:Raycast(rayOrigin, rayDir, params)
			local targetPos = pointOnLine
			local targetNormal = Vector3.new(0, 1, 0)
			local validSurface = true

			local resultInstance = nil
			if result then
				targetPos = result.Position
				targetNormal = result.Normal
				resultInstance = result.Instance
				if not Core.isMaterialAllowed(result.Material) then validSurface = false end
				if not Core.isSlopeAllowed(result.Normal) then validSurface = false end
			else
				-- If no surface found directly below, try raycasting towards the line end point normal if available?
				-- Fallback: just place on the line in air
			end

			-- Height check applies to final position regardless of surface hit
			if not Core.isHeightAllowed(targetPos) then validSurface = false end

			if validSurface then
				local assetToClone = getRandomWeightedAsset(activeAssets)
				if assetToClone then
					local placedAsset = placeAsset(assetToClone, targetPos, targetNormal)
					if placedAsset then placedAsset.Parent = groupFolder end
				end
			end

			if count == 0 then break end
		end
	end

	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Line Paint")
end


function Core.fillSelectedPart()
	if not State.partToFill then return end
	local density = math.max(1, math.floor(Utils.parseNumber(UI.C.densityBox[1].Text, 10)))

	ChangeHistoryService:SetWaypoint("Brush - Before Fill")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder")
	groupFolder.Name = "BrushFill_" .. tostring(math.floor(os.time()))
	groupFolder.Parent = container

	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end
	local allAssets = targetGroup:GetChildren()
	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end

	if #activeAssets > 0 then
		local cf = State.partToFill.CFrame
		local size = State.partToFill.Size

		for i = 1, density do
			local assetToClone = getRandomWeightedAsset(activeAssets)
			if assetToClone then
				local rx = Utils.randFloat(-size.X/2, size.X/2)
				local ry = Utils.randFloat(-size.Y/2, size.Y/2)
				local rz = Utils.randFloat(-size.Z/2, size.Z/2)
				local worldPos = cf * Vector3.new(rx, ry, rz)

				-- For Fill, we typically align to identity or random, not necessarily surface normal since it's volumetric.
				-- But placeAsset expects a normal. We can use UpVector.
				local normal = Vector3.new(0, 1, 0) 

				local placedAsset = placeAsset(assetToClone, worldPos, normal)
				if placedAsset then placedAsset.Parent = groupFolder end
			end
		end
	end

	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Fill")
end

function Core.eraseAt(center)
	local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
	local assets = getAssetsInRadius(center, radius)

	if #assets > 0 then
		ChangeHistoryService:SetWaypoint("Brush - Before Erase")
		for _, asset in ipairs(assets) do
			local shouldErase = true
			if State.SmartEraser.FilterMode == "CurrentGroup" then
				local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
				if targetGroup then
					-- Check if asset name exists in the current group
					if not targetGroup:FindFirstChild(asset.Name) then
						shouldErase = false
					end
				end
			end

			if shouldErase then
				asset:Destroy()
			end
		end
		ChangeHistoryService:SetWaypoint("Brush - After Erase")
	end
end

function Core.replaceAt(center)
	local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
	local assets = getAssetsInRadius(center, radius)

	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then return end
	local allAssets = targetGroup:GetChildren()
	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end
	if #activeAssets == 0 then return end

	if #assets > 0 then
		ChangeHistoryService:SetWaypoint("Brush - Before Replace")
		for _, asset in ipairs(assets) do
			local shouldReplace = true
			if State.SmartEraser.FilterMode == "CurrentGroup" then
				if not targetGroup:FindFirstChild(asset.Name) then
					shouldReplace = false
				end
			end

			if shouldReplace then
				local cf
				if asset:IsA("Model") and asset.PrimaryPart then
					cf = asset:GetPrimaryPartCFrame()
				elseif asset:IsA("BasePart") then
					cf = asset.CFrame
				else
					cf = asset:GetPivot()
				end

				local assetToClone = getRandomWeightedAsset(activeAssets)
				if assetToClone then
					local parent = asset.Parent
					local oldName = asset.Name
					asset:Destroy() -- Remove old

					local pos = cf.Position
					local up = cf.UpVector
					local placedAsset = placeAsset(assetToClone, pos, up)
					if placedAsset then 
						placedAsset.Parent = parent 
						-- If replacing, we might want to name it consistently or keep old name? 
						-- Standard behavior is new name.
					end
				end
			end
		end
		ChangeHistoryService:SetWaypoint("Brush - After Replace")
	end
end

function Core.updateFillSelection()
	if State.currentMode ~= "Fill" then
		State.partToFill = nil
		if State.fillSelectionBox then State.fillSelectionBox.Adornee = nil end
		UI.C.fillBtn[1].Text = "SELECT TARGET VOLUME"
		UI.C.fillBtn[1].TextColor3 = Constants.Theme.Text
		return
	end
	local selection = Selection:Get()
	if #selection == 1 and selection[1]:IsA("BasePart") then
		State.partToFill = selection[1]

		-- Only attempt to visualize if previewFolder exists (Active)
		if State.previewFolder then
			if not State.fillSelectionBox then
				State.fillSelectionBox = Instance.new("SelectionBox")
				State.fillSelectionBox.Color3 = Constants.Theme.Accent
				State.fillSelectionBox.LineThickness = 0.1
			end
			State.fillSelectionBox.Parent = State.previewFolder
			State.fillSelectionBox.Adornee = State.partToFill
		end

		UI.C.fillBtn[1].Text = "FILL: " .. State.partToFill.Name
		UI.C.fillBtn[1].TextColor3 = Constants.Theme.Success
	else
		State.partToFill = nil
		if State.fillSelectionBox then State.fillSelectionBox.Adornee = nil end
		UI.C.fillBtn[1].Text = "SELECT TARGET VOLUME"
		UI.C.fillBtn[1].TextColor3 = Constants.Theme.Text
	end
end

function Core.paintInVolume(center)
	local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
	local density = math.max(1, math.floor(Utils.parseNumber(UI.C.densityBox[1].Text, 10)))

	ChangeHistoryService:SetWaypoint("Brush - Before Volume Paint")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder")
	groupFolder.Name = "BrushVolume_" .. tostring(math.floor(os.time()))
	groupFolder.Parent = container

	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end
	local allAssets = targetGroup:GetChildren()
	local activeAssets = {}
	for _, asset in ipairs(allAssets) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end

	if #activeAssets > 0 then
		for i = 1, density do
			local assetToClone = getRandomWeightedAsset(activeAssets)
			if assetToClone then
				local offset = Utils.getRandomPointInSphere(radius)
				local worldPos = center + offset
				-- Random rotation for floating objects usually
				local normal = Vector3.new(0, 1, 0)

				local placedAsset = placeAsset(assetToClone, worldPos, normal)
				if placedAsset then placedAsset.Parent = groupFolder end
			end
		end
	end

	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Volume Paint")
end

function Core.updatePathPreview()
	State.pathPreviewFolder:ClearAllChildren()
	if #State.pathPoints == 0 then return end

	-- Draw Points
	for i, pt in ipairs(State.pathPoints) do
		local p = Instance.new("Part")
		p.Name = "Point" .. i
		p.Size = Vector3.new(0.5, 0.5, 0.5)
		p.Shape = Enum.PartType.Ball
		p.Anchored = true; p.CanCollide = false
		p.Color = Constants.Theme.Accent
		p.Material = Enum.Material.Neon
		p.Position = pt
		p.Parent = State.pathPreviewFolder
	end

	-- Draw Spline
	if #State.pathPoints < 2 then return end

	local stepsPerSegment = 10
	for i = 1, #State.pathPoints - 1 do
		local p0 = State.pathPoints[math.max(1, i - 1)]
		local p1 = State.pathPoints[i]
		local p2 = State.pathPoints[i + 1]
		local p3 = State.pathPoints[math.min(#State.pathPoints, i + 2)]

		local lastPos = p1
		for tStep = 1, stepsPerSegment do
			local t = tStep / stepsPerSegment
			local nextPos = Utils.catmullRom(p0, p1, p2, p3, t)

			local seg = Instance.new("Part")
			seg.Name = "Seg"
			seg.Anchored = true; seg.CanCollide = false
			seg.Material = Enum.Material.Neon
			seg.Color = Constants.Theme.Warning
			local dist = (nextPos - lastPos).Magnitude
			seg.Size = Vector3.new(0.1, 0.1, dist)
			seg.CFrame = CFrame.lookAt(lastPos, nextPos) * CFrame.new(0, 0, -dist/2)
			seg.Parent = State.pathPreviewFolder

			lastPos = nextPos
		end
	end
end

function Core.generatePathAssets()
	if #State.pathPoints < 2 then return end
	local spacing = math.max(0.1, Utils.parseNumber(UI.C.spacingBox[1].Text, 1.0))

	ChangeHistoryService:SetWaypoint("Brush - Before Path Gen")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder")
	groupFolder.Name = "BrushPath_" .. tostring(math.floor(os.time()))
	groupFolder.Parent = container

	local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
	if not targetGroup then groupFolder:Destroy(); return end
	local activeAssets = {}
	for _, asset in ipairs(targetGroup:GetChildren()) do
		local isActive = State.assetOffsets[asset.Name .. "_active"]
		if isActive == nil then isActive = true end
		if isActive then table.insert(activeAssets, asset) end
	end

	if #activeAssets > 0 then
		-- Calculate rough length to prevent infinite loops or weirdness, though we iterate segments
		for i = 1, #State.pathPoints - 1 do
			local p0 = State.pathPoints[math.max(1, i - 1)]
			local p1 = State.pathPoints[i]
			local p2 = State.pathPoints[i + 1]
			local p3 = State.pathPoints[math.min(#State.pathPoints, i + 2)]

			-- Estimate segment length with a few samples
			local segLen = 0
			local samples = 5
			local prevS = p1
			for s = 1, samples do
				local t = s / samples
				local nextS = Utils.catmullRom(p0, p1, p2, p3, t)
				segLen = segLen + (nextS - prevS).Magnitude
				prevS = nextS
			end

			local count = math.floor(segLen / spacing)
			if count < 1 then count = 1 end

			for k = 0, count - 1 do -- don't double count endpoints
				local t = k / count
				local posOnCurve = Utils.catmullRom(p0, p1, p2, p3, t)

				-- Raycast down
				local rayOrigin = posOnCurve + Vector3.new(0, 5, 0)
				local rayDir = Vector3.new(0, -10, 0)
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { State.previewFolder, container, State.pathPreviewFolder }
				params.FilterType = Enum.RaycastFilterType.Exclude
				local res = workspace:Raycast(rayOrigin, rayDir, params)

				local targetPos = posOnCurve
				local targetNormal = Vector3.new(0, 1, 0)
				local validSurface = true

				if res then 
					targetPos = res.Position; targetNormal = res.Normal 
					if not Core.isMaterialAllowed(res.Material) then validSurface = false end
					if not Core.isSlopeAllowed(res.Normal) then validSurface = false end
				end

				-- Height check applies to final position regardless of surface hit
				if not Core.isHeightAllowed(targetPos) then validSurface = false end

				if validSurface then
					local assetToClone = getRandomWeightedAsset(activeAssets)
					if assetToClone then
						local placed = placeAsset(assetToClone, targetPos, targetNormal)
						if placed then placed.Parent = groupFolder end
					end
				end
			end
		end
	end

	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Path Gen")
end

function Core.clearPath() 
	State.pathPoints = {}
	if State.pathPreviewFolder then State.pathPreviewFolder:ClearAllChildren() end
end

function Core.setMode(newMode)
	if State.currentMode == newMode then return end
	if State.currentMode == "Replace" then State.sourceAsset = nil; State.targetAsset = nil end
	if State.currentMode == "Erase" and newMode ~= "Erase" then State.eraseFilter = {} end
	State.lineStartPoint = nil
	if State.linePreviewPart then State.linePreviewPart.Parent = nil end
	if newMode ~= "Path" then Core.clearPath() end

	State.currentMode = newMode
	UI.updateModeButtonsUI()
	Core.updatePreview()
	Core.updateFillSelection()
end

-- Event Handlers
local function onMove()
	if not State.active then return end
	Core.updatePreview()
	if State.isPainting then
		local unitRay = workspace.CurrentCamera:ViewportPointToRay(State.mouse.X, State.mouse.Y)
		local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {State.previewFolder, getWorkspaceContainer(), State.pathPreviewFolder}
		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
		if result and State.lastPaintPosition then
			local spacing = math.max(0.1, Utils.parseNumber(UI.C.spacingBox[1].Text, 1.0))
			if (result.Position - State.lastPaintPosition).Magnitude >= spacing then
				if State.currentMode == "Paint" then Core.paintAt(result.Position, result.Normal)
				elseif State.currentMode == "Erase" then Core.eraseAt(result.Position)
				elseif State.currentMode == "Replace" then Core.replaceAt(result.Position)
				end
				State.lastPaintPosition = result.Position
			end
		end
	end
end

local function onDown()
	if not State.active or not State.mouse then return end

	if State.currentMode == "Volume" then
		local distance = math.max(1, Utils.parseNumber(UI.C.distanceBox[1].Text, 30))
		local unitRay = workspace.CurrentCamera:ViewportPointToRay(State.mouse.X, State.mouse.Y)
		local center = unitRay.Origin + unitRay.Direction * distance
		Core.paintInVolume(center)
		return
	end

	local center, normal, _ = Core.findSurfacePositionAndNormal()
	if not center then return end

	if State.currentMode == "Line" then
		if not State.lineStartPoint then State.lineStartPoint = center
		else 
			Core.paintAlongLine(State.lineStartPoint, center)
			State.lineStartPoint = nil 
		end
	elseif State.currentMode == "Path" then
		table.insert(State.pathPoints, center); 
		Core.updatePathPreview()
	elseif State.currentMode == "Paint" or State.currentMode == "Stamp" or State.currentMode == "Erase" or State.currentMode == "Replace" then
		if State.currentMode == "Paint" then Core.paintAt(center, normal)
		elseif State.currentMode == "Stamp" then Core.stampAt(center, normal)
		elseif State.currentMode == "Erase" then Core.eraseAt(center)
		elseif State.currentMode == "Replace" then Core.replaceAt(center)
		end

		if State.currentMode ~= "Stamp" then
			State.isPainting = true
			State.lastPaintPosition = center
		end
	end
end

local function onUp()
	State.isPainting = false
	State.lastPaintPosition = nil
end

function Core.activate()
	if State.active then return end
	State.active = true

	-- Re-create preview folders if missing
	if not State.previewFolder or not State.previewFolder.Parent then
		State.previewFolder = workspace:FindFirstChild("_BrushPreview") or Instance.new("Folder", workspace)
		State.previewFolder.Name = "_BrushPreview"
	end
	if not State.pathPreviewFolder or not State.pathPreviewFolder.Parent then
		State.pathPreviewFolder = workspace:FindFirstChild("_PathPreview") or Instance.new("Folder", workspace)
		State.pathPreviewFolder.Name = "_PathPreview"
	end

	State.previewPart = Instance.new("Part")
	State.previewPart.Name = "BrushRadiusPreview"
	State.previewPart.Anchored = true; State.previewPart.CanCollide = false; State.previewPart.Transparency = 0.6; State.previewPart.Material = Enum.Material.Neon
	State.linePreviewPart = Instance.new("Part")
	State.linePreviewPart.Name = "BrushLinePreview"
	State.linePreviewPart.Anchored = true; State.linePreviewPart.CanCollide = false; State.linePreviewPart.Transparency = 0.5; State.linePreviewPart.Material = Enum.Material.Neon

	pluginInstance:Activate(true)
	State.mouse = pluginInstance:GetMouse()
	moveConn = State.mouse.Move:Connect(onMove)
	downConn = State.mouse.Button1Down:Connect(onDown)
	upConn = State.mouse.Button1Up:Connect(onUp)

	Core.updatePreview()
	Core.updateFillSelection()
	-- toolbarBtn:SetActive(true) -- Handled in Main or callback
	UI.updateOnOffButtonUI()
end

function Core.deactivate()
	if not State.active then return end
	State.active = false
	if moveConn then moveConn:Disconnect(); moveConn = nil end
	if downConn then downConn:Disconnect(); downConn = nil end
	if upConn then upConn:Disconnect(); upConn = nil end
	State.isPainting = false; State.lastPaintPosition = nil; State.lineStartPoint = nil
	Core.clearPath(); State.mouse = nil
	if State.previewPart then State.previewPart:Destroy(); State.previewPart = nil; State.cyl = nil end
	if State.linePreviewPart then State.linePreviewPart:Destroy(); State.linePreviewPart = nil end
	if State.ghostModel then State.ghostModel:Destroy(); State.ghostModel = nil end
	if State.fillSelectionBox then State.fillSelectionBox.Adornee = nil end

	-- Destroy folders on deactivate
	if State.previewFolder then State.previewFolder:Destroy(); State.previewFolder = nil end
	if State.pathPreviewFolder then State.pathPreviewFolder:Destroy(); State.pathPreviewFolder = nil end

	-- toolbarBtn:SetActive(false)
	UI.updateOnOffButtonUI()
end

return Core
