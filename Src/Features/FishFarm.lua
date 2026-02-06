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
local CAST_COOLDOWN = 0.7  -- Faster cooldown for aggressive retries

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
    -- Smart Farm State
    LastWaterPos = nil,
    LastWaterCheckTime = 0,
    CurrentBobber = nil,
    BobberName = nil, -- Cache for auto-learned name
    CastStartTime = 0,
    ActiveHotspot = nil, -- Cache for active hotspot
}

-- Settings
local Settings = {
    FishDelay = 20,
    AutoClick = true,
    ExpandZone = true,
    AutoHotspot = false, -- New Setting
}

-- ============================================
-- HELPERS
-- ============================================
local function isRod(name)
    if not name then return false end
    if not ROD_KEYWORD then return false end
    -- Check string library just in case
    if not string or not string.lower or not string.find then return false end
    
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

local function findBobber()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    -- 1. Fast Path: Check known name
    if State.BobberName then
        local bobber = char:FindFirstChild(State.BobberName, true)
        if bobber then return bobber end
    end
    
    -- 2. Discovery Mode (Run once efficiently)
    -- A. Check Rod Children (Priority - Most likely location)
    local rod = getEquippedRod()
    if rod then
        for _, child in ipairs(rod:GetDescendants()) do
            if child:IsA("BasePart") then
                local name = string.lower(child.Name)
                if string.find(name, "bobber") or string.find(name, "float") or string.find(name, "lure") then
                    State.BobberName = child.Name
                    log("🔍 Auto-detected Bobber in Rod: " .. child.Name)
                    return child
                end
            end
        end
    end

    -- B. Check Character descendants (Fallback)
    for _, child in ipairs(char:GetDescendants()) do
        if child:IsA("BasePart") then
            local name = string.lower(child.Name)
            if string.find(name, "bobber") or string.find(name, "float") or string.find(name, "lure") then
                State.BobberName = child.Name 
                log("🔍 Auto-detected Bobber in Char: " .. child.Name)
                return child
            end
        end
    end
    
    -- 3. Deep Fallback (Only if CastStartTime is recent)
    -- If we just casted < 1s ago, the bobber might be spawning in Workspace
    if tick() - State.CastStartTime < 1.0 then
        -- Only scan 10 studs around impact cache (LastWaterPos) to prevent lag
        -- (Skipped for now to strictly follow anti-lag request, usually it's in character)
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
    
    -- 1. Check Cache (Reuse water if player hasn't moved far)
    if State.LastWaterPos then
        local dist = (State.LastWaterPos.Position - root.Position).Magnitude
        if dist <= WATER_RANGE then
            return State.LastWaterPos, dist
        end
        State.LastWaterPos = nil -- Cache invalid
    end
    
    -- 2. Scan (Throttle: Max once per second if failing)
    local now = tick()
    if now - State.LastWaterCheckTime < 1 then
        return nil -- Throttle scan
    end
    State.LastWaterCheckTime = now
    
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
    
    -- Update Cache
    if nearestWater then
        State.LastWaterPos = nearestWater
    end
    
    return nearestWater, nearestDist
end

-- New: Accurate Center of nearest FishingZone
local function getNearestZoneCenter()
    local root = getRoot()
    if not root then return nil end
    
    local landmarks = Workspace.Map:FindFirstChild("Landmarks")
    if not landmarks then return nil end
    
    local bestZone = nil
    local bestDist = math.huge
    local centerPos = nil
    
    for _, landmark in ipairs(landmarks:GetChildren()) do
        local zone = landmark:FindFirstChild("FishingZone")
        if zone then
            -- FishingZone is usually a Model/Folder with parts
            -- We want the geometric center. Finding main part or calculating bounds.
            local pivot = zone:GetPivot().Position
            local dist = (pivot - root.Position).Magnitude
            
            if dist < bestDist and dist <= WATER_RANGE * 1.5 then
                bestDist = dist
                bestZone = zone
                centerPos = pivot
            end
        end
    end
    
    return centerPos, bestDist
end

-- New: Global Active Hotspot Scanner (For Teleport)
local function getGlobalActiveHotspot()
    local landmarks = Workspace.Map:FindFirstChild("Landmarks")
    if not landmarks then return nil end
    
    local bestHotspot = nil
    local shortestDist = math.huge
    local root = getRoot()
    if not root then return nil end
    
    for _, landmark in ipairs(landmarks:GetChildren()) do
        local zone = landmark:FindFirstChild("FishingZone")
        if zone then
            local hotspots = zone:FindFirstChild("Hotspots")
            if hotspots then
                for _, hotspot in ipairs(hotspots:GetChildren()) do
                    -- SUPPORT: Handle both Parts and Models safely
                    local isPart = hotspot:IsA("BasePart")
                    local isModel = hotspot:IsA("Model")
                    
                    if isPart or isModel then
                        local bubbles = hotspot:FindFirstChild("Bubbles")
                        -- STRICT CHECK: Must be Enabled=true
                        if bubbles and bubbles:IsA("ParticleEmitter") and bubbles.Enabled then
                            local pos = isPart and hotspot.Position or hotspot:GetPivot().Position
                            local dist = (pos - root.Position).Magnitude
                            
                            if dist < shortestDist then
                                shortestDist = dist
                                bestHotspot = hotspot
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestHotspot
end

local function getNearestHotspot()
    local root = getRoot()
    if not root then return nil end
    
    local landmarks = Workspace.Map:FindFirstChild("Landmarks")
    if not landmarks then return nil end
    
    local bestHotspot = nil
    local bestDist = math.huge
    
    -- Iterate through landmarks to find active bubbles
    for _, landmark in ipairs(landmarks:GetChildren()) do
        local zone = landmark:FindFirstChild("FishingZone")
        if zone then
            local hotspots = zone:FindFirstChild("Hotspots")
            if hotspots then
                for _, hotspot in ipairs(hotspots:GetChildren()) do
                    local isPart = hotspot:IsA("BasePart")
                    local isModel = hotspot:IsA("Model")
                    
                    if isPart or isModel then
                        local bubbles = hotspot:FindFirstChild("Bubbles")
                        -- Check for Active ParticleEmitter
                        if bubbles and bubbles:IsA("ParticleEmitter") and bubbles.Enabled then
                            local pos = isPart and hotspot.Position or hotspot:GetPivot().Position
                            local dist = (pos - root.Position).Magnitude
                            
                            if dist < bestDist and dist <= WATER_RANGE then
                                bestDist = dist
                                bestHotspot = hotspot
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestHotspot, bestDist
end

-- Debug Visualizer
local function visualizeTarget(pos)
    if not pos then return end
    
    local viz = Workspace:FindFirstChild("FishFarmViz")
    if not viz then
        viz = Instance.new("Part")
        viz.Name = "FishFarmViz"
        viz.Shape = Enum.PartType.Ball
        viz.Size = Vector3.new(1, 1, 1)
        viz.Material = Enum.Material.Neon
        viz.Color = Color3.fromRGB(255, 0, 0) -- RED = Target
        viz.Anchored = true
        viz.CanCollide = false
        viz.Parent = Workspace
    end
    viz.Position = pos
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
            
            -- FIX: Animation needs ~1.5s+ to reset. 
            -- We wait 2.5s to be safe and perfectly synced.
            State.LastCastTime = tick() - CAST_COOLDOWN + 1.2
            log("⏳ Waiting for animation reset...")
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
    local targetPos = nil
    
    -- 1. Check for Active Hotspot (Priority for casting)
    local hotspot, hDist = getNearestHotspot() -- Function created in prev step (checks local range)
    if hotspot then
        -- REVERT: Y-Sync caused parallax issues if water level was wrong.
        -- Using direct hotspot position is safer if dev placed it correctly.
        targetPos = hotspot:IsA("BasePart") and hotspot.Position or hotspot:GetPivot().Position
        log("🔥 Targeting Nearby Hotspot: " .. math.floor(hDist) .. " studs")
    else
        -- 2. Accurate Zone Targeting (Normal Mode)
        local zoneCenter, zDist = getNearestZoneCenter()
        if zoneCenter then
             targetPos = zoneCenter
             -- Adjust height to water level
             if water then targetPos = Vector3.new(targetPos.X, water.Position.Y, targetPos.Z) end
             log("🎯 Targeting Zone Center: " .. math.floor(zDist) .. " studs")
        else
             -- 3. Fallback: Standard Offset
             targetPos = playerPos + lookVector * 8
             targetPos = Vector3.new(targetPos.X, water.Position.Y, targetPos.Z)
        end
    end
    
    -- Debug: Show where we are aiming
    visualizeTarget(targetPos)
    
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
    
    -- OFFSET FIX: Account for GuiInset (TopBar)
    local guiInset = game:GetService("GuiService"):GetGuiInset()
    local screenX = math.floor(screenPos.X)
    local screenY = math.floor(screenPos.Y + guiInset.Y) -- Add inset to Y
    
    State.LastCastTime = tick()
    State.CastStartTime = tick() -- Capture precise start time for smart logic
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
    State.ActiveHotspot = nil -- Fix: Clear reference to prevent memory leaks
    
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

local function setAnchored(shouldAnchor)
    State.Anchored = shouldAnchor
    local root = getRoot()
    if root then root.Anchored = shouldAnchor end
    
    if State.AnchorGui then
        local btn = State.AnchorGui:FindFirstChild("AnchorButton")
        local stroke = btn and btn:FindFirstChild("UIStroke")
        
        if btn and stroke then
            if shouldAnchor then
                btn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                btn.Text = "🔒 LOCKED"
                stroke.Color = Color3.fromRGB(80, 200, 80)
            else
                btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                btn.Text = "🔓 ANCHOR"
                stroke.Color = Color3.fromRGB(120, 120, 120)
            end
        end
    end
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
        local castAttempts = 0
        
        -- FIX: Initial delay for equip animation / start sync
        log("⏳ Warming up (1.5s)...")
        task.wait(1.5)
        
        while State.Enabled do
            -- 1. Throttling: Slow down if minigame not active
             if not State.IsMinigameActive and not State.WaitingForMinigame then
                  task.wait(0.1) -- Fast throttle
             else
                 RunService.Heartbeat:Wait()
            end

            -- 2. Validate Rod & Water
            local rod = getEquippedRod()
            if not rod then
                -- Reset state
                State.LastWaterPos = nil
                State.CurrentBobber = nil
                
                local now = os.clock()
                if now - noRodWarn >= 30 then
                    noRodWarn = now
                    log("⏳ Equip a rod...")
                end
                continue
            end
            
            local water = getNearestWater()
            if not water then
                local now = os.clock()
                if now - noWaterWarn >= 30 then
                    noWaterWarn = now
                    log("⏳ Go near water...")
                end
                continue
            end
            
            -- 3. Minigame Active? (Just wait)
            if State.IsMinigameActive then
                continue
            end
            
            -- [NEW] Auto Hotspot Hunt Logic
            if Settings.AutoHotspot and not State.WaitingForMinigame then
                -- Check if current spot is still valid
                local currentSpotValid = false
                if State.ActiveHotspot then
                    -- Safety: Check if object still exists in game
                    if State.ActiveHotspot.Parent then
                        local bubbles = State.ActiveHotspot:FindFirstChild("Bubbles")
                        if bubbles and bubbles:IsA("ParticleEmitter") and bubbles.Enabled then
                             currentSpotValid = true
                             
                             -- AUTO-ANCHOR: Ensure we are anchored while fishing at valid spot
                             if not State.Anchored then
                                 setAnchored(true)
                                 log("⚓ Auto-Anchored at Hotspot")
                             end
                        else
                             log("⚠ Current hotspot expired!")
                             State.ActiveHotspot = nil
                        end
                    else
                        State.ActiveHotspot = nil -- Object destroyed
                    end
                end
                
                -- If no valid spot, HUNT!
                if not currentSpotValid then
                    log("🔎 Scanning for global hotspots...")
                    
                    -- Unanchor before moving
                    if State.Anchored then
                        setAnchored(false)
                        log("⚓ Unanchored for Teleport")
                    end
                    
                    local targetHotspot = getGlobalActiveHotspot()
                    
                    if targetHotspot then
                        log("🚀 Found Hotspot! Teleporting...")
                        
                        -- Teleport Logic
                        local root = getRoot()
                        if root then
                            -- Teleport slightly above and away to avoid falling in
                            local targetCFrame = targetHotspot.CFrame * CFrame.new(0, 5, 8)
                            -- Look at hotspot
                            targetCFrame = CFrame.lookAt(targetCFrame.Position, targetHotspot.Position)
                            
                            root.CFrame = targetCFrame
                            State.ActiveHotspot = targetHotspot
                            State.LastWaterPos = nil -- Reset water cache
                            
                            -- Stabilize
                            log("⏳ Stabilizing...")
                            task.wait(1.5)
                            
                            -- Re-anchor immediately after stabilize
                            setAnchored(true)
                            log("⚓ Anchor restored")
                        end
                    else
                        logWarn("No active hotspots found. Waiting...")
                        task.wait(2)
                        continue
                    end
                end
            end
            
            -- 4. SMART LOGIC: Bobber Detection
            local bobber = findBobber()
            
            if State.WaitingForMinigame then
                -- We are waiting for fish...
                local timeSinceCast = tick() - State.LastCastTime
                
                if bobber then
                    -- Good! Bobber exists.
                    State.CurrentBobber = bobber
                    
                    if timeSinceCast > Settings.FishDelay + 5 then
                        -- Stuck too long? Recast
                        log("⚠ Stuck (timeout), recasting...")
                        State.WaitingForMinigame = false
                    end
                else
                    -- No bobber found?
                    if timeSinceCast > 1.2 then -- Aggressive check (was 1.5)
                        -- If 1.2s passed and still no bobber -> CAST FAILED or LINE CUT
                        log("⚡ Smart Recast: Cast failed / Bobber lost")
                        State.WaitingForMinigame = false -- Trigger recast
                    end
                    -- < 1.5s: Allow time for bobber to spawn
                end
            end
            
            -- 5. Casting Logic
            if not State.WaitingForMinigame then
                -- Ready to cast
                
                -- Check cooldown
                if tick() - State.LastCastTime < CAST_COOLDOWN then
                    continue
                end
                
                if doCast() then
                    castAttempts = castAttempts + 1
                    -- Reset bobber state
                    State.CurrentBobber = nil
                end
                
                task.wait(0.1) -- Snappy response
            end
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
    elseif key == "AutoHotspot" then
        Settings.AutoHotspot = value
        log("AutoHotspot: " .. tostring(value))
    end
end

function FishFarm.GetFishCount()
    return State.FishCount
end

return FishFarm
