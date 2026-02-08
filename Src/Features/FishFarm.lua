local FishFarm = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Remote = nil

local WATER_RANGE = 50
local CYCLE_DELAY = 1
local ZONE_SIZE_EXPLOIT = 0.99
local CLICK_COOLDOWN = 0.2
local CAST_COOLDOWN = 0.7

local DEBUG = getgenv().OP_DEBUG or false
local function log(msg)
    if DEBUG then print("[FishFarm] " .. msg) end
end
local function logWarn(msg)
    warn("[FishFarm] " .. msg)
end

local State = {
    Enabled = false,
    IsStarting = false,
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
    LastWaterPos = nil,
    LastWaterCheckTime = 0,
    CurrentBobber = nil,
    BobberName = nil,
    CastStartTime = 0,
    ActiveHotspot = nil,
    CharacterConnection = nil,
    AnchorButtonConnection = nil,
    AnchorLoop = nil,
    OriginalZoneSize = nil,
}

local function setupCharacterConnection()
    if State.CharacterConnection then
        State.CharacterConnection:Disconnect()
        State.CharacterConnection = nil
    end
    
    State.CharacterConnection = LocalPlayer.CharacterAdded:Connect(function(character)
        if State.Anchored then
            State.Anchored = false
        end
        State.CurrentBobber = nil
        State.BobberName = nil
        log("Character respawned, state reset")
    end)
end

setupCharacterConnection()

local Settings = {
    FishDelay = 20, 
    AutoClick = true,
    ExpandZone = true,
    AutoHotspot = false,
    RodKeyword = "rod",
    Debug = false,
}

local function isRod(name)
    if not name then return false end
    local keyword = Settings.RodKeyword or "rod"
    if not keyword or keyword == "" then return false end
    if not string or not string.lower or not string.find then return false end
    
    return string.find(string.lower(name), string.lower(keyword)) ~= nil
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

local function getObjectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then
        return obj.Position
    elseif obj:IsA("Model") then
        return obj:GetPivot().Position
    else
        local primaryPart = obj:IsA("Model") and obj.PrimaryPart
        if primaryPart then return primaryPart.Position end
        local firstPart = obj:FindFirstChildWhichIsA("BasePart", true)
        if firstPart then return firstPart.Position end
    end
    return nil
end

local function findBobber()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = getRoot()
    
    if State.BobberName then
        local bobber = char:FindFirstChild(State.BobberName, true)
        if bobber and bobber.Parent then
            local bobberPos = getObjectPosition(bobber)
            if root and bobberPos then
                local dist = (bobberPos - root.Position).Magnitude
                if dist <= WATER_RANGE * 2 then
                    return bobber
                else
                    State.BobberName = nil
                    log("⚠ Cached bobber too far, resetting cache")
                end
            elseif bobberPos then
                return bobber
            end
        else
            State.BobberName = nil
        end
    end
    
    for _, child in ipairs(char:GetChildren()) do
        local name = string.lower(child.Name)
        if string.find(name, "bobber") or string.find(name, "float") or string.find(name, "lure") then
            local childPos = getObjectPosition(child)
            if root and childPos then
                local dist = (childPos - root.Position).Magnitude
                if dist > 3 then
                    State.BobberName = child.Name
                    log("🔍 Auto-detected Bobber: " .. child.Name .. " (dist: " .. math.floor(dist) .. ")")
                    return child
                end
            else
                State.BobberName = child.Name
                return child
            end
        end
    end
    
    local toolHandle = char:FindFirstChild("ToolHandle")
    if toolHandle then
        for _, child in ipairs(toolHandle:GetChildren()) do
            local name = string.lower(child.Name)
            if string.find(name, "bobber") or string.find(name, "float") or string.find(name, "lure") then
                local childPos = getObjectPosition(child)
                if root and childPos then
                    local dist = (childPos - root.Position).Magnitude
                    if dist > 3 then
                        State.BobberName = child.Name
                        log("🔍 Auto-detected Bobber in ToolHandle: " .. child.Name)
                        return child
                    end
                else
                    State.BobberName = child.Name
                    return child
                end
            end
        end
    end
    
    if tick() - State.CastStartTime < 1.0 then
    end

    return nil
end

local function getNearestWater()
    local root = getRoot()
    if not root then return nil end
    
    if State.LastWaterPos then
        if State.LastWaterPos.Parent then
            local dist = (State.LastWaterPos.Position - root.Position).Magnitude
            if dist <= WATER_RANGE then
                return State.LastWaterPos, dist
            end
        end
        State.LastWaterPos = nil
    end
    
    local now = tick()
    if now - State.LastWaterCheckTime < 1 then
        return nil
    end
    
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
    
    State.LastWaterCheckTime = now
    
    if nearestWater then
        State.LastWaterPos = nearestWater
    end
    
    return nearestWater, nearestDist
