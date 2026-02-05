--[[
    UI/MainInterface.lua
    99 Nights In The Forest - OP Script Interface
    
    Modular architecture with Home Tab and Player Info
]]

local App = {}

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    BASE_URL = (getgenv and getgenv().OP_BASE_URL) or "http://192.168.1.8:8000/",
    WINDOW = {
        Title = "99 Nights OP",
        Folder = "99NightsOP",
        Icon = "moon",
        Theme = "Dark",
    },
    COLORS = {
        Green = Color3.fromHex("#10C550"),
        Blue = Color3.fromHex("#257AF7"),
        Purple = Color3.fromHex("#7775F2"),
        Yellow = Color3.fromHex("#ECA201"),
        Red = Color3.fromHex("#EF4F1D"),
        Grey = Color3.fromHex("#83889E"),
    },
    SETTINGS = {
        ToggleKey = Enum.KeyCode.P
    }
}

-- ============================================
-- MODULE LOADER
-- ============================================
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
local REMOTE_BASE = CONFIG.BASE_URL .. "Src/"

local function loadModule(path)
    -- Try local first
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
    
    -- Fallback to remote
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

-- ============================================
-- CLEANUP PREVIOUS FEATURE INSTANCES
-- ============================================
if getgenv and getgenv().OP_FEATURES then
    for name, feature in pairs(getgenv().OP_FEATURES) do
        pcall(function()
            if feature.Stop then feature.Stop() end
            if feature.Cleanup then feature.Cleanup() end
        end)
    end
    getgenv().OP_FEATURES = nil
end

-- ============================================
-- LOAD MODULES
-- ============================================
print("[OP] Loading modules...")

-- Core
local Utils = loadModule("Core/Utils.lua")
local Remote = loadModule("Core/RemoteHandler.lua")

-- Features
local AutoEat = loadModule("Features/AutoEat.lua")
local GodMode = loadModule("Features/GodMode.lua")
local KillAura = loadModule("Features/KillAura.lua")
local MapRevealer = loadModule("Features/MapRevealer.lua")
local TreeFarm = loadModule("Features/TreeFarm.lua")
local AutoPlant = loadModule("Features/AutoPlant.lua")
local SoundManager = loadModule("Features/SoundManager.lua")
local ItemCollector = loadModule("Features/ItemCollector.lua")
local ChestExplorer = loadModule("Features/ChestExplorer.lua")
local Fly = loadModule("Features/Fly.lua")
local Speed = loadModule("Features/Speed.lua")
if not Speed then warn("[MainInterface] CRITICAL: Speed module failed to load!") else print("[MainInterface] Speed module loaded table: " .. tostring(Speed)) end
local Teleport = loadModule("Features/Teleport.lua") -- [NEW]
local PhysicsOptimizer = loadModule("Features/PhysicsOptimizer.lua") -- [NEW]
local Tools = loadModule("Features/Tools.lua") -- [NEW] Free Camera & Spectator
local KillTarget = loadModule("Features/KillTarget.lua") -- [NEW] Teleport Kill

-- UI Tabs
local HomeTab = loadModule("UI/Tabs/HomeTab.lua")
local SurvivalTab = loadModule("UI/Tabs/SurvivalTab.lua")
local CombatTab = loadModule("UI/Tabs/CombatTab.lua")
local FarmingTab = loadModule("UI/Tabs/FarmingTab.lua")
local SettingsTab = loadModule("UI/Tabs/SettingsTab.lua")
local ExplorerTab = loadModule("UI/Tabs/ExplorerTab.lua")
local MiscTab = loadModule("UI/Tabs/MiscTab.lua")
local AutoCollectTab = loadModule("UI/Tabs/AutoCollectTab.lua")
local TeleportTab = loadModule("UI/Tabs/TeleportTab.lua") -- [NEW]
local ToolsTab = loadModule("UI/Tabs/ToolsTab.lua") -- [NEW] Free Camera & Spectator

print("[OP] Modules loaded!")

-- Store features for cleanup on next reload
if getgenv then
    getgenv().OP_FEATURES = {
        AutoEat = AutoEat,
        GodMode = GodMode,
        KillAura = KillAura,
        MapRevealer = MapRevealer,
        TreeFarm = TreeFarm,
        AutoPlant = AutoPlant,
        SoundManager = SoundManager,
        ItemCollector = ItemCollector,
        ChestExplorer = ChestExplorer,
        Fly = Fly,
        Speed = Speed,
        PhysicsOptimizer = PhysicsOptimizer,
        Tools = Tools,
        KillTarget = KillTarget,
    }
end

-- ============================================
-- FEATURES BUNDLE
-- ============================================
local Features = {
    AutoEat = AutoEat,
    GodMode = GodMode,
    KillAura = KillAura,
    MapRevealer = MapRevealer,
    TreeFarm = TreeFarm,
    AutoPlant = AutoPlant,
    SoundManager = SoundManager,
    ItemCollector = ItemCollector,
    ChestExplorer = ChestExplorer,
    Fly = Fly,
    Speed = Speed, -- [FIX] Added missing registration
    Teleport = Teleport, -- [NEW]
    PhysicsOptimizer = PhysicsOptimizer, -- [NEW]
    Tools = Tools, -- [NEW] Free Camera & Spectator
    KillTarget = KillTarget, -- [NEW] Teleport Kill
}

