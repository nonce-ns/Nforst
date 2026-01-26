--[[
    UI/MainInterface.lua (Modular Version)
    99 Nights In The Forest - OP Script Interface
    
    Uses modular Core and Features system
]]

local App = {}

-- ============================================
-- LOAD MODULES VIA HTTP
-- ============================================
local BASE_URL = (getgenv and getgenv().OP_BASE_URL) or "http://192.168.1.5:8000/"

local function normalizeBasePath(base)
	if not base or base == "" then
		return nil
	end
	local normalized = base:gsub("\\", "/")
	if string.sub(normalized, -1) ~= "/" then
		normalized = normalized .. "/"
	end
	if string.sub(normalized, -4) == "Src/" or string.sub(normalized, -4) == "src/" then
		return normalized
	end
	return normalized .. "Src/"
end

local LOCAL_BASE = normalizeBasePath(getgenv and getgenv().OP_BASE_PATH)
local REMOTE_BASE = BASE_URL .. "Src/"

local function loadModule(path)
	if LOCAL_BASE and readfile and isfile then
		local localPath = LOCAL_BASE .. path
		if isfile(localPath) then
			local ok, result = pcall(function()
				return loadstring(readfile(localPath))()
			end)
			if ok then
				return result
			end
			warn("[Loader] Local load failed: " .. path .. " - " .. tostring(result))
		end
	end

	local url = REMOTE_BASE .. path
	local ok, result = pcall(function()
		return loadstring(game:HttpGet(url))()
	end)
	if ok then
		return result
	end
	warn("[Loader] Failed to load: " .. path .. " - " .. tostring(result))
	return nil
end

-- Core modules
local Config = loadModule("Core/Config.lua")
local Utils = loadModule("Core/Utils.lua")
local Remote = loadModule("Core/RemoteHandler.lua")
local Scanner = loadModule("Core/Scanner.lua")

-- Feature modules
local GodMode = loadModule("Features/GodMode.lua")
local AutoEat = loadModule("Features/AutoEat.lua")
local AutoWarmth = loadModule("Features/AutoWarmth.lua")
local KillAura = loadModule("Features/KillAura.lua")
local MiningAura = loadModule("Features/MiningAura.lua")
local AutoLoot = loadModule("Features/AutoLoot.lua")
local AutoPlant = loadModule("Features/AutoPlant.lua")
local AutoCraft = loadModule("Features/AutoCraft.lua")
local AutoScrap = loadModule("Features/AutoScrap.lua")

-- Logger reference (set in Init)
local Logger = nil

-- ============================================
-- INITIALIZE MODULES
-- ============================================
local function initModules()
	-- Set logger for Utils
	if Utils then
		Utils.SetLogger(Logger)
		Utils.SetConfig(Config)
	end
	if Remote then
		Remote.SetLogger(function(msg, level)
			Utils.log(msg, level)
		end)
	end
	if Scanner then
		Scanner.SetLogger(function(msg, level)
			Utils.log(msg, level)
		end)
		Scanner.SetUtils(Utils)
	end

	-- Init features
	if GodMode then
		GodMode.Init(Config, Utils, Remote)
	end
	if AutoEat then
		AutoEat.Init(Config, Utils, Remote)
	end
	if AutoWarmth then
		AutoWarmth.Init(Config, Utils, Remote)
	end
	if KillAura then
		KillAura.Init(Config, Utils, Remote, Scanner)
	end
	if MiningAura then
		MiningAura.Init(Config, Utils, Remote, Scanner)
	end
	if AutoLoot then
		AutoLoot.Init(Config, Utils, Remote)
	end
	if AutoPlant then
		AutoPlant.Init(Config, Utils, Remote)
	end
	if AutoCraft then
		AutoCraft.Init(Config, Utils, Remote)
	end
	if AutoScrap then
		AutoScrap.Init(Config, Utils, Remote)
	end
end