end

local function getNearestZoneCenter()
    local root = getRoot()
    if not root then return nil end
    
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return nil end
    
    local landmarks = mapFolder:FindFirstChild("Landmarks")
    if not landmarks then return nil end
    
    local bestZone = nil
    local bestDist = math.huge
    local centerPos = nil
    
    for _, landmark in ipairs(landmarks:GetChildren()) do
        local zone = landmark:FindFirstChild("FishingZone")
        if zone then
            local zonePos = nil
            
            if zone:IsA("BasePart") then
                zonePos = zone.Position
            elseif zone:IsA("Model") then
                zonePos = zone:GetPivot().Position
            else
                local firstPart = zone:FindFirstChildWhichIsA("BasePart", true)
                if firstPart then
                    zonePos = firstPart.Position
                end
            end
            
            if zonePos then
                local dist = (zonePos - root.Position).Magnitude
                
                if dist < bestDist and dist <= WATER_RANGE * 1.5 then
                    bestDist = dist
                    bestZone = zone
                    centerPos = zonePos
                end
            end
        end
    end
    
    return centerPos, bestDist
end

local function getGlobalActiveHotspot()
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return nil end
    
    local landmarks = mapFolder:FindFirstChild("Landmarks")
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
                    local isPart = hotspot:IsA("BasePart")
                    local isModel = hotspot:IsA("Model")
                    
                    if isPart or isModel then
                        local bubbles = hotspot:FindFirstChild("Bubbles")
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
    
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return nil end
    
    local landmarks = mapFolder:FindFirstChild("Landmarks")
    if not landmarks then return nil end
    
    local bestHotspot = nil
    local bestDist = math.huge
    
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

local function visualizeTarget(pos)
    if not pos then return end
    
    local oldViz = Workspace:FindFirstChild("FishFarmViz")
    if oldViz then
        pcall(function() oldViz:Destroy() end)
    end
    
    pcall(function()
        local viz = Instance.new("Part")
        viz.Name = "FishFarmViz"
        viz.Shape = Enum.PartType.Ball
        viz.Size = Vector3.new(1, 1, 1)
        viz.Material = Enum.Material.Neon
        viz.Color = Color3.fromRGB(255, 0, 0)
        viz.Anchored = true
        viz.CanCollide = false
        viz.Transparency = 0.3
        viz.Parent = Workspace
        viz.Position = pos
    end)
end

local function clickAtWorldPosition(worldPos)
    local camera = getCamera()
    if not camera then return false end
    
    local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
    
    if not onScreen then
        logWarn("Water not on screen!")
        return false
    end
    
    local screenX = math.floor(screenPos.X)
    local screenY = math.floor(screenPos.Y)
    
    log("Clicking at screen: " .. screenX .. ", " .. screenY)
    
    local success, err = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(screenX, screenY, 0, true, game, 0)
        task.delay(0.1, function()
            pcall(function()
                vim:SendMouseButtonEvent(screenX, screenY, 0, false, game, 0)
            end)
        end)
    end)
    
    if not success then
        logWarn("VirtualInputManager failed: " .. tostring(err))
        logWarn("Your executor may not support VIM. Try a different executor.")
    end
    
    return success
end

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
        if not State.OriginalZoneSize then
            State.OriginalZoneSize = {
                Size = successArea.Size,
                Position = successArea.Position
            }
        end
        
        successArea.Size = UDim2.new(1, 0, ZONE_SIZE_EXPLOIT, 0)
        successArea.Position = UDim2.new(0.5, 0, 0.025, 0)
        State.ZoneExpanded = true
        log("✓ Zone expanded to " .. (ZONE_SIZE_EXPLOIT * 100) .. "%")
        return true
    end
    
    return false
end

local function restoreGreenZone()
    if not State.OriginalZoneSize then return end
    
    local frame = getFishingFrame()
    if not frame then
        State.OriginalZoneSize = nil
        return
    end
    
    local timingBar = frame:FindFirstChild("TimingBar")
    if not timingBar then
        State.OriginalZoneSize = nil
        return
    end
    
    local successArea = timingBar:FindFirstChild("SuccessArea")
    if successArea then
        pcall(function()
            successArea.Size = State.OriginalZoneSize.Size
            successArea.Position = State.OriginalZoneSize.Position
        end)
        log("Zone restored to original size")
    end
    
    State.OriginalZoneSize = nil
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
            
            State.LastCastTime = tick() - CAST_COOLDOWN + 1.2
            log("⏳ Waiting for animation reset...")
        end
    end
