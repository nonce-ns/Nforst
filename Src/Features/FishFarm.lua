--[[
    Features/FishFarm.lua
    Auto Fishing Feature (Memory-Safe + Debug Mode)
    
    - Auto-detects equipped rod via ToolHandle
    - Finds nearest water part
    - Expands minigame green zone for easy hits
    - Auto-clicks when bar is in zone (with debounce)
    - Comprehensive debug logging
]]

local FishFarm = {}

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Dependencies (injected via Init)
local Remote = nil

-- Constants
local ROD_KEYWORD = "rod"
local WATER_RANGE = 50
local CYCLE_DELAY = 0.5
local ZONE_SIZE_EXPLOIT = 0.95
local CLICK_COOLDOWN = 0.15
local MINIGAME_CHECK_INTERVAL = 0.05

-- Debug settings
local DEBUG = true
local DEBUG_VERBOSE = false  -- Extra detailed logs

local function log(msg)
    if DEBUG then
        print("[FishFarm] " .. msg)
    end
end

local function logVerbose(msg)
    if DEBUG and DEBUG_VERBOSE then
        print("[FishFarm:V] " .. msg)
    end
end

local function logWarn(msg)
    warn("[FishFarm] " .. msg)
end

local function logError(msg)
    warn("[FishFarm:ERROR] " .. msg)
end

-- State
local State = {
    Enabled = false,
    FishingThread = nil,
    MinigameConnection = nil,
    FishCount = 0,
    LastNoRodWarning = 0,
    LastNoWaterWarning = 0,
    LastClickTime = 0,
    IsMinigameActive = false,
    IsFishing = false,
    ZoneExpanded = false,
    ClickCount = 0,  -- Track clicks per minigame
    MinigameStartTime = 0,
}

