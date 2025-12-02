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

function Core.getOutputParent(assetName)
	local mainContainer = getWorkspaceContainer()

	if State.Output.Mode == "Fixed" then
		local folderName = Utils.trim(State.Output.FixedFolderName)
		if folderName == "" then folderName = "BrushOutput" end

		local target = mainContainer:FindFirstChild(folderName)
		if not target then
			target = Instance.new("Folder")
			target.Name = folderName
			target.Parent = mainContainer
		end
		return target

	elseif State.Output.Mode == "Grouped" then
		local folderName = assetName or "Unknown"
		local target = mainContainer:FindFirstChild(folderName)
		if not target then
			target = Instance.new("Folder")
			target.Name = folderName
			target.Parent = mainContainer
		end
		return target

	else -- "PerStroke"
		return nil
	end
end

function Core.isMaterialAllowed(material)
	if not State.MaterialFilter.Enabled then return true end
	return State.MaterialFilter.Whitelist[material] == true
end

function Core.isSlopeAllowed(normal)
	if not State.SlopeFilter.Enabled then return true end
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

-- Modified applyAssetTransform to accept properties instead of generating random ones
local function applyAssetTransform(asset, position, normal, scale, rotation, wobble)
	local effectiveNormal = normal or Vector3.new(0, 1, 0)

	local assetName = asset.Name:gsub("^GHOST_", "")
	local isSticker = false
	if assetName:match("^Sticker_") then
		assetName = assetName:gsub("^Sticker_", "")
		isSticker = true
	end

	local customOffset = State.assetOffsets[assetName] or 0
	local finalScale = scale or 1.0

	-- Pre-calc sticker base transforms (since they are constant per asset type)
	if isSticker then
		local baseScale = State.assetOffsets[assetName .. "_scale"] or 1
		local baseRotation = math.rad(State.assetOffsets[assetName .. "_rotation"] or 0)
		local baseRotationX = math.rad(State.assetOffsets[assetName .. "_rotationX"] or 0)

		finalScale = finalScale * baseScale
		if rotation then
			rotation = rotation * CFrame.Angles(baseRotationX, baseRotation, 0)
		end
	end

	local shouldAlign = State.alignToSurface

	if asset:IsA("Model") and asset.PrimaryPart then
		if math.abs(finalScale - 1) > 0.0001 then Utils.scaleModel(asset, finalScale) end

		local finalPosition = position + (effectiveNormal * customOffset)

		if State.smartSnapEnabled then
			local downDir = -effectiveNormal
			if (not normal) or (State.surfaceAngleMode == "Off" and not shouldAlign) then downDir = Vector3.new(0, -1, 0) end

			local tempCFrame = asset:GetPrimaryPartCFrame()
			asset:SetPrimaryPartCFrame(CFrame.new(finalPosition) * rotation)

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
			local rotatedCFrame = CFrame.new() * rotation
			local look = rotatedCFrame.LookVector
			local rightVec = look:Cross(effectiveNormal).Unit
			local lookActual = effectiveNormal:Cross(rightVec).Unit
			if rightVec.Magnitude < 0.9 then
				look = rotatedCFrame.RightVector; rightVec = look:Cross(effectiveNormal).Unit; lookActual = effectiveNormal:Cross(rightVec).Unit
			end
			finalCFrame = CFrame.fromMatrix(finalPosition, rightVec, effectiveNormal, -lookActual)
		else
			finalCFrame = CFrame.new(finalPosition) * rotation
		end

		if wobble then finalCFrame = finalCFrame * wobble end
		asset:SetPrimaryPartCFrame(finalCFrame)

	elseif asset:IsA("BasePart") then
		asset.Size = asset.Size * finalScale
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
			local rotatedCFrame = CFrame.new() * rotation
			local look = rotatedCFrame.LookVector
			local rightVec = look:Cross(effectiveNormal).Unit
			local lookActual = effectiveNormal:Cross(rightVec).Unit
			if rightVec.Magnitude < 0.9 then
				look = rotatedCFrame.RightVector; rightVec = look:Cross(effectiveNormal).Unit; lookActual = effectiveNormal:Cross(rightVec).Unit
			end
			finalCFrame = CFrame.fromMatrix(finalPos, rightVec, effectiveNormal, -lookActual)
		else
			finalCFrame = CFrame.new(finalPos) * rotation
		end

		if wobble then finalCFrame = finalCFrame * wobble end
		asset.CFrame = finalCFrame
	end
	return asset
