--[[
    Core/Utils.lua
    Shared utility functions for all features
]]

local Utils = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

Utils.LocalPlayer = Players.LocalPlayer

Utils.Config = nil

-- Logger reference (set by MainInterface)
Utils.Logger = nil

local LOG_LEVELS = {
	Debug = 1,
	Info = 2,
	Success = 2,
	Warning = 3,
	Error = 4,
}

local logThrottle = {}
local statLogThrottle = {}

local function normalize(text)
	return string.lower(text or "")
end

-- ============================================
-- LOGGING
-- ============================================
function Utils.log(msg, level)
	level = level or "Info"
	if Utils.Config and Utils.Config.System then
		local system = Utils.Config.System
		if system.SilentMode and level ~= "Error" then
			return
		end
		local minLevel = LOG_LEVELS[system.LogLevel or "Info"] or LOG_LEVELS.Info
		local current = LOG_LEVELS[level] or LOG_LEVELS.Info
		if current < minLevel then
			return
		end
	end
	if Utils.Logger then
		Utils.Logger.Add("[OP] " .. msg, level)
	else
		print("[OP][" .. level .. "] " .. msg)
	end
end

function Utils.SetLogger(logger)
	Utils.Logger = logger
end

function Utils.SetConfig(config)
	Utils.Config = config
end

function Utils.logThrottled(key, msg, level, cooldown)
	local now = os.clock()
	local last = logThrottle[key] or 0
	local waitTime = cooldown or 5
	if now - last >= waitTime then
		logThrottle[key] = now
		Utils.log(msg, level)
	end
end

function Utils.matchAny(name, patterns)
	local lower = normalize(name)
	for _, pattern in ipairs(patterns or {}) do
		if string.find(lower, normalize(pattern), 1, true) then
			return true
		end
	end
	return false
end

-- ============================================
-- CHARACTER & POSITION
-- ============================================
function Utils.getCharacter()
	return Utils.LocalPlayer.Character
end

function Utils.getRoot()
	local char = Utils.getCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

function Utils.getHumanoid()
	local char = Utils.getCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

function Utils.getModelPosition(model)
	if not model then
		return nil
	end

	if model:IsA("BasePart") then
		return model.Position
	end

	if model:IsA("Model") then
		-- Try GetPivot first (modern method)
		local ok, pivot = pcall(function()
			return model:GetPivot()
		end)
		if ok and pivot then
			return pivot.Position
		end

		-- Fallback to PrimaryPart or first BasePart
		local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if primary then
			return primary.Position
		end
	end

	return nil
end

function Utils.distanceTo(target)
	local root = Utils.getRoot()
	local targetPos = Utils.getModelPosition(target)
	if root and targetPos then
		return (targetPos - root.Position).Magnitude
	end
	return math.huge
end

-- ============================================
-- GAME DATA GETTERS
-- ============================================
function Utils.getStat(name)
	local value = Utils.LocalPlayer:GetAttribute(name)
	if value ~= nil and Utils.Config and Utils.Config.System and Utils.Config.System.LogStats then
		local cooldown = Utils.Config.System.StatLogCooldown or 10
		local now = os.clock()
		local last = statLogThrottle[name] or 0
		if now - last >= cooldown then
			statLogThrottle[name] = now
			Utils.log("getStat('" .. name .. "'): " .. tostring(value), "Debug")
		end
	end
	return value
end

function Utils.getInventory()
	return Utils.LocalPlayer:FindFirstChild("Inventory")
end

function Utils.getItemBag()
	return Utils.LocalPlayer:FindFirstChild("ItemBag")
end

function Utils.getBagTool()
	local inv = Utils.getInventory()
	if not inv then
		return nil
	end
	-- Old Sack or Good Sack
	return inv:FindFirstChild("Old Sack") or inv:FindFirstChild("Good Sack") or inv:FindFirstChildWhichIsA("Tool")
end

-- ============================================
-- WORKSPACE FOLDERS
-- ============================================
function Utils.getMap()
	return Workspace:FindFirstChild("Map")
end

function Utils.getCampground()
	local map = Utils.getMap()
	return map and map:FindFirstChild("Campground")
end

