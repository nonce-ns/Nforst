--[[
    Features/FishFarm.lua
    Auto Fishing Feature
    
    Strategy:
    1. Convert water position to screen coordinates
    2. Click directly on water (VirtualInputManager with x,y)
    3. Auto-expand zone + auto-click during minigame
    4. Repeat
]]

local FishFarm = {}

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Dependencies
local Remote = nil

-- Constants
local ROD_KEYWORD = "rod"
local WATER_RANGE = 50
local CYCLE_DELAY = 1
local ZONE_SIZE_EXPLOIT = 0.95
local CLICK_COOLDOWN = 0.2
local CAST_COOLDOWN = 1  -- Faster recast after catching

-- Debug
local DEBUG = false -- Production Ready
local function log(msg)
    if DEBUG then print("[FishFarm] " .. msg) end
end
local function logWarn(msg)
    warn("[FishFarm] " .. msg)
end

-- State
local State = {
    Enabled = false,
    FishingThread = nil,
    MinigameConnection = nil,
    FishCount = 0,
    LastClickTime = 0,
    LastCastTime = 0,
    IsMinigameActive = false,
    ZoneExpanded = false,
    ClickCount = 0,
    WaitingForMinigame = false,
    Anchored = false,
    AnchorGui = nil,
}

-- Settings
local Settings = {
    FishDelay = 15,
    AutoClick = true,
    ExpandZone = true,
}

-- ============================================
-- HELPERS
-- ============================================
local function isRod(name)
    if not name then return false end
    return string.find(string.lower(name), ROD_KEYWORD) ~= nil
end

local function getEquippedRod()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local toolHandle = char:FindFirstChild("ToolHandle")
    if not toolHandle then return nil end
    
    local originalItem = toolHandle:FindFirstChild("OriginalItem")
    if not originalItem or not originalItem.Value then return nil end
    
    local weapon = originalItem.Value
    if isRod(weapon.Name) then
        return weapon
    end
    return nil
end

local function getRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getCamera()
    return Workspace.CurrentCamera
end

local function getNearestWater()
    local root = getRoot()
    if not root then return nil end
    
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return nil end
    
    local waterFolder = mapFolder:FindFirstChild("Water")
    if not waterFolder then return nil end
    
    local nearestWater = nil
    local nearestDist = math.huge
    
    for _, waterPart in ipairs(waterFolder:GetChildren()) do
        if waterPart:IsA("BasePart") then
            local dist = (waterPart.Position - root.Position).Magnitude
            if dist < nearestDist and dist <= WATER_RANGE then
                nearestDist = dist
                nearestWater = waterPart
            end
        end
    end
    
    return nearestWater, nearestDist
end

-- ============================================
-- CLICK AT POSITION
-- ============================================

-- Convert world position to screen coordinates and click there
local function clickAtWorldPosition(worldPos)
    local camera = getCamera()
    if not camera then return false end
    
    -- Convert world position to screen coordinates
    local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
    
    if not onScreen then
        logWarn("Water not on screen!")
        return false
    end
    
    local screenX = math.floor(screenPos.X)
    local screenY = math.floor(screenPos.Y)
    
    log("Clicking at screen: " .. screenX .. ", " .. screenY)
    
    local success = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        -- Click at water's screen position
        vim:SendMouseButtonEvent(screenX, screenY, 0, true, game, 0)
        task.delay(0.1, function()
            pcall(function()
                vim:SendMouseButtonEvent(screenX, screenY, 0, false, game, 0)
            end)
        end)
    end)
    
    return success
end

-- Simple click for minigame (center screen)
local function simulateClick()
    local now = tick()
    if now - State.LastClickTime < CLICK_COOLDOWN then
        return false
    end
    State.LastClickTime = now
    
    local success = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.delay(0.1, function()
            pcall(function()
                vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
        end)
    end)
    
    return success
end

-- ============================================
-- MINIGAME HANDLER
-- ============================================

local function getFishingFrame()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local frame = gui:FindFirstChild("FishingCatchFrame", true)
            if frame then return frame end
        end
    end
    return nil
end

local function expandGreenZone()
    if not Settings.ExpandZone then return false end
    if State.ZoneExpanded then return true end
    
    local frame = getFishingFrame()
    if not frame then return false end
    
    local timingBar = frame:FindFirstChild("TimingBar")
    if not timingBar then return false end
    
    local successArea = timingBar:FindFirstChild("SuccessArea")
    if successArea then
        successArea.Size = UDim2.new(1, 0, ZONE_SIZE_EXPLOIT, 0)
        successArea.Position = UDim2.new(0.5, 0, 0.025, 0)
        State.ZoneExpanded = true
        log("✓ Zone expanded to " .. (ZONE_SIZE_EXPLOIT * 100) .. "%")
        return true
    end
    
    return false
