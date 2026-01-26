--[[
    99 Nights In The Forest - Map Explorer Debug Script
    Logs all items, targets, structures, and map data
    Run this on an unlocked map to see everything
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local output = {}

local function add(text)
	table.insert(output, text)
	print(text)
end

local function separator(title)
	add("\n" .. string.rep("=", 60))
	add("  " .. title)
	add(string.rep("=", 60))
end

-- ============================================================================
-- PLAYER INFO
-- ============================================================================
separator("PLAYER INFO")
add("Name: " .. LocalPlayer.Name)
add("UserId: " .. LocalPlayer.UserId)

-- Attributes
add("\n-- Player Attributes --")
for _, attr in ipairs({ "Hunger", "Warmth", "Temperature", "Health", "Stamina", "Thirst" }) do
	local val = LocalPlayer:GetAttribute(attr)
	if val then
		add(attr .. " = " .. tostring(val))
	end
end

-- ============================================================================
-- PLAYER INVENTORY
-- ============================================================================
separator("PLAYER INVENTORY")

local inv = LocalPlayer:FindFirstChild("Inventory")
if inv then
	add("Inventory folder found!")
	for i, item in ipairs(inv:GetChildren()) do
		add(i .. ". " .. item.Name .. " (" .. item.ClassName .. ")")
	end
else
	add("No Inventory folder!")
end

local itemBag = LocalPlayer:FindFirstChild("ItemBag")
if itemBag then
	add("\n-- Item Bag Contents --")
	for i, item in ipairs(itemBag:GetChildren()) do
		add(i .. ". " .. item.Name .. " (" .. item.ClassName .. ")")
	end
end

-- ============================================================================
-- REMOTE EVENTS
-- ============================================================================
separator("REMOTE EVENTS")

local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
if remotes then
	add("Total remotes: " .. #remotes:GetChildren())
	add("\n-- Key Remotes --")
	local keyRemotes = {
		"DamagePlayer",
		"ToolDamageObject",
		"RequestConsumeItem",
		"RequestPlantItem",
		"RequestCookItem",
		"RequestBurnItem",
		"RequestBagStoreItem",
		"RequestBagDropItem",
		"RequestStartDraggingItem",
		"StopDraggingItem",
		"RequestScrapItem",
		"RequestSelectRecipe",
		"RequestAddAnvilIngredient",
		"RequestOpenItemChest",
		"ToggleDoor",
		"RequestLavaBurnItem",
		"EquipItemHandle",
		"UnequipItemHandle",
		"RequestEquipArmour",
		"RequestUpgradeDefense",
	}
	for _, name in ipairs(keyRemotes) do
		local r = remotes:FindFirstChild(name)
		if r then
			add("✓ " .. name .. " (" .. r.ClassName .. ")")
		else
			add("✗ " .. name .. " (NOT FOUND)")
		end
	end
end

-- ============================================================================
-- WORKSPACE ITEMS
-- ============================================================================
separator("WORKSPACE ITEMS")

local items = Workspace:FindFirstChild("Items")
if items then
	add("Total items in world: " .. #items:GetChildren())
	add("\n-- Item Types --")
	local types = {}
	for _, item in ipairs(items:GetChildren()) do
		types[item.Name] = (types[item.Name] or 0) + 1
	end
	for name, count in pairs(types) do
		add(name .. ": " .. count)
	end
end

-- ============================================================================
-- WORKSPACE CHARACTERS (Enemies/NPCs)
-- ============================================================================
separator("CHARACTERS / ENEMIES")

local chars = Workspace:FindFirstChild("Characters")
if chars then
	add("Total characters: " .. #chars:GetChildren())
	add("\n-- Character Types --")
	local types = {}
	for _, char in ipairs(chars:GetChildren()) do
		local name = char.Name
		types[name] = (types[name] or 0) + 1
	end
	for name, count in pairs(types) do
		add(name .. ": " .. count)
	end
else
	add("No Characters folder!")
end

-- ============================================================================
-- MAP STRUCTURE
-- ============================================================================
separator("MAP STRUCTURE")

local map = Workspace:FindFirstChild("Map")
if map then
	add("Map found! Children:")
	for _, child in ipairs(map:GetChildren()) do
		add("  - " .. child.Name .. " (" .. child.ClassName .. ")")
	end

	-- Campground
	local camp = map:FindFirstChild("Campground")
	if camp then
		add("\n-- Campground Contents --")
		for _, obj in ipairs(camp:GetChildren()) do
			add("  - " .. obj.Name .. " (" .. obj.ClassName .. ")")
		end
	end

	-- Landmarks
	local landmarks = map:FindFirstChild("Landmarks")
	if landmarks then
		add("\n-- Landmarks --")
		for _, obj in ipairs(landmarks:GetChildren()) do
			add("  - " .. obj.Name .. " (" .. obj.ClassName .. ")")
		end
	end

	-- Foliage
	local foliage = map:FindFirstChild("Foliage")
	if foliage then
		add("\n-- Foliage Types --")
		local types = {}
		for _, f in ipairs(foliage:GetChildren()) do
			types[f.Name] = (types[f.Name] or 0) + 1
		end
		for name, count in pairs(types) do
			add(name .. ": " .. count)
		end
	end
else
	add("No Map found!")
end

-- ============================================================================
-- REPLICATED STORAGE
-- ============================================================================
separator("REPLICATED STORAGE")

add("ReplicatedStorage children:")
for _, child in ipairs(ReplicatedStorage:GetChildren()) do
	add("  - " .. child.Name .. " (" .. child.ClassName .. ")")
end

-- TempStorage
local temp = ReplicatedStorage:FindFirstChild("TempStorage")
if temp then
	add("\n-- TempStorage Contents --")
	local count = #temp:GetChildren()
	add("Total items: " .. count)
	if count <= 20 then
		for _, item in ipairs(temp:GetChildren()) do
			add("  - " .. item.Name)
		end
	end
end

-- ============================================================================
-- FIRE INFO
-- ============================================================================
separator("FIRE / CAMPFIRE INFO")

local campMap = map and map:FindFirstChild("Campground")
local mainFire = campMap and campMap:FindFirstChild("MainFire")
if mainFire then
	add("MainFire found!")
	add("Class: " .. mainFire.ClassName)

	-- Check fire level attribute
	local fireLevel = mainFire:GetAttribute("Level") or mainFire:GetAttribute("FireLevel")
	if fireLevel then
		add("Fire Level: " .. tostring(fireLevel))
	end

	-- Children
	add("Children:")
	for _, child in ipairs(mainFire:GetChildren()) do
		add("  - " .. child.Name .. " (" .. child.ClassName .. ")")
	end
else
	add("MainFire not found in Campground!")
end

-- ============================================================================
-- OUTPUT TO CLIPBOARD
-- ============================================================================
separator("DEBUG COMPLETE")

local fullOutput = table.concat(output, "\n")
add("\nTotal lines: " .. #output)

-- Copy to clipboard
if setclipboard then
	setclipboard(fullOutput)
	add("✓ Copied to clipboard!")
else
	add("✗ setclipboard not available")
end

-- Return for Logger
return fullOutput
