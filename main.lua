--[[
    main.lua
    99 Nights In The Forest - OP Script Entry Point
    
    Usage:
    - Local:  getgenv().OP_BASE_PATH = "C:/path/to/Nforst/"; loadstring(readfile("main.lua"))()
    - Remote: loadstring(game:HttpGet("http://192.168.1.5:8000/main.lua"))()
]]

-- ============================================
-- ANTI-DUPLICATE: Cleanup previous instance
-- ============================================
if getgenv and getgenv().OP_WINDOW then
    pcall(function()
        print("[99NightsOP] Destroying previous UI instance...")
        getgenv().OP_WINDOW:Destroy()
    end)
    getgenv().OP_WINDOW = nil
end

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    -- Remote URL for loading modules
    BASE_URL = "http://192.168.1.5:8000/",
    
    -- WindUI source (change to local path if needed)
    -- WINDUI_URL = "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    WINDUI_URL = "http://192.168.1.5:8000/WindUI/dist/main.lua",
}

-- Allow override via getgenv
if getgenv then
    if getgenv().OP_BASE_URL then
        CONFIG.BASE_URL = getgenv().OP_BASE_URL
    end
    getgenv().OP_BASE_URL = CONFIG.BASE_URL
end

-- ============================================
-- UTILITIES
-- ============================================
local function log(msg, level)
    level = level or "Info"
    print("[99NightsOP][" .. level .. "] " .. msg)
end

local function normalizeBasePath(base)
    if not base or base == "" then
        return nil
    end
    local normalized = base:gsub("\\", "/")
    if string.sub(normalized, -1) ~= "/" then
        normalized = normalized .. "/"
    end
    return normalized
end

-- ============================================
-- MODULE LOADER
-- ============================================
local LOCAL_BASE = getgenv and getgenv().OP_BASE_PATH and normalizeBasePath(getgenv().OP_BASE_PATH)

local function loadFile(path)
    -- Try local first
    if LOCAL_BASE and readfile and isfile then
        local localPath = LOCAL_BASE .. path
        if isfile(localPath) then
            log("Loading local: " .. path, "Debug")
            local ok, result = pcall(function()
                return loadstring(readfile(localPath))()
            end)
            if ok then
                return result
            end
            log("Local load failed: " .. tostring(result), "Warning")
        end
    end
    
    -- Fallback to remote
    local url = CONFIG.BASE_URL .. path
    log("Loading remote: " .. path, "Debug")
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok then
        return result
    end
    log("Remote load failed: " .. tostring(result), "Error")
    return nil
end

-- ============================================
-- LOAD WINDUI
-- ============================================
log("Loading WindUI...", "Info")

local WindUI

-- Try local WindUI first
if LOCAL_BASE and readfile and isfile then
    -- Check for cloned repo at root (WindUI/dist/main.lua)
    local rootWindUI = LOCAL_BASE .. "WindUI/dist/main.lua"
    -- Check for Libs path (Libs/WindUI/dist/main.lua)
    local libsWindUI = LOCAL_BASE .. "Libs/WindUI/dist/main.lua"
    
    local targetPath
    if isfile(rootWindUI) then
        targetPath = rootWindUI
    elseif isfile(libsWindUI) then
        targetPath = libsWindUI
    end

    if targetPath then
        log("Using local WindUI: " .. targetPath, "Debug")
        local ok, result = pcall(function()
            return loadstring(readfile(targetPath))()
        end)
        if ok then
            WindUI = result
        else
            log("Local WindUI failed: " .. tostring(result), "Warning")
        end
    end
end

-- Fallback to remote WindUI
if not WindUI then
    log("Using remote WindUI", "Debug")
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(CONFIG.WINDUI_URL))()
    end)
    if ok then
        WindUI = result
    else
        log("Failed to load WindUI: " .. tostring(result), "Error")
        return
    end
end

log("WindUI v" .. (WindUI.Version or "?") .. " loaded!", "Success")

-- ============================================
-- LOAD MAIN INTERFACE
-- ============================================
log("Loading MainInterface...", "Info")

local MainInterface = loadFile("Src/UI/MainInterface.lua")

if not MainInterface then
    log("Failed to load MainInterface!", "Error")
    return
end

-- ============================================
-- INITIALIZE
-- ============================================
log("Initializing...", "Info")

local Window = MainInterface.Init({
    WindUI = WindUI,
    Logger = nil, -- Optional logger module
})

log("=================================", "Success")
log("  99 Nights OP Script Loaded!   ", "Success")
log("  God Mode ready to use!        ", "Success")
log("=================================", "Success")