-- ============================================
-- START/STOP ALL FEATURES
-- ============================================
local function startAllFeatures()
	Config.State.Running = true

	if GodMode then
		GodMode.Start()
	end
	if AutoEat then
		AutoEat.Start()
	end
	if AutoWarmth then
		AutoWarmth.Start()
	end
	if KillAura then
		KillAura.Start()
	end
	if MiningAura then
		MiningAura.Start()
	end
	if AutoLoot then
		AutoLoot.Start()
	end
	if AutoPlant then
		AutoPlant.Start()
	end
	if AutoCraft then
		AutoCraft.Start()
	end
	if AutoScrap then
		AutoScrap.Start()
	end

	Utils.log("All features started!", "Success")
end

local function stopAllFeatures()
	Config.State.Running = false

	if GodMode then
		GodMode.Stop()
	end
	if AutoEat then
		AutoEat.Stop()
	end
	if AutoWarmth then
		AutoWarmth.Stop()
	end
	if KillAura then
		KillAura.Stop()
	end
	if MiningAura then
		MiningAura.Stop()
	end
	if AutoLoot then
		AutoLoot.Stop()
	end
	if AutoPlant then
		AutoPlant.Stop()
	end
	if AutoCraft then
		AutoCraft.Stop()
	end
	if AutoScrap then
		AutoScrap.Stop()
	end

	Utils.log("All features stopped!", "Warning")
end