end

local function startMinigameWatcher()
    if State.MinigameConnection then
        log("MinigameWatcher already running, skipping restart")
        return
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
    
    restoreGreenZone()
end

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
    
    local lookVector = root.CFrame.LookVector
    local playerPos = root.Position
    local targetPos = nil
    local targetType = "unknown"

    
    local hotspot, hDist = getNearestHotspot()
    if hotspot then
        targetPos = hotspot:IsA("BasePart") and hotspot.Position or hotspot:GetPivot().Position
        targetType = "Hotspot"
        log("🎯 Targeting hotspot at " .. math.floor(hDist) .. " studs")
    else
        local zoneCenter, zDist = getNearestZoneCenter()
        if zoneCenter then
             targetPos = zoneCenter
             if water then targetPos = Vector3.new(targetPos.X, water.Position.Y, targetPos.Z) end
             targetType = "ZoneCenter"
             log("🎯 Targeting zone center at " .. math.floor(zDist) .. " studs")
        else
             targetPos = playerPos + lookVector * 8
             targetPos = Vector3.new(targetPos.X, water.Position.Y, targetPos.Z)
             targetType = "Fallback"
        end
    end
    
    visualizeTarget(targetPos)
    
    local screenPos, onScreen = camera:WorldToScreenPoint(targetPos)
    
    if not onScreen then
        log("📷 Auto-fixing camera to face target...")
        
        local camDistance = 15
        local camHeight = 8
        
        local toTarget = (targetPos - playerPos).Unit
        
        local camPos = playerPos - (toTarget * camDistance) + Vector3.new(0, camHeight, 0)
        
        camera.CFrame = CFrame.lookAt(camPos, targetPos)
        
        root.CFrame = CFrame.lookAt(playerPos, Vector3.new(targetPos.X, playerPos.Y, targetPos.Z))
        
        task.wait(0.3)
        
        screenPos, onScreen = camera:WorldToScreenPoint(targetPos)
        
        if onScreen then
            log("📷 Camera fixed! Target now on screen")
        else
            screenPos, onScreen = camera:WorldToScreenPoint(water.Position)
            if not onScreen then
                log("⚠ Cannot get target on screen, aborting cast")
                return false
            end
        end
    end
    
    local guiInset = game:GetService("GuiService"):GetGuiInset()
    
    local screenX = math.floor(screenPos.X)
    local screenY = math.floor(screenPos.Y + guiInset.Y)
    
    log("🎣 Casting at screen " .. screenX .. ", " .. screenY)
    
    State.LastCastTime = tick()
    State.CastStartTime = tick()
    State.WaitingForMinigame = true
    
    local success, err = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(screenX, screenY, 0, true, game, 0)
        task.delay(0.1, function()
            pcall(function()
                vim:SendMouseButtonEvent(screenX, screenY, 0, false, game, 0)
            end)
        end)
    end)
    
    if not success then
        logWarn("Cast failed: " .. tostring(err))
        State.WaitingForMinigame = false
        return false
    end
    
    return true
end

local function destroyVisualizer()
    local viz = Workspace:FindFirstChild("FishFarmViz")
    if viz then viz:Destroy() end
end

local function fullCleanup()
    destroyVisualizer()
    stopMinigameWatcher()
    
    if State.FishingThread then
        pcall(function() task.cancel(State.FishingThread) end)
        State.FishingThread = nil
    end
    
    local count = State.FishCount
    
    State.Enabled = false
    State.IsStarting = false
    State.FishCount = 0
    State.LastClickTime = 0
    State.LastCastTime = 0
    State.IsMinigameActive = false
    State.ZoneExpanded = false
    State.ClickCount = 0
    State.WaitingForMinigame = false
    State.ActiveHotspot = nil
    State.BobberName = nil
    State.CurrentBobber = nil
    State.LastWaterPos = nil
    State.CastStartTime = 0
    State.OriginalZoneSize = nil
    
    log("Cleanup (fish: " .. count .. ")")
end