end

local function isBarInZone()
    local frame = getFishingFrame()
    if not frame or not frame.Visible then return false end
    
    local timingBar = frame:FindFirstChild("TimingBar")
    if not timingBar then return false end
    
    local bar = timingBar:FindFirstChild("Bar")
    local successArea = timingBar:FindFirstChild("SuccessArea")
    
    if bar and successArea then
        local barY = bar.AbsolutePosition.Y
        local barHeight = bar.AbsoluteSize.Y
        local zoneY = successArea.AbsolutePosition.Y
        local zoneHeight = successArea.AbsoluteSize.Y
        
        return barY >= zoneY and (barY + barHeight) <= (zoneY + zoneHeight)
    end
    return false
end

local function onMinigameFrame()
    if not State.Enabled then return end
    
    local frame = getFishingFrame()
    
    if frame and frame.Visible then
        if not State.IsMinigameActive then
            State.IsMinigameActive = true
            State.ZoneExpanded = false
            State.ClickCount = 0
            State.WaitingForMinigame = false
            log("▶ MINIGAME STARTED!")
        end
        
        expandGreenZone()
        
        if Settings.AutoClick and isBarInZone() then
            if simulateClick() then
                State.ClickCount = State.ClickCount + 1
                log("Click #" .. State.ClickCount)
            end
        end
    else
        if State.IsMinigameActive then
            log("■ MINIGAME ENDED (" .. State.ClickCount .. " clicks)")
            State.FishCount = State.FishCount + 1
            log("🎣 Fish #" .. State.FishCount)
            
            State.IsMinigameActive = false
            State.ZoneExpanded = false
            State.ClickCount = 0
            State.LastCastTime = tick() - CAST_COOLDOWN + 1.5  -- Wait 1.5s after catch
        end
    end
end

local function startMinigameWatcher()
    if State.MinigameConnection then
        State.MinigameConnection:Disconnect()
        State.MinigameConnection = nil
    end
    
    State.MinigameConnection = RunService.RenderStepped:Connect(onMinigameFrame)
    log("Minigame watcher started")
end

local function stopMinigameWatcher()
    if State.MinigameConnection then
        State.MinigameConnection:Disconnect()
        State.MinigameConnection = nil
    end
    State.IsMinigameActive = false
    State.ZoneExpanded = false
end

-- ============================================
-- MAIN FISHING LOGIC
-- ============================================

local function doCast()
    local now = tick()
    if now - State.LastCastTime < CAST_COOLDOWN then
        return false
    end
    
    local rod = getEquippedRod()
    if not rod then return false end
    
    local water, dist = getNearestWater()
    if not water then return false end
    
    local root = getRoot()
    local camera = getCamera()
    if not root or not camera then return false end
    
    log("─────────────────────")
    log("🎣 Casting (rod: " .. rod.Name .. ", water: " .. math.floor(dist) .. " studs)")
    
    -- Get character's look direction
    local lookVector = root.CFrame.LookVector
    local playerPos = root.Position
    
    -- Calculate target position: 8 studs in front of character, at water level
    local targetPos = playerPos + lookVector * 8
    targetPos = Vector3.new(targetPos.X, water.Position.Y, targetPos.Z)
    
    log("Target: " .. math.floor(targetPos.X) .. ", " .. math.floor(targetPos.Y) .. ", " .. math.floor(targetPos.Z))
    
    -- Convert to screen position
    local screenPos, onScreen = camera:WorldToScreenPoint(targetPos)
    
    if not onScreen then
        logWarn("Target not on screen, trying water position...")
        screenPos, onScreen = camera:WorldToScreenPoint(water.Position)
        if not onScreen then
            logWarn("Water not on screen!")
            return false
        end
    end
    
    local screenX = math.floor(screenPos.X)
    local screenY = math.floor(screenPos.Y)
    
    State.LastCastTime = tick()
    State.WaitingForMinigame = true
    
    log("Clicking at: " .. screenX .. ", " .. screenY)
    
    local success = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(screenX, screenY, 0, true, game, 0)
        task.delay(0.1, function()
            pcall(function()
                vim:SendMouseButtonEvent(screenX, screenY, 0, false, game, 0)
            end)
        end)
    end)
    
    if success then
        log("✓ Cast sent")
    else
        logWarn("Click failed")
        State.WaitingForMinigame = false
        return false
    end
    
    return true
end