end

local function getTransform(normal)
	local scale = 1.0
	if State.Randomizer.Scale.Enabled then
		local smin = Utils.parseNumber(UI.C.scaleMinBox[1].Text, 0.8)
		local smax = Utils.parseNumber(UI.C.scaleMaxBox[1].Text, 1.2)
		if smin <= 0 then smin = 0.1 end; if smax < smin then smax = smin end
		scale = Utils.randFloat(smin, smax)
	end

	local rotation = nil
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

	if State.surfaceAngleMode == "Floor" and normal then xrot = 0; zrot = 0
	elseif State.surfaceAngleMode == "Ceiling" and normal then xrot = math.pi; zrot = 0 end
	rotation = CFrame.Angles(xrot, yrot, zrot)

	local wobble = nil
	if State.Wobble.Enabled then
		local xMax = math.rad(Utils.parseNumber(UI.C.wobbleXMaxBox[1].Text, 0))
		local zMax = math.rad(Utils.parseNumber(UI.C.wobbleZMaxBox[1].Text, 0))
		wobble = CFrame.Angles(Utils.randFloat(-xMax, xMax), 0, Utils.randFloat(-zMax, zMax))
	end

	return scale, rotation, wobble
end

local function animateAssetSpawn(target)
	local isModel = target:IsA("Model")
	local finalSize
	if not isModel then finalSize = target.Size end
	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = 0.01
	if isModel then target:ScaleTo(0.01) else target.Size = finalSize * 0.01 end
	local tw = game:GetService("TweenService"):Create(scaleValue, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Value = 1})
	local conn
	conn = scaleValue.Changed:Connect(function(val)
		pcall(function()
			if isModel then target:ScaleTo(val) else target.Size = finalSize * val end
		end)
	end)
	tw.Completed:Connect(function() conn:Disconnect(); scaleValue:Destroy() end)
	tw:Play()
end

local function placeAsset(assetToClone, position, normal, scale, rotation, wobble)
	local clone
	if assetToClone:IsA("Decal") or assetToClone:IsA("Texture") then
		local hostPart = Instance.new("Part")
		hostPart.Name = "Sticker_" .. assetToClone.Name
		hostPart.Transparency = 1
		hostPart.Size = Vector3.new(1, 0.05, 1)
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

	applyAssetTransform(clone, position, normal, scale, rotation, wobble)
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