-- ============================================
-- BUILD UI
-- ============================================
local function createUI(WindUI)
    -- Initialize features with dependencies
    if AutoEat then
        AutoEat.Init({
            Utils = Utils,
            Remote = Remote,
            WindUI = WindUI,
        })
    end
    
    if GodMode then
        GodMode.Init({
            Remote = Remote,
        })
    end
    
    if KillAura then
        KillAura.Init({
            Utils = Utils,
            Remote = Remote,
            WindUI = WindUI,
        })
    end
    
    if KillTarget then
        KillTarget.Init({
            Utils = Utils,
            Remote = Remote,
        })
    end

    if MapRevealer then
        MapRevealer.Init({
            Remote = Remote,
        })
    end
    
    if TreeFarm then
        TreeFarm.Init({
            Utils = Utils,
            Remote = Remote,
        })
    end
    
    if AutoPlant then
        AutoPlant.Init({
            Utils = Utils,
            Remote = Remote,
        })
    end

    if SoundManager then
        SoundManager.Init({
            Utils = Utils,
            })
    end

    if ItemCollector then
        ItemCollector.Init({
            Remote = Remote,
        })
    end
    
    if ChestExplorer then
        ChestExplorer.Init({
            Remote = Remote,
        })
    end

    if Fly then Fly.Init() end
    if Speed then Speed.Init() end
    if Teleport then Teleport.Init() end -- [NEW]
    if PhysicsOptimizer then PhysicsOptimizer.Init() end -- [NEW]
    if Tools then Tools.Init() end -- [NEW] Free Camera & Spectator
    
    -- Create window
    local Window = WindUI:CreateWindow({
        Title = CONFIG.WINDOW.Title,
        Folder = CONFIG.WINDOW.Folder,
        Icon = "solar:moon-stars-bold",
        Theme = CONFIG.WINDOW.Theme,
        Size = UDim2.fromOffset(580, 460),
        HasOutline = true,
        Transparent = true,
        SideBarWidth = 200,
        NewElements = true,
        ToggleKey = CONFIG.SETTINGS.ToggleKey, -- [FIX] Added ToggleKey
        Topbar = {
            Height = 44,
            ButtonsType = "Mac",
        }
    })
    
    -- Debug Window type
    print("[OP] Window created. Type: " .. type(Window))
    
    if type(Window) ~= "table" then
        warn("[OP] CRITICAL: Window is not a table! It is: " .. tostring(Window))
        return nil
    end

    -- Store reference for anti-duplicate
    if getgenv then
        getgenv().OP_WINDOW = Window
    end
    
    -- Create Home Tab (and auto-select it)
    local homeTabRef = nil
    if HomeTab then
        homeTabRef = HomeTab.Create(Window, CONFIG, WindUI)
    end
    
    -- Create Tabs
    if TeleportTab then
        TeleportTab.Create(Window, Features, CONFIG, WindUI) -- [NEW] Placed early for visibility
    end

    if SurvivalTab then
        SurvivalTab.Create(Window, Features, CONFIG)
    end
    
    if CombatTab then
        CombatTab.Create(Window, Features, CONFIG, WindUI)
    end
    
    if FarmingTab then
        FarmingTab.Create(Window, Features, CONFIG)
    end
    
    if ExplorerTab then
        ExplorerTab.Create(Window, Features, CONFIG, WindUI)
    end

    if MiscTab then
        MiscTab.Create(Window, Utils, Remote, CONFIG, Features, WindUI)
    end

    if AutoCollectTab then
        AutoCollectTab.Create(Window, Features, CONFIG, WindUI)
    end

    if ToolsTab then
        ToolsTab.Create(Window, Features, CONFIG, WindUI) -- [NEW] Free Camera & Spectator
    end
    
    if SettingsTab then
        SettingsTab.Create(Window, Utils, Remote, CONFIG, WindUI)
    end
    
    -- Auto-select Home tab on startup
    if homeTabRef and homeTabRef.Select then
        homeTabRef:Select()
    end
    
    print("[OP] UI Created! Ready to use.")
    return Window
end


-- ============================================
-- APP INIT
-- ============================================
function App.Init(deps)
    local WindUI = deps and deps.WindUI
    
    if not WindUI then
        warn("[OP] WindUI not provided!")
        return nil
    end
    
    print("[OP] Initializing 99 Nights OP Script...")
    
    local Window = createUI(WindUI)
    
    -- Show welcome notification
    WindUI:Notify({
        Title = "99 Nights OP",
        Content = "Welcome, " .. LocalPlayer.DisplayName .. "!",
        Icon = "check",
        Duration = 5,
    })
    
    return Window
end

return App
