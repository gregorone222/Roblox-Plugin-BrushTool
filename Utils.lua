local Utils = {}

function Utils.trim(s)
	return s:match("^%s*(.-)%s*$") or s
end

function Utils.parseNumber(txt, fallback)
	local ok, n = pcall(function() return tonumber(Utils.trim(txt)) end)
	if ok and n then return n end
	return fallback
end

function Utils.randFloat(a, b)
	return a + math.random() * (b - a)
end

function Utils.randomPointInCircle(radius)
	local r = radius * math.sqrt(math.random())
	local theta = math.random() * 2 * math.pi
	return Vector3.new(r * math.cos(theta), 0, r * math.sin(theta))
end

function Utils.getRandomPointInSphere(radius)
	local u = math.random()
	local v = math.random()
	local theta = u * 2 * math.pi
	local phi = math.acos(2 * v - 1)
	local r = math.pow(math.random(), 1/3) * radius
	return Vector3.new(r * math.sin(phi) * math.cos(theta), r * math.sin(phi) * math.sin(theta), r * math.cos(phi))
end

function Utils.catmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

function Utils.scaleModel(model, scale)
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

function Utils.snapPositionToGrid(position, size)
	if size <= 0 then return position end
	local x = math.floor(position.X / size + 0.5) * size
	local y = math.floor(position.Y / size + 0.5) * size
	local z = math.floor(position.Z / size + 0.5) * size
	return Vector3.new(x, y, z)
end

return Utils