function Utils.getMainFire()
	local camp = Utils.getCampground()
	return camp and camp:FindFirstChild("MainFire")
end

function Utils.getFoliage()
	local map = Utils.getMap()
	return map and map:FindFirstChild("Foliage")
end

function Utils.getLandmarks()
	local map = Utils.getMap()
	return map and map:FindFirstChild("Landmarks")
end

function Utils.getToolWorkshop()
	local landmarks = Utils.getLandmarks()
	return landmarks and landmarks:FindFirstChild("ToolWorkshop")
end

function Utils.getCraftingBench()
	local camp = Utils.getCampground()
	return camp and camp:FindFirstChild("CraftingBench")
end

function Utils.getCharactersFolder()
	return Workspace:FindFirstChild("Characters")
end

function Utils.getItemsFolder()
	return Workspace:FindFirstChild("Items")
end

function Utils.getTempStorage()
	return ReplicatedStorage:FindFirstChild("TempStorage")
end

-- ============================================
-- MODEL UTILITIES
-- ============================================
function Utils.isAlive(model)
	if not model then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

function Utils.isPlayerModel(model)
	return Players:GetPlayerFromCharacter(model) ~= nil
end

-- ============================================
-- WEAPON DETECTION
-- ============================================
local WEAPON_KEYWORDS = { "Axe", "Sword", "Hammer", "Pickaxe", "Spear", "Knife", "Blade", "Club" }

function Utils.isWeaponName(name)
	return Utils.matchAny(name, WEAPON_KEYWORDS)
end

function Utils.equipTool(toolName)
	-- Check if already equipped
	local char = Utils.getCharacter()
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") or (child:IsA("Model") and Utils.isWeaponName(child.Name)) then
				return child
			end
		end
	end

	-- Find in Inventory
	local inv = Utils.getInventory()
	if not inv then
		return nil
	end

	local items = inv:GetChildren()

	-- Specific tool requested
	if toolName then
		local tool = inv:FindFirstChild(toolName)
		if tool then
			return tool
		end
	end

	-- Find by weapon name
	for _, child in ipairs(items) do
		if Utils.isWeaponName(child.Name) then
			Utils.log("equipTool: Found " .. child.Name, "Success")
			return child
		end
	end

	-- Any Tool class
	for _, child in ipairs(items) do
		if child:IsA("Tool") then
			return child
		end
	end

	-- Any Model (not bags)
	for _, child in ipairs(items) do
		if child:IsA("Model") and not string.find(child.Name, "Sack") then
			return child
		end
	end

	return nil
end

-- ============================================
-- PATTERN GENERATORS (for AutoPlant)
-- ============================================
function Utils.getCirclePositions(center, radius, innerRadius, spacing)
	local positions = {}
	for r = innerRadius, radius, spacing do
		local circumference = 2 * math.pi * r
		local count = math.max(1, math.floor(circumference / spacing))
		for i = 1, count do
			local angle = (i / count) * 2 * math.pi
			local x = center.X + r * math.cos(angle)
			local z = center.Z + r * math.sin(angle)
			table.insert(positions, Vector3.new(x, center.Y, z))
		end
	end
	return positions
end

function Utils.getGridPositions(center, rows, cols, spacing)
	local positions = {}
	local startX = center.X - (cols - 1) * spacing / 2
	local startZ = center.Z - (rows - 1) * spacing / 2
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local x = startX + col * spacing
			local z = startZ + row * spacing
			table.insert(positions, Vector3.new(x, center.Y, z))
		end
	end
	return positions
end

function Utils.getSpiralPositions(center, radius, spacing)
	local positions = {}
	local a = 0
	local b = spacing / (2 * math.pi)
	local maxAngle = radius / b

	for angle = 0, maxAngle, 0.5 do
		local r = a + b * angle
		local x = center.X + r * math.cos(angle)
		local z = center.Z + r * math.sin(angle)
		table.insert(positions, Vector3.new(x, center.Y, z))
	end
	return positions
end

-- ============================================
-- HIT ID GENERATOR
-- ============================================
function Utils.hitId()
	return tostring(math.random(1, 99)) .. "_" .. tostring(os.time())
end

return Utils