local function setAnchored(shouldAnchor)
    State.Anchored = shouldAnchor
    local root = getRoot()
    
    if root then
        local existingBP = root:FindFirstChild("FishFarmAnchor")
        local existingBG = root:FindFirstChild("FishFarmGyro")
        local existingLoop = State.AnchorLoop
        
        if shouldAnchor then
            local lockPos = root.Position
            local lockCFrame = root.CFrame
            
            if not existingBP then
                local bp = Instance.new("BodyPosition")
                bp.Name = "FishFarmAnchor"
                bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bp.D = 1000
                bp.P = 50000
                bp.Position = lockPos
                bp.Parent = root
            else
                existingBP.Position = lockPos
            end
            
            if not existingBG then
                local bg = Instance.new("BodyGyro")
                bg.Name = "FishFarmGyro"
                bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bg.D = 1000
                bg.P = 50000
                bg.CFrame = lockCFrame
                bg.Parent = root
            else
                existingBG.CFrame = lockCFrame
            end
            
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            
            if not existingLoop then
                State.AnchorLoop = RunService.Heartbeat:Connect(function()
                    if State.Anchored and root and root.Parent then
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                    end
                end)
            end
        else
            if existingBP then existingBP:Destroy() end
            if existingBG then existingBG:Destroy() end
            if existingLoop then
                existingLoop:Disconnect()
                State.AnchorLoop = nil
            end
        end
    end
    
    if State.AnchorGui then
        local btn = State.AnchorGui:FindFirstChild("AnchorButton")
        local stroke = btn and btn:FindFirstChild("UIStroke")
        
        if btn and stroke then
            if shouldAnchor then
                btn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                btn.Text = "LOCKED"
                stroke.Color = Color3.fromRGB(80, 200, 80)
            else
                btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                btn.Text = "ANCHOR"
                stroke.Color = Color3.fromRGB(120, 120, 120)
            end
        end
    end
end

local function createAnchorGui()
    if State.AnchorGui then return end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "FishFarmAnchorGui"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer:FindFirstChild("PlayerGui")
    
    State.AnchorGui = gui
    
    local anchorBtn = Instance.new("TextButton")
    anchorBtn.Name = "AnchorButton"
    anchorBtn.Size = UDim2.new(0, 90, 0, 40)
    anchorBtn.Position = UDim2.new(0, 20, 0.7, 0)
    anchorBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    anchorBtn.Text = "ANCHOR"
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
    
    State.AnchorButtonConnection = anchorBtn.MouseButton1Click:Connect(function()
        setAnchored(not State.Anchored)
        log("Player " .. (State.Anchored and "ANCHORED" or "UNANCHORED"))
    end)
    
    log("Anchor button created")
end

local function destroyAnchorGui()
    if State.Anchored then
        setAnchored(false)
    end
    
    if State.AnchorButtonConnection then
        State.AnchorButtonConnection:Disconnect()
        State.AnchorButtonConnection = nil
    end
    
    if State.AnchorGui then
        pcall(function()
            State.AnchorGui:Destroy()
        end)
        State.AnchorGui = nil
    end
end

function FishFarm.Init(deps)
    Remote = deps.Remote
    log("Initialized")
end