-- ============================================
-- BUILD UI
-- ============================================
local function createUI(WindUI)
	local Window = WindUI:CreateWindow({
		Title = "99 Nights OP",
		Icon = "rbxassetid://0",
		Author = "OP Script",
		Folder = "99NightsOP",
		Size = UDim2.fromOffset(500, 400),
		Transparent = true,
		Theme = "Dark",
		SideBarWidth = 180,
		HasOutline = false,
	})

	-- ========================================
	-- TAB: SURVIVAL
	-- ========================================
	local SurvivalTab = Window:Tab({ Title = "🛡️ Survival", Icon = "heart" })

	-- God Mode Section
	local GodSection = SurvivalTab:Section({ Title = "God Mode" })
	GodSection:Toggle({
		Title = "Enable God Mode",
		Default = Config.GodMode.Enabled,
		Callback = function(v)
			Config.GodMode.Enabled = v
			Utils.log("GodMode: " .. (v and "ON" or "OFF"), "Info")
		end,
	})

	-- Auto Eat Section
	local EatSection = SurvivalTab:Section({ Title = "Auto Eat" })
	EatSection:Toggle({
		Title = "Enable Auto Eat",
		Default = Config.AutoEat.Enabled,
		Callback = function(v)
			Config.AutoEat.Enabled = v
		end,
	})
	EatSection:Slider({
		Title = "Hunger Threshold",
		Step = 1,
		Value = {
			Min = 0,
			Max = 200,
			Default = Config.AutoEat.HungerThreshold,
		},
		Callback = function(v)
			Config.AutoEat.HungerThreshold = v
		end,
	})
	EatSection:Dropdown({
		Title = "Food Priority",
		Values = { "BestFirst", "WorstFirst", "Any" },
		Default = Config.AutoEat.FoodPriority,
		Callback = function(v)
			Config.AutoEat.FoodPriority = v
		end,
	})
	EatSection:Toggle({
		Title = "Allow World Food",
		Default = Config.AutoEat.AllowWorldFood,
		Callback = function(v)
			Config.AutoEat.AllowWorldFood = v
		end,
	})
	EatSection:Slider({
		Title = "Eat Cooldown (s)",
		Step = 1,
		Value = {
			Min = 0,
			Max = 10,
			Default = Config.AutoEat.EatCooldown,
		},
		Callback = function(v)
			Config.AutoEat.EatCooldown = v
		end,
	})

	-- Auto Warmth Section
	local WarmthSection = SurvivalTab:Section({ Title = "Auto Warmth" })
	WarmthSection:Toggle({
		Title = "Enable Auto Warmth",
		Default = Config.AutoWarmth.Enabled,
		Callback = function(v)
			Config.AutoWarmth.Enabled = v
		end,
	})
	WarmthSection:Toggle({
		Title = "Teleport to Fire",
		Default = Config.AutoWarmth.TeleportToFire,
		Callback = function(v)
			Config.AutoWarmth.TeleportToFire = v
		end,
	})
	WarmthSection:Toggle({
		Title = "Move to Fire",
		Default = Config.AutoWarmth.MoveToFire,
		Callback = function(v)
			Config.AutoWarmth.MoveToFire = v
		end,
	})
	WarmthSection:Toggle({
		Title = "Auto Feed Fire",
		Default = Config.AutoWarmth.AutoFeedFire,
		Callback = function(v)
			Config.AutoWarmth.AutoFeedFire = v
		end,
	})
	WarmthSection:Dropdown({
		Title = "Fuel Priority",
		Values = { "Sapling", "Log", "Coal", "Any" },
		Default = Config.AutoWarmth.FuelPriority,
		Callback = function(v)
			Config.AutoWarmth.FuelPriority = v
		end,
	})
	WarmthSection:Toggle({
		Title = "Pull Fuel From World",
		Default = Config.AutoWarmth.PullFuelFromWorld,
		Callback = function(v)
			Config.AutoWarmth.PullFuelFromWorld = v
		end,
	})

	-- ========================================
	-- TAB: COMBAT
	-- ========================================
	local CombatTab = Window:Tab({ Title = "⚔️ Combat", Icon = "sword" })

	-- Kill Aura Section
	local KillSection = CombatTab:Section({ Title = "Kill Aura" })
	KillSection:Toggle({
		Title = "Enable Kill Aura",
		Default = Config.KillAura.Enabled,
		Callback = function(v)
			Config.KillAura.Enabled = v
		end,
	})
	KillSection:Slider({
		Title = "Radius",
		Step = 1,
		Value = {
			Min = 10,
			Max = 200,
			Default = Config.KillAura.Radius,
		},
		Callback = function(v)
			Config.KillAura.Radius = v
		end,
	})
	KillSection:Toggle({
		Title = "Target Wolves",
		Default = Config.KillAura.TargetWolves,
		Callback = function(v)
			Config.KillAura.TargetWolves = v
		end,
	})
	KillSection:Toggle({
		Title = "Target Bears",
		Default = Config.KillAura.TargetBears,
		Callback = function(v)
			Config.KillAura.TargetBears = v
		end,
	})
	KillSection:Toggle({
		Title = "Target Scorpions",
		Default = Config.KillAura.TargetScorpions,
		Callback = function(v)
			Config.KillAura.TargetScorpions = v
		end,
	})
	KillSection:Toggle({
		Title = "Target Cultists",
		Default = Config.KillAura.TargetCultists,
		Callback = function(v)
			Config.KillAura.TargetCultists = v
		end,
	})

	-- Mining Aura Section
	local MineSection = CombatTab:Section({ Title = "Mining Aura" })
	MineSection:Toggle({
		Title = "Enable Mining Aura",
		Default = Config.MiningAura.Enabled,
		Callback = function(v)
			Config.MiningAura.Enabled = v
		end,
	})
	MineSection:Slider({
		Title = "Radius",
		Step = 1,
		Value = {
			Min = 10,
			Max = 200,
			Default = Config.MiningAura.Radius,
		},
		Callback = function(v)
			Config.MiningAura.Radius = v
		end,
	})
	MineSection:Toggle({
		Title = "Target Trees",
		Default = Config.MiningAura.TargetTrees,
		Callback = function(v)
			Config.MiningAura.TargetTrees = v
		end,
	})
	MineSection:Toggle({
		Title = "Target Stones",
		Default = Config.MiningAura.TargetStones,
		Callback = function(v)
			Config.MiningAura.TargetStones = v
		end,
	})
	MineSection:Toggle({
		Title = "Target Bushes",
		Default = Config.MiningAura.TargetBushes,
		Callback = function(v)
			Config.MiningAura.TargetBushes = v
		end,
	})

	-- ========================================
	-- TAB: AUTOMATION
	-- ========================================
	local AutoTab = Window:Tab({ Title = "📦 Automation", Icon = "box" })

	-- Auto Loot Section
	local LootSection = AutoTab:Section({ Title = "Auto Loot" })
	LootSection:Toggle({
		Title = "Enable Auto Loot",
		Default = Config.AutoLoot.Enabled,
		Callback = function(v)
			Config.AutoLoot.Enabled = v
		end,
	})
	LootSection:Slider({
		Title = "Radius",
		Step = 1,
		Value = {
			Min = 10,
			Max = 200,
			Default = Config.AutoLoot.Radius,
		},
		Callback = function(v)
			Config.AutoLoot.Radius = v
		end,
	})
	LootSection:Slider({
		Title = "Max Loot Per Tick",
		Step = 1,
		Value = {
			Min = 1,
			Max = 50,
			Default = Config.AutoLoot.MaxLootPerTick,
		},
		Callback = function(v)
			Config.AutoLoot.MaxLootPerTick = v
		end,
	})
	LootSection:Toggle({
		Title = "Loot Valuables",
		Default = Config.AutoLoot.LootValuables,
		Callback = function(v)
			Config.AutoLoot.LootValuables = v
		end,
	})
	LootSection:Toggle({
		Title = "Loot Resources",
		Default = Config.AutoLoot.LootResources,
		Callback = function(v)
			Config.AutoLoot.LootResources = v
		end,
	})
	LootSection:Toggle({
		Title = "Loot Scrap",
		Default = Config.AutoLoot.LootScrap,
		Callback = function(v)
			Config.AutoLoot.LootScrap = v
		end,
	})
	LootSection:Toggle({
		Title = "Loot Containers",
		Default = Config.AutoLoot.LootContainers,
		Callback = function(v)
			Config.AutoLoot.LootContainers = v
		end,
	})
	LootSection:Toggle({
		Title = "Open Containers",
		Default = Config.AutoLoot.OpenContainers,
		Callback = function(v)
			Config.AutoLoot.OpenContainers = v
		end,
	})

	-- Auto Plant Section
	local PlantSection = AutoTab:Section({ Title = "Auto Plant (Exploit)" })
	PlantSection:Toggle({
		Title = "Enable Auto Plant",
		Default = Config.AutoPlant.Enabled,
		Callback = function(v)
			Config.AutoPlant.Enabled = v
		end,
	})
	PlantSection:Dropdown({
		Title = "Pattern",
		Values = { "Circle", "Square", "Spiral" },
		Default = Config.AutoPlant.Pattern,
		Callback = function(v)
			Config.AutoPlant.Pattern = v
		end,
	})
	PlantSection:Slider({
		Title = "Radius",
		Step = 1,
		Value = {
			Min = 5,
			Max = 100,
			Default = Config.AutoPlant.Radius,
		},
		Callback = function(v)
			Config.AutoPlant.Radius = v
		end,
	})
	PlantSection:Slider({
		Title = "Spacing",
		Step = 1,
		Value = {
			Min = 1,
			Max = 10,
			Default = Config.AutoPlant.Spacing,
		},
		Callback = function(v)
			Config.AutoPlant.Spacing = v
		end,
	})
	PlantSection:Slider({
		Title = "Plant Count",
		Step = 1,
		Value = {
			Min = 10,
			Max = 200,
			Default = Config.AutoPlant.PlantCount,
		},
		Callback = function(v)
			Config.AutoPlant.PlantCount = v
		end,
	})
	PlantSection:Button({
		Title = "🌱 Plant Now!",
		Callback = function()
			if AutoPlant then
				AutoPlant.PlantNow()
			end
		end,
	})

	-- Auto Craft Section
	local CraftSection = AutoTab:Section({ Title = "Auto Craft" })
	CraftSection:Toggle({
		Title = "Enable Auto Craft",
		Default = Config.AutoCraft.Enabled,
		Callback = function(v)
			Config.AutoCraft.Enabled = v
		end,
	})

	-- Auto Scrap Section
	local ScrapSection = AutoTab:Section({ Title = "Auto Scrap" })
	ScrapSection:Toggle({
		Title = "Enable Auto Scrap",
		Default = Config.AutoScrap.Enabled,
		Callback = function(v)
			Config.AutoScrap.Enabled = v
		end,
	})
	ScrapSection:Toggle({
		Title = "Scrap Junk Items",
		Default = Config.AutoScrap.ScrapJunk,
		Callback = function(v)
			Config.AutoScrap.ScrapJunk = v
		end,
	})
	ScrapSection:Slider({
		Title = "Max Scrap Per Tick",
		Step = 1,
		Value = {
			Min = 1,
			Max = 50,
			Default = Config.AutoScrap.MaxScrapPerTick,
		},
		Callback = function(v)
			Config.AutoScrap.MaxScrapPerTick = v
		end,
	})

	-- ========================================
	-- TAB: SCANNER
	-- ========================================
	local ScanTab = Window:Tab({ Title = "🔍 Scanner", Icon = "search" })

	local ScanSection = ScanTab:Section({ Title = "Dynamic Scanner" })
	ScanSection:Button({
		Title = "🔍 Scan All",
		Callback = function()
			if Scanner then
				Scanner.ScanAll()
			end
		end,
	})
	ScanSection:Button({
		Title = "🔍 Scan Items",
		Callback = function()
			if Scanner then
				Scanner.ScanItems()
			end
		end,
	})
	ScanSection:Button({
		Title = "🔍 Scan Enemies",
		Callback = function()
			if Scanner then
				Scanner.ScanEnemies()
			end
		end,
	})
	ScanSection:Button({
		Title = "🔍 Scan Foliage",
		Callback = function()
			if Scanner then
				Scanner.ScanFoliage()
			end
		end,
	})

	-- ========================================
	-- TAB: SETTINGS
	-- ========================================
	local SettingsTab = Window:Tab({ Title = "⚙️ Settings", Icon = "settings" })

	local CtrlSection = SettingsTab:Section({ Title = "Controls" })
	CtrlSection:Button({
		Title = "▶️ Start All Features",
		Callback = startAllFeatures,
	})
	CtrlSection:Button({
		Title = "⏹️ Stop All Features",
		Callback = stopAllFeatures,
	})

	local LogSection = SettingsTab:Section({ Title = "Logging" })
	LogSection:Dropdown({
		Title = "Log Level",
		Values = { "Debug", "Info", "Warning", "Error" },
		Default = Config.System.LogLevel,
		Callback = function(v)
			Config.System.LogLevel = v
		end,
	})
	LogSection:Toggle({
		Title = "Log Stats",
		Default = Config.System.LogStats,
		Callback = function(v)
			Config.System.LogStats = v
		end,
	})

	return Window
end

-- ============================================
-- APP INIT
-- ============================================
function App.Init(deps)
	Logger = deps and deps.Logger

	Utils.log("App.Init: Loading modules...", "Info")

	-- Initialize all modules
	initModules()

	-- Create UI
	local WindUI = deps and deps.WindUI
	if WindUI then
		createUI(WindUI)
		Utils.log("UI created!", "Success")
	else
		Utils.log("WindUI not provided!", "Error")
	end

	-- Auto-start features
	startAllFeatures()

	Utils.log("App.Init: Complete!", "Success")
end

return App