-- Settings
local Settings = {
    FishDelay = 5,
    AutoClick = true,
    ExpandZone = true,
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function isRod(name)
    if not name then return false end
    return string.find(string.lower(name), ROD_KEYWORD) ~= nil
end

local function getEquippedRod()
    local char = LocalPlayer.Character
    if not char then 
        logVerbose("No character")
        return nil 
    end
    
    local toolHandle = char:FindFirstChild("ToolHandle")
    if not toolHandle then 
        logVerbose("No ToolHandle")
        return nil 
    end
    
    local originalItem = toolHandle:FindFirstChild("OriginalItem")
    if not originalItem or not originalItem.Value then 
        logVerbose("No OriginalItem")
        return nil 
    end
    
    local weapon = originalItem.Value
    if isRod(weapon.Name) then
        logVerbose("Rod found: " .. weapon.Name)
        return weapon
    end
    
    logVerbose("Equipped item is not rod: " .. weapon.Name)
    return nil
end

local function getInventoryRod(rodName)
    local inventory = LocalPlayer:FindFirstChild("Inventory")
    if not inventory then 
        logWarn("Inventory not found!")
        return nil 
    end
    
    local rod = inventory:FindFirstChild(rodName)
    if rod then 
        log("Found rod in inventory: " .. rodName)
        return rod 
    end
    
    -- Fallback
    for _, item in ipairs(inventory:GetChildren()) do
        if isRod(item.Name) then
            log("Found fallback rod: " .. item.Name)
            return item
        end
    end
    
    logWarn("No rod in inventory!")
    return nil
end

local function getRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getNearestWater()
    local root = getRoot()
    if not root then return nil end
    
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then 
        logWarn("Map folder not found!")
        return nil 
    end
    
    local waterFolder = mapFolder:FindFirstChild("Water")
    if not waterFolder then 
        logWarn("Water folder not found!")
        return nil 
    end
    
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
    
    if nearestWater then
        logVerbose("Water found: " .. nearestWater.Name .. " at " .. math.floor(nearestDist) .. " studs")
    end
    
    return nearestWater, nearestDist
end

local function getWaterPosition(waterPart)
    if not waterPart then return nil end
    local pos = waterPart.Position
    return Vector3.new(pos.X, pos.Y - 1, pos.Z)
end

-- ============================================
-- MINIGAME EXPLOIT
-- ============================================

local function getFishingFrame()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local frame = gui:FindFirstChild("FishingCatchFrame", true)
            if frame then 
                logVerbose("FishingCatchFrame found in: " .. gui.Name)
                return frame 
            end
        end
    end
    return nil
end

local function expandGreenZone()
    if not Settings.ExpandZone then return false end
    if State.ZoneExpanded then return true end
    
    local frame = getFishingFrame()
    if not frame then 
        logVerbose("expandGreenZone: No frame")
        return false 
    end
    
    local timingBar = frame:FindFirstChild("TimingBar")
    if not timingBar then 
        logWarn("expandGreenZone: No TimingBar")
        return false 
    end
    
    local successArea = timingBar:FindFirstChild("SuccessArea")
    if successArea then
        local oldSize = successArea.Size.Y.Scale
        successArea.Size = UDim2.new(1, 0, ZONE_SIZE_EXPLOIT, 0)
        successArea.Position = UDim2.new(0.5, 0, 0.025, 0)
        State.ZoneExpanded = true
        log("✓ Zone expanded: " .. math.floor(oldSize * 100) .. "% → " .. math.floor(ZONE_SIZE_EXPLOIT * 100) .. "%")
        return true
    else
        logWarn("expandGreenZone: No SuccessArea")
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
        
        local inZone = barY >= zoneY and (barY + barHeight) <= (zoneY + zoneHeight)
        
        if DEBUG_VERBOSE then
            logVerbose(string.format("Bar: Y=%.1f H=%.1f | Zone: Y=%.1f H=%.1f | InZone=%s", 
                barY, barHeight, zoneY, zoneHeight, tostring(inZone)))
        end
        
        return inZone
    end
    return false
end

local function simulateClick()
    local now = tick()
    if now - State.LastClickTime < CLICK_COOLDOWN then
        logVerbose("Click debounced")
        return false
    end
    State.LastClickTime = now
    State.ClickCount = State.ClickCount + 1
    
    local success = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.delay(0.05, function()
            pcall(function()
                vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
        end)
    end)
    
    if success then
        log("✓ Click #" .. State.ClickCount)
    else
        logWarn("Click failed!")
    end
    
    return success
end

local function onMinigameFrame()
    if not State.Enabled then return end
    
    local frame = getFishingFrame()
    
    if frame and frame.Visible then
        -- Minigame just started
        if not State.IsMinigameActive then
            State.IsMinigameActive = true
            State.ZoneExpanded = false
            State.ClickCount = 0
            State.MinigameStartTime = tick()
            log("▶ Minigame STARTED")
        end
        
        -- Expand zone
        expandGreenZone()
        
        -- Auto-click
        if Settings.AutoClick and isBarInZone() then
            simulateClick()
        end
    else
        -- Minigame ended
        if State.IsMinigameActive then
            local duration = tick() - State.MinigameStartTime
            log(string.format("■ Minigame ENDED (%.1fs, %d clicks)", duration, State.ClickCount))
            
            State.IsMinigameActive = false
            State.ZoneExpanded = false
            State.ClickCount = 0
        end
    end
end

local function startMinigameWatcher()
    if State.MinigameConnection then
        State.MinigameConnection:Disconnect()
        State.MinigameConnection = nil
        log("Disconnected old minigame watcher")
    end
    
    State.MinigameConnection = RunService.RenderStepped:Connect(onMinigameFrame)
    log("Started minigame watcher (RenderStepped)")
end

local function stopMinigameWatcher()
    if State.MinigameConnection then
        State.MinigameConnection:Disconnect()
        State.MinigameConnection = nil
        log("Stopped minigame watcher")
    end
    State.IsMinigameActive = false
    State.ZoneExpanded = false
    State.ClickCount = 0
end

-- ============================================
-- FISHING LOGIC
-- ============================================
local function doFishing(rod, waterPart)
    if not State.Enabled then 
        logVerbose("doFishing: Not enabled")
        return false 
    end
    if State.IsFishing then 
        logVerbose("doFishing: Already fishing")
        return false 
    end
    
    State.IsFishing = true
    log("─────────────────────")
    log("🎣 Starting fish attempt #" .. (State.FishCount + 1))
    
    local success, err = pcall(function()
        -- Get inventory rod
        local inventoryRod = getInventoryRod(rod.Name)
        if not inventoryRod then
            logError("Rod not in Inventory: " .. rod.Name)
            return
        end
        
        -- Get water position
        local waterPos = getWaterPosition(waterPart)
        if not waterPos then 
            logError("Failed to get water position")
            return 
        end
        
        log("Casting to: " .. waterPart.Name)
        log("Position: " .. tostring(waterPos))
        
        -- Call remote
        local result = Remote.StartCatchTimer(inventoryRod, waterPart, waterPos)
        
        if result then
            log("✓ Server response: Fish hooked!")
            if type(result) == "table" then
                if result.Item then
                    log("  Item: " .. tostring(result.Item))
                end
                if result.Difficulty then
                    log("  Difficulty: " .. tostring(result.Difficulty))
                end
            end
        else
            logWarn("No server response (might be normal)")
        end
        
        -- Wait for minigame
        log("Waiting " .. Settings.FishDelay .. "s for minigame...")
        local waited = 0
        local wasMinigameActive = false
        
        while State.Enabled and waited < Settings.FishDelay do
            task.wait(0.5)
            waited = waited + 0.5
            
            -- Track minigame state
            if State.IsMinigameActive and not wasMinigameActive then
                wasMinigameActive = true
                log("Minigame detected at " .. waited .. "s")
            end
            
            -- Check if minigame ended early
            if wasMinigameActive and not State.IsMinigameActive and waited > 1 then
                log("Minigame ended early at " .. waited .. "s")
                break
            end
        end
        
        if State.Enabled then
            State.FishCount = State.FishCount + 1
            log("✓ Fish #" .. State.FishCount .. " complete!")
        end
    end)
    
    if not success then
        logError("doFishing error: " .. tostring(err))
    end
    
    State.IsFishing = false
    return success
end

-- ============================================
-- CLEANUP
-- ============================================
local function fullCleanup()
    log("Running full cleanup...")
    
    stopMinigameWatcher()
    
    if State.FishingThread then
        pcall(function() task.cancel(State.FishingThread) end)
        State.FishingThread = nil
        log("Cancelled fishing thread")
    end
    
    local fishCount = State.FishCount
    
    State.Enabled = false
    State.IsFishing = false
    State.IsMinigameActive = false
    State.ZoneExpanded = false
    State.FishCount = 0
    State.ClickCount = 0
    State.LastClickTime = 0
    State.LastNoRodWarning = 0
    State.LastNoWaterWarning = 0
    State.MinigameStartTime = 0
    
    log("Cleanup complete (caught " .. fishCount .. " fish)")
end

-- ============================================
-- PUBLIC API
-- ============================================
function FishFarm.Init(deps)
    Remote = deps.Remote
    log("Initialized (Debug: " .. tostring(DEBUG) .. ", Verbose: " .. tostring(DEBUG_VERBOSE) .. ")")
end

function FishFarm.Start()
    if State.Enabled then 
        logWarn("Already running!")
        return 
    end
    
    log("═══════════════════════════")
    log("      FISH FARM START      ")
    log("═══════════════════════════")
    log("Settings:")
    log("  FishDelay: " .. Settings.FishDelay .. "s")
    log("  AutoClick: " .. tostring(Settings.AutoClick))
    log("  ExpandZone: " .. tostring(Settings.ExpandZone))
    log("  ZoneSize: " .. (ZONE_SIZE_EXPLOIT * 100) .. "%")
    
    fullCleanup()
    State.Enabled = true
    
    startMinigameWatcher()
    
    State.FishingThread = task.spawn(function()
        log("Fishing loop started")
        
        while State.Enabled do
            local rod = getEquippedRod()
            
            if not rod then
                local now = os.clock()
                if now - State.LastNoRodWarning >= 30 then
                    State.LastNoRodWarning = now
                    log("⏳ Waiting for rod to be equipped...")
                end
                task.wait(CYCLE_DELAY)
                continue
            end
            
            local waterPart, waterDist = getNearestWater()
            
            if not waterPart then
                local now = os.clock()
                if now - State.LastNoWaterWarning >= 30 then
                    State.LastNoWaterWarning = now
                    log("⏳ No water nearby (range: " .. WATER_RANGE .. " studs)")
                end
                task.wait(CYCLE_DELAY)
                continue
            end
            
            doFishing(rod, waterPart)
            
            task.wait(1)
        end
        
        log("Fishing loop ended")
    end)
end

function FishFarm.Stop()
    if not State.Enabled then 
        logWarn("Not running!")
        return 
    end
    
    log("═══════════════════════════")
    log("      FISH FARM STOP       ")
    log("═══════════════════════════")
    
    pcall(function() 
        Remote.EndCatching() 
        log("Called EndCatching")
    end)
    
    fullCleanup()
end

function FishFarm.IsEnabled()
    return State.Enabled
end

function FishFarm.Cleanup()
    FishFarm.Stop()
end

function FishFarm.UpdateSetting(key, value)
    log("Setting changed: " .. key .. " = " .. tostring(value))
    
    if key == "FishDelay" then
        Settings.FishDelay = value or 5
    elseif key == "AutoClick" then
        Settings.AutoClick = value
    elseif key == "ExpandZone" then
        Settings.ExpandZone = value
    end
end

function FishFarm.GetFishCount()
    return State.FishCount
end

-- Debug toggle
function FishFarm.SetDebug(enabled, verbose)
    DEBUG = enabled
    DEBUG_VERBOSE = verbose or false
    log("Debug mode: " .. tostring(DEBUG) .. ", Verbose: " .. tostring(DEBUG_VERBOSE))
end

return FishFarm
