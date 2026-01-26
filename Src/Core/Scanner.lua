--[[
    Core/Scanner.lua
    Dynamic scanning system for game data
    
    Scans items, enemies, foliage types and caches results
    with auto-rescan capability
]]

local Scanner = {}

local Utils -- Will be set after require

-- Scan data cache
Scanner.Data = {
	-- World items (grouped by type)
	Items = {},
	ItemCounts = {},

	-- Enemy types
	Enemies = {},
	EnemyCounts = {},

	-- Foliage types
	FoliageTypes = {},
	FoliageCounts = {},

	-- Player inventory
	Inventory = {},

	-- Bag contents
	BagContents = {},

	-- Landmarks
	Landmarks = {},

	-- Timestamps
	LastScan = 0,
	LastItemScan = 0,
	LastEnemyScan = 0,
	LastFoliageScan = 0,
}

-- Logger
local log = function(msg, level)
	print("[Scanner][" .. (level or "Info") .. "] " .. msg)
end

function Scanner.SetLogger(logFn)
	log = logFn
end

function Scanner.SetUtils(utils)
	Utils = utils
end

-- ============================================
-- SCAN ITEMS
-- ============================================
function Scanner.ScanItems()
	local items = Utils.getItemsFolder()
	if not items then
		log("Items folder not found!", "Warning")
		return {}
	end

	Scanner.Data.Items = {}
	Scanner.Data.ItemCounts = {}

	for _, item in ipairs(items:GetChildren()) do
		local name = item.Name
		Scanner.Data.ItemCounts[name] = (Scanner.Data.ItemCounts[name] or 0) + 1

		if not Scanner.Data.Items[name] then
			Scanner.Data.Items[name] = {}
		end
		table.insert(Scanner.Data.Items[name], item)
	end

	Scanner.Data.LastItemScan = os.time()
	log("Scanned " .. #items:GetChildren() .. " items", "Success")

	return Scanner.Data.ItemCounts
end

-- ============================================
-- SCAN ENEMIES
-- ============================================
function Scanner.ScanEnemies()
	local chars = Utils.getCharactersFolder()
	if not chars then
		log("Characters folder not found!", "Warning")
		return {}
	end

	Scanner.Data.Enemies = {}
	Scanner.Data.EnemyCounts = {}

	for _, char in ipairs(chars:GetChildren()) do
		local name = char.Name
		Scanner.Data.EnemyCounts[name] = (Scanner.Data.EnemyCounts[name] or 0) + 1

		if not Scanner.Data.Enemies[name] then
			Scanner.Data.Enemies[name] = {}
		end
		table.insert(Scanner.Data.Enemies[name], char)
	end

	Scanner.Data.LastEnemyScan = os.time()
	log("Scanned " .. #chars:GetChildren() .. " characters", "Success")

	return Scanner.Data.EnemyCounts
end

-- ============================================
-- SCAN FOLIAGE
-- ============================================
function Scanner.ScanFoliage()
	local foliage = Utils.getFoliage()
	if not foliage then
		log("Foliage folder not found!", "Warning")
		return {}
	end

	Scanner.Data.FoliageTypes = {}
	Scanner.Data.FoliageCounts = {}

	for _, node in ipairs(foliage:GetChildren()) do
		local name = node.Name
		Scanner.Data.FoliageCounts[name] = (Scanner.Data.FoliageCounts[name] or 0) + 1

		if not Scanner.Data.FoliageTypes[name] then
			Scanner.Data.FoliageTypes[name] = {}
		end
		table.insert(Scanner.Data.FoliageTypes[name], node)
	end

	Scanner.Data.LastFoliageScan = os.time()
	log("Scanned " .. #foliage:GetChildren() .. " nodes", "Success")

	return Scanner.Data.FoliageCounts
end

-- ============================================
-- SCAN INVENTORY
-- ============================================
function Scanner.ScanInventory()
	local inv = Utils.getInventory()
	if not inv then
		log("Inventory not found!", "Warning")
		return {}
	end

	Scanner.Data.Inventory = {}

	for _, item in ipairs(inv:GetChildren()) do
		table.insert(Scanner.Data.Inventory, {
			Name = item.Name,
			Class = item.ClassName,
			Instance = item,
		})
	end

	log("Scanned " .. #Scanner.Data.Inventory .. " inventory items", "Success")

	return Scanner.Data.Inventory
end

-- ============================================
-- SCAN BAG CONTENTS
-- ============================================
function Scanner.ScanBag()
	local bag = Utils.getItemBag()
	if not bag then
		log("ItemBag not found!", "Warning")
		return {}
	end

	Scanner.Data.BagContents = {}

	-- Bag contents are stored as attributes
	local attrs = bag:GetAttributes()
	for name, value in pairs(attrs) do
		Scanner.Data.BagContents[name] = {
			Count = value,
			Source = "Attribute",
		}
	end

	-- Also check children (instances)
	for _, item in ipairs(bag:GetChildren()) do
		local entry = Scanner.Data.BagContents[item.Name] or {}
		entry.Instance = item
		entry.Source = entry.Source or "Child"
		entry.Count = entry.Count or 1
		Scanner.Data.BagContents[item.Name] = entry
	end

	log("Scanned bag contents", "Success")

	return Scanner.Data.BagContents
end

-- ============================================
-- SCAN LANDMARKS
-- ============================================
function Scanner.ScanLandmarks()
	local landmarks = Utils.getLandmarks()
	if not landmarks then
		log("Landmarks not found!", "Warning")
		return {}
	end

	Scanner.Data.Landmarks = {}

	for _, landmark in ipairs(landmarks:GetChildren()) do
		table.insert(Scanner.Data.Landmarks, {
			Name = landmark.Name,
			Instance = landmark,
			Position = Utils.getModelPosition(landmark),
		})
	end

	log("Scanned " .. #Scanner.Data.Landmarks .. " landmarks", "Success")

	return Scanner.Data.Landmarks
end

-- ============================================
-- SCAN ALL
-- ============================================
function Scanner.ScanAll()
	log("Starting full scan...", "Info")

	Scanner.ScanItems()
	Scanner.ScanEnemies()
	Scanner.ScanFoliage()
	Scanner.ScanInventory()
	Scanner.ScanBag()
	Scanner.ScanLandmarks()

	Scanner.Data.LastScan = os.time()
	log("Full scan complete!", "Success")

	return Scanner.Data
end

-- ============================================
-- GET DATA (with optional auto-rescan)
-- ============================================
function Scanner.GetItems(maxAge)
	maxAge = maxAge or 30
	if os.time() - Scanner.Data.LastItemScan > maxAge then
		Scanner.ScanItems()
	end
	return Scanner.Data.Items, Scanner.Data.ItemCounts
end

function Scanner.GetEnemies(maxAge)
	maxAge = maxAge or 30
	if os.time() - Scanner.Data.LastEnemyScan > maxAge then
		Scanner.ScanEnemies()
	end
	return Scanner.Data.Enemies, Scanner.Data.EnemyCounts
end

function Scanner.GetFoliage(maxAge)
	maxAge = maxAge or 30
	if os.time() - Scanner.Data.LastFoliageScan > maxAge then
		Scanner.ScanFoliage()
	end
	return Scanner.Data.FoliageTypes, Scanner.Data.FoliageCounts
end

return Scanner