-- New Batch Calculation System
function Core.calculateBatch(center, normal, activeAssets)
	if not activeAssets or #activeAssets == 0 then return {} end

	local candidates = {}
	local density = 1

	if State.currentMode == "Paint" or State.currentMode == "Volume" or State.currentMode == "Fill" then
		density = math.max(1, math.floor(Utils.parseNumber(UI.C.densityBox[1].Text, 10)))
	end

	local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
	local spacing = math.max(0.1, Utils.parseNumber(UI.C.spacingBox[1].Text, 1.0))

	-- Pre-calculate transforms for density
	for i = 1, density do
		local asset = getRandomWeightedAsset(activeAssets)
		if not asset then break end

		-- Random Transforms
		local scale = 1.0
		if State.Randomizer.Scale.Enabled then
			local smin = Utils.parseNumber(UI.C.scaleMinBox[1].Text, 0.8)
			local smax = Utils.parseNumber(UI.C.scaleMaxBox[1].Text, 1.2)
			if smin <= 0 then smin = 0.1 end; if smax < smin then smax = smin end
			scale = Utils.randFloat(smin, smax)
		end

		local rotation = nil
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

		if State.surfaceAngleMode == "Floor" and normal then xrot = 0; zrot = 0
		elseif State.surfaceAngleMode == "Ceiling" and normal then xrot = math.pi; zrot = 0 end
		rotation = CFrame.Angles(xrot, yrot, zrot)

		local wobble = nil
		if State.Wobble.Enabled then
			local xMax = math.rad(Utils.parseNumber(UI.C.wobbleXMaxBox[1].Text, 0))
			local zMax = math.rad(Utils.parseNumber(UI.C.wobbleZMaxBox[1].Text, 0))
			wobble = CFrame.Angles(Utils.randFloat(-xMax, xMax), 0, Utils.randFloat(-zMax, zMax))
		end

		-- Position Calculation
		local finalPos, finalNormal = nil, normal or Vector3.new(0,1,0)

		if State.currentMode == "Stamp" then
			finalPos = center
			finalNormal = normal
			-- Only 1 for Stamp
			density = 1 
		elseif State.currentMode == "Volume" then
			local offset = Utils.getRandomPointInSphere(radius)
			finalPos = center + offset
			finalNormal = Vector3.new(0,1,0)
		elseif State.currentMode == "Paint" then
			-- Calculate Plane CFrame
			local up = normal
			local look = Vector3.new(1, 0, 0)
			if math.abs(up:Dot(look)) > 0.99 then look = Vector3.new(0, 0, 1) end
			local right = look:Cross(up).Unit
			local look_actual = up:Cross(right).Unit
			local planeCFrame = CFrame.fromMatrix(center, right, up, -look_actual)

			-- Try to find valid spot
			local attempts = 0
			while attempts < 12 do
				attempts = attempts + 1
				local offset2D = Utils.randomPointInCircle(radius)
				local spawnPos = planeCFrame:PointToWorldSpace(Vector3.new(offset2D.X, 0, offset2D.Z))
				local rayOrigin = spawnPos + normal * 5
				local rayDir = -normal * 10
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { State.previewFolder, getWorkspaceContainer(), State.pathPreviewFolder }
				params.FilterType = Enum.RaycastFilterType.Exclude
				local result = workspace:Raycast(rayOrigin, rayDir, params)

				if result and result.Instance then
					if Core.isMaterialAllowed(result.Material) and Core.isSlopeAllowed(result.Normal) and Core.isHeightAllowed(result.Position) then
						local posOnSurface = result.Position
						local overlap = false
						for _, c in ipairs(candidates) do 
							if (c.Position - posOnSurface).Magnitude < spacing then overlap = true; break end 
						end
						if not overlap then
							finalPos = posOnSurface
							finalNormal = result.Normal
							break 
						end
					end
				end
			end
		end

		if finalPos then
			table.insert(candidates, {
				Asset = asset,
				Position = finalPos,
				Normal = finalNormal,
				Scale = scale,
				Rotation = rotation,
				Wobble = wobble
			})
		end

		if State.currentMode == "Stamp" then break end
	end

	return candidates
end

function Core.calculateLineBatch(startPos, endPos, activeAssets)
	if not activeAssets or #activeAssets == 0 then return {} end
	local spacing = math.max(0.1, Utils.parseNumber(UI.C.spacingBox[1].Text, 1.0))
	local vector = endPos - startPos
	local dist = vector.Magnitude
	local direction = vector.Unit
	local count = math.floor(dist / spacing)
	local candidates = {}

	for i = 0, count do
		local alpha = 0
		if count > 0 then alpha = i / count end
		if count == 0 then alpha = 1 end
		local pointOnLine = startPos + (direction * (dist * alpha))

		local rayOrigin = pointOnLine + Vector3.new(0, 5, 0)
		local rayDir = Vector3.new(0, -10, 0)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { State.previewFolder, getWorkspaceContainer(), State.pathPreviewFolder }
		params.FilterType = Enum.RaycastFilterType.Exclude
		local result = workspace:Raycast(rayOrigin, rayDir, params)

		local targetPos = pointOnLine
		local targetNormal = Vector3.new(0, 1, 0)
		local valid = true

		if result then
			targetPos = result.Position
			targetNormal = result.Normal
			if not Core.isMaterialAllowed(result.Material) then valid = false end
			if not Core.isSlopeAllowed(result.Normal) then valid = false end
		end
		if not Core.isHeightAllowed(targetPos) then valid = false end

		if valid then
			local asset = getRandomWeightedAsset(activeAssets)
			if asset then
				local s, r, w = getTransform(targetNormal)
				table.insert(candidates, {
					Asset = asset, Position = targetPos, Normal = targetNormal,
					Scale = s, Rotation = r, Wobble = w
				})
			end
		end
	end
	return candidates
