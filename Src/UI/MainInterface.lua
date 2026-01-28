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
    BASE_URL = (getgenv and getgenv().OP_BASE_URL) or "http://192.168.1.5:8000/",
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

-- UI Tabs
local HomeTab = loadModule("UI/Tabs/HomeTab.lua")
local SurvivalTab = loadModule("UI/Tabs/SurvivalTab.lua")
local SettingsTab = loadModule("UI/Tabs/SettingsTab.lua")

print("[OP] Modules loaded!")

-- Store features for cleanup on next reload
if getgenv then
    getgenv().OP_FEATURES = {
        AutoEat = AutoEat,
        GodMode = GodMode,
    }
end

-- ============================================
-- FEATURES BUNDLE
-- ============================================
local Features = {
    AutoEat = AutoEat,
    GodMode = GodMode,
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
    
    -- Create Home Tab
    if HomeTab then
        HomeTab.Create(Window, CONFIG, WindUI)
    end
    
    -- Create Features Section (Optional Divider)
    -- local MainSection = Window:Section({ Title = "Features" }) -- Removed causing error
    
    -- Create tabs
    if SurvivalTab then
        SurvivalTab.Create(Window, Features, CONFIG)
    end
    
    if SettingsTab then
        SettingsTab.Create(Window, Utils, Remote, CONFIG, WindUI)
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