function FishFarm.Start()
    if State.Enabled or State.IsStarting then return end
    State.IsStarting = true
    
    log("═══════════════════════════")
    log("      FISH FARM START      ")
    log("═══════════════════════════")
    log("FishDelay: " .. Settings.FishDelay .. "s")
    
    State.FishCount = 0
    State.LastClickTime = 0
    State.LastCastTime = 0
    State.IsMinigameActive = false
    State.ZoneExpanded = false
    State.ClickCount = 0
    State.WaitingForMinigame = false
    State.ActiveHotspot = nil
    State.BobberName = nil
    State.CurrentBobber = nil
    State.LastWaterPos = nil
    State.CastStartTime = 0
    State.OriginalZoneSize = nil
    
    State.Enabled = true
    State.IsStarting = false
    
    createAnchorGui()
    startMinigameWatcher()
    
    State.FishingThread = task.spawn(function()
        local noRodWarn = 0
        local noWaterWarn = 0
        local castAttempts = 0
        
        log("⏳ Warming up (1.5s)...")
        task.wait(1.5)
        
        while State.Enabled do
             if not State.IsMinigameActive and not State.WaitingForMinigame then
                  task.wait(0.1)
             else
                 RunService.Heartbeat:Wait()
            end
            
            local rod = getEquippedRod()
            if not rod then
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
                local needsTeleport = Settings.AutoHotspot and not State.ActiveHotspot
                if not needsTeleport then
                    local now = os.clock()
                    if now - noWaterWarn >= 30 then
                        noWaterWarn = now
                        log("⏳ Go near water...")
                    end
                    continue
                end
            end
            
            if State.IsMinigameActive then
                continue
            end
            
            if Settings.AutoHotspot and not State.WaitingForMinigame then
                local currentSpotValid = false
                if State.ActiveHotspot then
                    if State.ActiveHotspot.Parent then
                        local bubbles = State.ActiveHotspot:FindFirstChild("Bubbles")
                        
                        if bubbles and bubbles.Parent and bubbles:IsA("ParticleEmitter") and bubbles.Enabled then
                             currentSpotValid = true
                             
                             if not State.Anchored then
                                 setAnchored(true)
                                 log("⚓ Auto-Anchored at Hotspot")
                             end
                        else
                             log("⚠ Hotspot bubbles expired!")
                             State.ActiveHotspot = nil
                        end
                    else
                        log("⚠ Hotspot object destroyed")
                        State.ActiveHotspot = nil
                    end
                end
                
                if not currentSpotValid then
                    log("🔎 Hunting for new hotspot...")
                    
                    if State.Anchored then
                        setAnchored(false)
                    end
                    
                    local targetHotspot = getGlobalActiveHotspot()
                    
                    if targetHotspot then
                        log("🚀 Teleporting to hotspot!")
                        
                        local root = getRoot()
                        local camera = getCamera()
                        if root then
                            local hotspotCFrame, hotspotPos
                            if targetHotspot:IsA("BasePart") then
                                hotspotCFrame = targetHotspot.CFrame
                                hotspotPos = targetHotspot.Position
                            else
                                hotspotCFrame = targetHotspot:GetPivot()
                                hotspotPos = hotspotCFrame.Position
                            end
                            
                            local direction = (hotspotPos - root.Position).Unit
                            local targetPos = hotspotPos - (direction * 8) + Vector3.new(0, 5, 0)
                            local targetCFrame = CFrame.lookAt(targetPos, hotspotPos)
                            
                            root.CFrame = targetCFrame
                            
                            if camera then
                                camera.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 2, 0), hotspotPos)
                            end
                            
                            State.ActiveHotspot = targetHotspot
                            State.LastWaterPos = nil
                            
                            log("⏳ Stabilizing position...")
                            task.wait(2.5)
                            
                            if camera and root then
                                local lookAtPos = hotspotPos
                                root.CFrame = CFrame.lookAt(root.Position, Vector3.new(lookAtPos.X, root.Position.Y, lookAtPos.Z))
                            end
                            
                            setAnchored(true)
                            log("⚓ Ready to fish!")
                            
                            task.wait(0.5)
                        end
                    else
                        log("⏳ No hotspots found, waiting...")
                        task.wait(3)
                        continue
                    end
                end
            end
            
            local bobber = findBobber()
            
            if State.WaitingForMinigame then
                local timeSinceCast = tick() - State.LastCastTime
                
                if bobber then
                    State.CurrentBobber = bobber
                    
                    if timeSinceCast > Settings.FishDelay + 5 then
                        log("⚠ Stuck (timeout), recasting...")
                        State.WaitingForMinigame = false
                    end
                else
                    if timeSinceCast > 1.2 then
                        log("⚡ Smart Recast: Cast failed / Bobber lost")
                        State.WaitingForMinigame = false
                    end
                end
            end
            
            if not State.WaitingForMinigame then
                if tick() - State.LastCastTime < CAST_COOLDOWN then
                    continue
                end
                
                if doCast() then
                    castAttempts = castAttempts + 1
                    State.CurrentBobber = nil
                end
                
                task.wait(0.1)
            end
        end
    end)
end

function FishFarm.Stop()
    if not State.Enabled and not State.IsStarting then return end
    State.IsStarting = false
    
    log("═══════════════════════════")
    log("      FISH FARM STOP       ")
    log("═══════════════════════════")
    
    destroyAnchorGui()
    if Remote and Remote.EndCatching then
        pcall(function() Remote.EndCatching() end)
    end
    fullCleanup()
end

function FishFarm.IsEnabled()
    return State.Enabled
end

function FishFarm.Cleanup()
    FishFarm.Stop()
    
    if State.CharacterConnection then
        State.CharacterConnection:Disconnect()
        State.CharacterConnection = nil
    end
    
    log("FishFarm fully cleaned up")
end

function FishFarm.UpdateSetting(key, value)
    log("Setting: " .. key .. " = " .. tostring(value))
    
    if key == "FishDelay" then
        Settings.FishDelay = value or 25
    elseif key == "AutoClick" then
        Settings.AutoClick = value
    elseif key == "ExpandZone" then
        Settings.ExpandZone = value
    elseif key == "AutoHotspot" then
        Settings.AutoHotspot = value
        log("AutoHotspot: " .. tostring(value))
    elseif key == "RodKeyword" then
        Settings.RodKeyword = value or "rod"
    elseif key == "Debug" then
        Settings.Debug = value
        DEBUG = value
    end
end

function FishFarm.GetFishCount()
    return State.FishCount
end

return FishFarm