end

function Core.calculatePathBatch(activeAssets)
	if not activeAssets or #activeAssets == 0 then return {} end
	if #State.pathPoints < 2 then return {} end

	local candidates = {}
	local spacing = math.max(0.1, Utils.parseNumber(UI.C.spacingBox[1].Text, 1.0))

	-- Iterate segments
	for i = 1, #State.pathPoints - 1 do
		local p0 = State.pathPoints[math.max(1, i - 1)]
		local p1 = State.pathPoints[i]
		local p2 = State.pathPoints[i + 1]
		local p3 = State.pathPoints[math.min(#State.pathPoints, i + 2)]

		-- Estimate length
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

		for k = 0, count - 1 do
			local t = k / count
			local posOnCurve = Utils.catmullRom(p0, p1, p2, p3, t)

			local rayOrigin = posOnCurve + Vector3.new(0, 5, 0)
			local rayDir = Vector3.new(0, -10, 0)
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { State.previewFolder, getWorkspaceContainer(), State.pathPreviewFolder }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local res = workspace:Raycast(rayOrigin, rayDir, params)

			local targetPos = posOnCurve
			local targetNormal = Vector3.new(0, 1, 0)
			local valid = true
			if res then
				targetPos = res.Position; targetNormal = res.Normal
				if not Core.isMaterialAllowed(res.Material) then valid = false end
				if not Core.isSlopeAllowed(res.Normal) then valid = false end
			end
			if not Core.isHeightAllowed(targetPos) then valid = false end

			if valid then
				local asset = getRandomWeightedAsset(activeAssets)
				if asset then
					local s, r, w = getTransform(targetNormal)
					table.insert(candidates, {
						Asset = asset, Position = targetPos, Normal = targetNormal,
						Scale = s, Rotation = r, Wobble = w
					})
				end
			end
		end
	end
	return candidates
end

function Core.updateBatchGhosts(candidates)
	-- Clean up all existing active ghosts (No pooling to avoid cumulative scaling issues)
	for i, g in pairs(State.activeGhosts) do
		if g then g:Destroy() end
		State.activeGhosts[i] = nil
	end

	-- Create new ghosts for candidates
	local limit = math.min(#candidates, State.MaxPreviewGhosts or 20)

	for i = 1, limit do
		local data = candidates[i]
		local ghost = nil

		-- Create new ghost
		if data.Asset:IsA("Decal") or data.Asset:IsA("Texture") then
			local hostPart = Instance.new("Part")
			hostPart.Name = "GHOST_Sticker_" .. data.Asset.Name
			hostPart.Size = Vector3.new(1, 0.05, 1)
			hostPart.Transparency = 1
			hostPart.CanCollide = false
			hostPart.Anchored = true
			local sticker = data.Asset:Clone()
			sticker.Parent = hostPart
			if sticker:IsA("Decal") then sticker.Face = Enum.NormalId.Top end
			if sticker:IsA("Texture") then sticker.Face = Enum.NormalId.Top end
			ghost = hostPart
		else
			ghost = data.Asset:Clone()
			ghost.Name = "GHOST_" .. data.Asset.Name
		end

		-- Style it
		for _, desc in ipairs(ghost:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.CastShadow = false; desc.CanCollide = false; desc.Anchored = true; desc.Material = Enum.Material.ForceField
				desc.Color = Constants.Theme.Accent
				desc.Transparency = State.ghostTransparency
			elseif (desc:IsA("Decal") or desc:IsA("Texture")) and not ghost.Name:find("Sticker") then
				desc:Destroy()
			end
		end
		if ghost:IsA("BasePart") then
			ghost.CastShadow = false; ghost.CanCollide = false; ghost.Anchored = true; ghost.Material = Enum.Material.ForceField
			ghost.Color = Constants.Theme.Accent
			ghost.Transparency = State.ghostTransparency
		end

		State.activeGhosts[i] = ghost
		ghost.Parent = State.previewFolder
		-- Apply Transform
		applyAssetTransform(ghost, data.Position, data.Normal, data.Scale, data.Rotation, data.Wobble)
	end
end

function Core.updatePreview()
	if not State.mouse or not State.previewPart then return end

	-- Mode specific preview part updates
	local showGhost = (State.currentMode ~= "Replace" and State.currentMode ~= "Erase" and State.currentMode ~= "Line" and State.currentMode ~= "Path")

	if State.currentMode == "Volume" then
		State.previewPart.Parent = State.previewFolder
		local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
		local distance = math.max(1, Utils.parseNumber(UI.C.distanceBox[1].Text, 30))
		local unitRay = workspace.CurrentCamera:ViewportPointToRay(State.mouse.X, State.mouse.Y)
		local positionInSpace = unitRay.Origin + unitRay.Direction * distance

		State.previewPart.Shape = Enum.PartType.Ball
		State.previewPart.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		State.previewPart.CFrame = CFrame.new(positionInSpace)
		State.previewPart.Color = Color3.fromRGB(150, 150, 255)

		if showGhost and not State.isPainting then
			local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
			if targetGroup then
				local activeAssets = {}
				for _, a in ipairs(targetGroup:GetChildren()) do
					if State.assetOffsets[a.Name.."_active"] ~= false then table.insert(activeAssets, a) end
				end
				State.pendingBatch = Core.calculateBatch(positionInSpace, Vector3.new(0,1,0), activeAssets)
				Core.updateBatchGhosts(State.pendingBatch)
			end
		end

	elseif State.currentMode == "Paint" or State.currentMode == "Stamp" or State.currentMode == "Fill" or State.currentMode == "Erase" or State.currentMode == "Replace" then
		local radius = math.max(0.1, Utils.parseNumber(UI.C.radiusBox[1].Text, 10))
		local surfacePos, normal = Core.findSurfacePositionAndNormal()

		if surfacePos and normal then
			if State.currentMode == "Stamp" then
				State.previewPart.Parent = nil
			else
				State.previewPart.Parent = State.previewFolder
				State.previewPart.Shape = Enum.PartType.Cylinder
				State.previewPart.Size = Vector3.new(0.02, radius*2, radius*2)
				State.previewPart.Color = Color3.fromRGB(80, 255, 80)
				if State.currentMode == "Replace" then State.previewPart.Color = Color3.fromRGB(80, 180, 255)
				elseif State.currentMode == "Erase" then State.previewPart.Color = Color3.fromRGB(255, 80, 80) end
			end

			local pos = surfacePos
			local look = Vector3.new(1, 0, 0)
			if math.abs(look:Dot(normal)) > 0.99 then look = Vector3.new(0, 0, 1) end
			local right = look:Cross(normal).Unit
			local lookActual = normal:Cross(right).Unit
			State.previewPart.CFrame = CFrame.fromMatrix(pos + normal * 0.05, normal, right, lookActual)

			if showGhost and not State.isPainting then
				local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
				if targetGroup then
					local activeAssets = {}
					for _, a in ipairs(targetGroup:GetChildren()) do
						if State.assetOffsets[a.Name.."_active"] ~= false then table.insert(activeAssets, a) end
					end
					State.pendingBatch = Core.calculateBatch(surfacePos, normal, activeAssets)
					Core.updateBatchGhosts(State.pendingBatch)
				end
			elseif not showGhost then
				-- Hide ghosts if in Erase/Replace
				Core.updateBatchGhosts({})
			end
		else
			State.previewPart.Parent = nil
			Core.updateBatchGhosts({})
		end
	else
		-- Line, Path, etc
		if State.previewPart then State.previewPart.Parent = nil end
		Core.updateBatchGhosts({})
	end

	if State.currentMode == "Line" and State.lineStartPoint and State.linePreviewPart then
		local endPoint, _ = Core.findSurfacePositionAndNormal()
		if endPoint then
			State.linePreviewPart.Parent = State.previewFolder
			local mag = (endPoint - State.lineStartPoint).Magnitude
			State.linePreviewPart.Size = Vector3.new(0.2, 0.2, mag)
			State.linePreviewPart.CFrame = CFrame.new(State.lineStartPoint, endPoint) * CFrame.new(0, 0, -mag/2)

			-- Generate line batch ghosts
			local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
			if targetGroup then
				local activeAssets = {}
				for _, a in ipairs(targetGroup:GetChildren()) do
					if State.assetOffsets[a.Name.."_active"] ~= false then table.insert(activeAssets, a) end
				end
				State.pendingBatch = Core.calculateLineBatch(State.lineStartPoint, endPoint, activeAssets)
				Core.updateBatchGhosts(State.pendingBatch)
			end
		else 
			State.linePreviewPart.Parent = nil 
			Core.updateBatchGhosts({})
		end
	elseif State.linePreviewPart then 
		State.linePreviewPart.Parent = nil 
		if State.currentMode == "Line" then Core.updateBatchGhosts({}) end
	end

	if State.currentMode == "Path" then
		-- Generate path batch ghosts
		local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
		if targetGroup and #State.pathPoints >= 2 then
			local activeAssets = {}
			for _, a in ipairs(targetGroup:GetChildren()) do
				if State.assetOffsets[a.Name.."_active"] ~= false then table.insert(activeAssets, a) end
			end
			State.pendingBatch = Core.calculatePathBatch(activeAssets)
			Core.updateBatchGhosts(State.pendingBatch)
		end
	end
end

function Core.paintAt(center, surfaceNormal)
	ChangeHistoryService:SetWaypoint("Brush - Before Paint")
	local container = getWorkspaceContainer()
	local transientFolder = nil
	if State.Output.Mode == "PerStroke" then
		transientFolder = Instance.new("Folder")
		transientFolder.Name = "BrushGroup_" .. tostring(math.floor(os.time()))
		transientFolder.Parent = container
	end

	-- If we have pending batch data and it matches approximate location (simple check), use it
	-- Actually, if we are painting (dragging), we need to recalculate. 
	-- If it's the *first* click (onDown), we should use the pendingBatch if available.

	local batchToPlace = {}

	-- For dragging, isPainting is true. For first click, it is false in onDown before calling paintAt?
	-- Wait, onDown calls paintAt. State.isPainting is set to true AFTER first paint.
	-- So if not isPainting, we use pending.

	if not State.isPainting and State.pendingBatch and #State.pendingBatch > 0 then
		batchToPlace = State.pendingBatch
	else
		-- Calculate new batch on the fly for dragging
		local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
		if targetGroup then
			local activeAssets = {}
			for _, a in ipairs(targetGroup:GetChildren()) do
				if State.assetOffsets[a.Name.."_active"] ~= false then table.insert(activeAssets, a) end
			end
			batchToPlace = Core.calculateBatch(center, surfaceNormal, activeAssets)
		end
	end

	for _, data in ipairs(batchToPlace) do
		local placedAsset = placeAsset(data.Asset, data.Position, data.Normal, data.Scale, data.Rotation, data.Wobble)
		if placedAsset then 
			if transientFolder then placedAsset.Parent = transientFolder
			else placedAsset.Parent = Core.getOutputParent(data.Asset.Name) end
		end
	end

	if transientFolder and #transientFolder:GetChildren() == 0 then transientFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Paint")

	-- Clear pending batch after use
	State.pendingBatch = {}
	Core.updateBatchGhosts({})
end

function Core.stampAt(center, surfaceNormal)
	Core.paintAt(center, surfaceNormal)
end

function Core.paintAlongLine(startPos, endPos)
	ChangeHistoryService:SetWaypoint("Brush - Before Line Paint")
	local container = getWorkspaceContainer()

	local transientFolder = nil
	if State.Output.Mode == "PerStroke" then
		transientFolder = Instance.new("Folder")
		transientFolder.Name = "BrushLine_" .. tostring(math.floor(os.time()))
		transientFolder.Parent = container
	end

	-- Use pending batch if available (WYSIWYG), else recalculate
	local batchToPlace = {}
	if State.pendingBatch and #State.pendingBatch > 0 then
		batchToPlace = State.pendingBatch
	else
		-- Fallback
		local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
		if targetGroup then
			local activeAssets = {}
			for _, a in ipairs(targetGroup:GetChildren()) do
				if State.assetOffsets[a.Name.."_active"] ~= false then table.insert(activeAssets, a) end
			end
			batchToPlace = Core.calculateLineBatch(startPos, endPos, activeAssets)
		end
	end

	for _, data in ipairs(batchToPlace) do
		local placedAsset = placeAsset(data.Asset, data.Position, data.Normal, data.Scale, data.Rotation, data.Wobble)
		if placedAsset then 
			if transientFolder then
				placedAsset.Parent = transientFolder
			else
				placedAsset.Parent = Core.getOutputParent(data.Asset.Name)
			end
		end
	end

	if transientFolder and #transientFolder:GetChildren() == 0 then transientFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Line Paint")

	State.pendingBatch = {}
	Core.updateBatchGhosts({})
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

		-- Logic to generate Fill candidates (could be moved to calculateBatch if we pass bounds)
		-- For now, keep it simple here
		for i = 1, density do
			local assetToClone = getRandomWeightedAsset(activeAssets)
			if assetToClone then
				local rx = Utils.randFloat(-size.X/2, size.X/2)
				local ry = Utils.randFloat(-size.Y/2, size.Y/2)
				local rz = Utils.randFloat(-size.Z/2, size.Z/2)
				local worldPos = cf * Vector3.new(rx, ry, rz)
				local normal = Vector3.new(0, 1, 0) 

				-- Use defaults for fill
				local s, r, w = getTransform(normal)
				local placedAsset = placeAsset(assetToClone, worldPos, normal, s, r, w)
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
					if not targetGroup:FindFirstChild(asset.Name) then
						shouldErase = false
					end
				end
			elseif State.SmartEraser.FilterMode == "ActiveOnly" then
				local isActive = State.assetOffsets[asset.Name .. "_active"]
				if isActive == nil then isActive = true end
				if not isActive then shouldErase = false end
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
			elseif State.SmartEraser.FilterMode == "ActiveOnly" then
				local isActive = State.assetOffsets[asset.Name .. "_active"]
				if isActive == nil then isActive = true end
				if not isActive then shouldReplace = false end
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
					local s, r, w = getTransform(up)
					local placedAsset = placeAsset(assetToClone, pos, up, s, r, w)
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
	ChangeHistoryService:SetWaypoint("Brush - Before Volume Paint")
	local container = getWorkspaceContainer()
	local groupFolder = Instance.new("Folder")
	groupFolder.Name = "BrushVolume_" .. tostring(math.floor(os.time()))
	groupFolder.Parent = container

	local batchToPlace = {}
	if not State.isPainting and State.pendingBatch and #State.pendingBatch > 0 then
		batchToPlace = State.pendingBatch
	else
		local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
		if targetGroup then
			local activeAssets = {}
			for _, a in ipairs(targetGroup:GetChildren()) do
				if State.assetOffsets[a.Name.."_active"] ~= false then table.insert(activeAssets, a) end
			end
			batchToPlace = Core.calculateBatch(center, Vector3.new(0,1,0), activeAssets)
		end
	end

	for _, data in ipairs(batchToPlace) do
		local placedAsset = placeAsset(data.Asset, data.Position, data.Normal, data.Scale, data.Rotation, data.Wobble)
		if placedAsset then placedAsset.Parent = groupFolder end
	end

	if #groupFolder:GetChildren() == 0 then groupFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Volume Paint")

	State.pendingBatch = {}
	Core.updateBatchGhosts({})
end

function Core.pathUndo()
	if State.pathHistoryIndex > 0 then
		State.pathHistoryIndex = State.pathHistoryIndex - 1
		local history = State.pathHistory[State.pathHistoryIndex]
		if history then
			State.pathPoints = {unpack(history)} -- Deep copy not needed for Vector3s but safe
		else
			State.pathPoints = {}
		end
		Core.updatePathPreview()
		Core.updatePreview() -- Refresh ghosts
	end
end

function Core.pathRedo()
	if State.pathHistoryIndex < #State.pathHistory then
		State.pathHistoryIndex = State.pathHistoryIndex + 1
		local history = State.pathHistory[State.pathHistoryIndex]
		if history then
			State.pathPoints = {unpack(history)}
		end
		Core.updatePathPreview()
		Core.updatePreview()
	end
end

local function pushPathHistory()
	-- Remove forward history
	for i = #State.pathHistory, State.pathHistoryIndex + 1, -1 do
		table.remove(State.pathHistory, i)
	end

	-- Push new
	table.insert(State.pathHistory, {unpack(State.pathPoints)})
	State.pathHistoryIndex = #State.pathHistory
end

function Core.updatePathPreview()
	State.pathPreviewFolder:ClearAllChildren()
	if #State.pathPoints == 0 then return end

	-- Draw Points
	for i, pt in ipairs(State.pathPoints) do
		local p = Instance.new("Part")
		p.Name = "Point" .. i
		p.Size = Vector3.new(0.8, 0.8, 0.8)
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
			seg.Size = Vector3.new(0.25, 0.25, dist)
			seg.CFrame = CFrame.lookAt(lastPos, nextPos) * CFrame.new(0, 0, -dist/2)
			seg.Parent = State.pathPreviewFolder

			lastPos = nextPos
		end
	end
end

function Core.generatePathAssets()
	if #State.pathPoints < 2 then return end

	ChangeHistoryService:SetWaypoint("Brush - Before Path Gen")
	local container = getWorkspaceContainer()

	local transientFolder = nil
	if State.Output.Mode == "PerStroke" then
		transientFolder = Instance.new("Folder")
		transientFolder.Name = "BrushPath_" .. tostring(math.floor(os.time()))
		transientFolder.Parent = container
	end

	-- Use pending batch if available (WYSIWYG), else recalculate
	local batchToPlace = {}
	if State.pendingBatch and #State.pendingBatch > 0 then
		batchToPlace = State.pendingBatch
	else
		-- Fallback recalculation (unlikely if preview is active, but safe)
		local targetGroup = State.assetsFolder:FindFirstChild(State.currentAssetGroup)
		if targetGroup then
			local activeAssets = {}
			for _, a in ipairs(targetGroup:GetChildren()) do
				if State.assetOffsets[a.Name.."_active"] ~= false then table.insert(activeAssets, a) end
			end
			batchToPlace = Core.calculatePathBatch(activeAssets)
		end
	end

	for _, data in ipairs(batchToPlace) do
		local placedAsset = placeAsset(data.Asset, data.Position, data.Normal, data.Scale, data.Rotation, data.Wobble)
		if placedAsset then 
			if transientFolder then
				placedAsset.Parent = transientFolder 
			else
				placedAsset.Parent = Core.getOutputParent(data.Asset.Name)
			end
		end
	end

	if transientFolder and #transientFolder:GetChildren() == 0 then transientFolder:Destroy() end
	ChangeHistoryService:SetWaypoint("Brush - After Path Gen")

	-- Clear pending batch after use
	State.pendingBatch = {}
	Core.clearPath() -- Auto-clear after generate
end

function Core.clearPath() 
	State.pathPoints = {}
	State.pathHistory = {}
	State.pathHistoryIndex = 0
	if State.pathPreviewFolder then State.pathPreviewFolder:ClearAllChildren() end
	Core.updateBatchGhosts({}) -- Clear ghosts too
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
		pushPathHistory() -- Save state before adding new point? No, usually after. 
		-- Undo logic: Undo should remove the last added point. 
		-- So we push the *current* state (which includes the previous points) to history *before* modifying it?
		-- Or we treat history as a stack of states. 
		-- Standard: Push [p1], then user adds p2 -> Push [p1, p2]. 
		-- Undo -> Index moves to [p1]. 

		-- Current implementation of pushPathHistory pushes CURRENT State.pathPoints.
		-- So if we want to be able to Undo the *addition* of this point, we should push the NEW state.
		-- Wait, if we are at state A, and add point, we get state B.
		-- History: [A] -> [A, B]. Index at B. Undo -> Index at A.

		-- So:
		table.insert(State.pathPoints, center); 
		pushPathHistory()

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
