--[[
    Core/Config.lua
    Shared configuration for all OP features
    
    This module contains all settings that can be modified by the UI
]]

local Config = {
	-- ============================================
	-- 🛡️ SURVIVAL
	-- ============================================
	GodMode = {
		Enabled = false,
		FireRate = 1, -- seconds between fires
		LogFrequency = 30, -- log every N fires
	},

	AutoEat = {
		Enabled = false,
		HungerThreshold = 80,
		FoodPriority = "BestFirst", -- "BestFirst", "WorstFirst", "Any"
		SelectedFoods = {}, -- empty = all foods
		AvoidFoods = {}, -- never eat these
		AllowWorldFood = false, -- allow dragging world items into TempStorage to eat
		EatCooldown = 1.0, -- seconds between consume attempts
		WarnCooldown = 5.0, -- seconds between warning logs
	},

	AutoWarmth = {
		Enabled = false,
		WarmthThreshold = 30,
		TempThreshold = 40,
		TeleportToFire = false,
		TeleportDistance = 60,
		MoveToFire = true, -- walk to fire when teleport is off
		AutoFeedFire = false,
		FuelPriority = "Sapling", -- "Sapling", "Log", "Coal", "Any"
		PullFuelFromWorld = true, -- drag fuel from world into TempStorage
		WarnCooldown = 5.0,
	},

	-- ============================================
	-- ⚔️ COMBAT
	-- ============================================
	KillAura = {
		Enabled = false,
		Radius = 60,
		MaxHitsPerTick = 5,
		AttackPlayers = false,

		-- Target toggles
		TargetWolves = true,
		TargetBears = true,
		TargetScorpions = true,
		TargetCultists = true,
		TargetPassive = false, -- Kiwi, Bunny

		IgnoreTypes = {},
	},

	MiningAura = {
		Enabled = false,
		Radius = 60,
		MaxHitsPerTick = 10,

		-- Target categories
		TargetTrees = true,
		TargetStones = true,
		TargetBushes = false,

		-- Specific filters (empty = all in category)
		TreeTypes = {},
		StoneTypes = {},
		BushTypes = {},
	},

	-- ============================================
	-- 📦 AUTOMATION
	-- ============================================
	AutoLoot = {
		Enabled = false,
		Radius = 30,
		MaxLootPerTick = 6,
		OpenContainers = true,

		-- Categories
		LootValuables = true,
		LootResources = true,
		LootScrap = true,
		LootContainers = true,

		PriorityItems = {},
		IgnoreItems = {},
	},

	AutoPlant = {
		Enabled = false,

		-- Pattern settings
		Pattern = "Circle", -- "Circle", "Square", "Spiral"
		Radius = 20,
		InnerRadius = 5,
		Spacing = 3,

		-- Grid settings (for Square)
		Rows = 5,
		Columns = 5,

		-- Exploit settings
		PlantCount = 50,
		PlantDelay = 0.05,

		-- Location
		CenterOnPlayer = true,
	},

	AutoCraft = {
		Enabled = false,
		RecipePriority = { "Hammer", "Good Axe" },
		CraftAtWorkshop = true,
		CraftAtCampfire = true,
	},

	AutoScrap = {
		Enabled = false,
		ScrapJunk = true,
		NeverScrap = { "Rifle", "MedKit", "Bandage" },
		MaxScrapPerTick = 6,
	},

	-- ============================================
	-- 🔧 SYSTEM
	-- ============================================
	System = {
		SilentMode = false,
		LogLevel = "Info", -- "Debug", "Info", "Warning", "Error"
		LogStats = false,
		StatLogCooldown = 10, -- seconds between stat logs per stat
		AutoRescan = true,
		RescanInterval = 30, -- seconds
	},
}

-- ============================================
-- 📚 ITEM CATALOG (shared lists)
-- ============================================
Config.Items = {
	FoodValues = {
		["Cooked Steak"] = 100,
		["Cake"] = 80,
		["Cooked Morsel"] = 60,
		["Apple"] = 40,
		["Berry"] = 30,
		["Raw Meat"] = 10,
	},
	FoodKeywords = { "Steak", "Cake", "Morsel", "Apple", "Berry", "Meat", "Fish", "Cooked" },
	FuelItems = { "Sapling", "Log", "Coal" },
	LootCategories = {
		Valuables = { "Rifle", "Revolver", "Dynamite", "Bandage", "MedKit", "Gem" },
		Resources = { "Coal", "Log", "Sapling", "Stone", "Berry", "Apple", "Bolt" },
		Scrap = { "Broken", "Old Radio", "Chair", "Washing Machine", "Tyre", "Fan" },
		Containers = { "Chest", "Crate" },
	},
	ScrapItems = {
		"Broken Fan",
		"Broken Microwave",
		"Old Radio",
		"Chair",
		"Metal Chair",
		"Washing Machine",
		"Tyre",
		"Basketball",
	},
}

-- State (not configurable via UI)
Config.State = {
	Running = false,
	Threads = {},
	LastScan = 0,
}

return Config