-- ============================================
-- CLEANUP
-- ============================================
local function fullCleanup()
    stopMinigameWatcher()
    
    if State.FishingThread then
        pcall(function() task.cancel(State.FishingThread) end)
        State.FishingThread = nil
    end
    
    local count = State.FishCount
    
    State.Enabled = false
    State.FishCount = 0
    State.LastClickTime = 0
    State.LastCastTime = 0
    State.IsMinigameActive = false
    State.ZoneExpanded = false
    State.ClickCount = 0
    State.WaitingForMinigame = false
    
    log("Cleanup (fish: " .. count .. ")")
end

-- ============================================
-- ANCHOR GUI
-- ============================================
local function createAnchorGui()
    if State.AnchorGui then return end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "FishFarmAnchorGui"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer:FindFirstChild("PlayerGui")
    
    State.AnchorGui = gui
    
    -- Anchor Button
    local anchorBtn = Instance.new("TextButton")
    anchorBtn.Name = "AnchorButton"
    anchorBtn.Size = UDim2.new(0, 90, 0, 40)
    anchorBtn.Position = UDim2.new(0, 20, 0.7, 0)
    anchorBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    anchorBtn.Text = "🔓 ANCHOR"
    anchorBtn.TextColor3 = Color3.new(1, 1, 1)
    anchorBtn.TextSize = 14
    anchorBtn.Font = Enum.Font.GothamBold
    anchorBtn.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = anchorBtn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 120, 120)
    stroke.Thickness = 1
    stroke.Parent = anchorBtn
    
    anchorBtn.MouseButton1Click:Connect(function()
        State.Anchored = not State.Anchored
        local root = getRoot()
        
        if State.Anchored then
            anchorBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
            anchorBtn.Text = "🔒 LOCKED"
            stroke.Color = Color3.fromRGB(80, 200, 80)
            if root then root.Anchored = true end
            log("Player ANCHORED")
        else
            anchorBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            anchorBtn.Text = "🔓 ANCHOR"
            stroke.Color = Color3.fromRGB(120, 120, 120)
            if root then root.Anchored = false end
            log("Player UNANCHORED")
        end
    end)
    
    log("Anchor button created")
end

local function destroyAnchorGui()
    -- Unanchor player first
    if State.Anchored then
        State.Anchored = false
        local root = getRoot()
        if root then root.Anchored = false end
    end
    
    if State.AnchorGui then
        State.AnchorGui:Destroy()
        State.AnchorGui = nil
    end
end

-- ============================================
-- PUBLIC API
-- ============================================
function FishFarm.Init(deps)
    Remote = deps.Remote
    log("Initialized")
end

function FishFarm.Start()
    if State.Enabled then return end
    
    log("═══════════════════════════")
    log("      FISH FARM START      ")
    log("═══════════════════════════")
    log("FishDelay: " .. Settings.FishDelay .. "s")
    
    fullCleanup()
    State.Enabled = true
    
    createAnchorGui()
    startMinigameWatcher()
    
    State.FishingThread = task.spawn(function()
        local noRodWarn = 0
        local noWaterWarn = 0
        
        while State.Enabled do
            local rod = getEquippedRod()
            local water = getNearestWater()
            
            if not rod then
                local now = os.clock()
                if now - noRodWarn >= 30 then
                    noRodWarn = now
                    log("⏳ Equip a rod...")
                end
                task.wait(CYCLE_DELAY)
                continue
            end
            
            if not water then
                local now = os.clock()
                if now - noWaterWarn >= 30 then
                    noWaterWarn = now
                    log("⏳ Go near water...")
                end
                task.wait(CYCLE_DELAY)
                continue
            end
            
            if State.IsMinigameActive then
                task.wait(0.5)
                continue
            end
            
            if State.WaitingForMinigame then
                local waitTime = tick() - State.LastCastTime
                if waitTime > Settings.FishDelay then
                    log("⚠ No fish after " .. Settings.FishDelay .. "s, recasting...")
                    State.WaitingForMinigame = false
                else
                    task.wait(0.5)
                    continue
                end
            end
            
            doCast()
            task.wait(CAST_COOLDOWN)
        end
    end)
end

function FishFarm.Stop()
    if not State.Enabled then return end
    
    log("═══════════════════════════")
    log("      FISH FARM STOP       ")
    log("═══════════════════════════")
    
    destroyAnchorGui()
    pcall(function() Remote.EndCatching() end)
    fullCleanup()
end

function FishFarm.IsEnabled()
    return State.Enabled
end

function FishFarm.Cleanup()
    FishFarm.Stop()
end

function FishFarm.UpdateSetting(key, value)
    log("Setting: " .. key .. " = " .. tostring(value))
    
    if key == "FishDelay" then
        Settings.FishDelay = value or 15
    elseif key == "AutoClick" then
        Settings.AutoClick = value
    elseif key == "ExpandZone" then
        Settings.ExpandZone = value
    end
end

function FishFarm.GetFishCount()
    return State.FishCount
end

return FishFarm
