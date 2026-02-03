--[[
    Features/MapRevealer.lua
    Removes fog blocks to reveal the map using Spiral Fly approach
    
    v2.2 - Cleaned & Optimized:
    - Spiral fly algorithm from Campfire to MaxRadius
    - Anchor Mode for safe return (anti-void fall)
    - Optional Satellite Camera & ESP
]]

local MapRevealer = {}

-- Services
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Remote = nil

-- ============================================
-- STATE
-- ============================================
local State = {
    Scanning = false,
    Cancelled = false,
}

local FlyState = {
    IsFlying = false,
    BodyGyro = nil,
    BodyPos = nil,
    BodyVel = nil,
    FlyConnection = nil,
    NoClipConnection = nil,
    CharacterPartsCache = {},
    CachedCharRef = nil,
}

local CamState = {
    Connection = nil
}

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    -- Spiral Flight
    FlySpeed = 170,
    SpiralSpacing = 100,
    MaxRadius = 600,
    FlyHeight = 40,
    TouchRadius = 60,
    
    -- Features
    UseSatelliteCamera = false,
    
    -- Remote retry
    RetryAttempts = 2,
}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function getBoundariesFolder()
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    return map:FindFirstChild("Boundaries")
end

local function isFogPart(part)
    return part:IsA("BasePart") and part:FindFirstChild("TouchInterest")
end

local function tryFadeOutFogBlock(part, attempt)
    attempt = attempt or 1
    
    local success = pcall(function()
        Remote.FadeOutFogBlock("FireAllClients", part)
    end)
    
    if success then return true end
    
    if attempt < CONFIG.RetryAttempts then
        task.wait(0.05 * attempt)
        return tryFadeOutFogBlock(part, attempt + 1)
    end
    
    return false
end



-- ============================================
-- TOUCH SIMULATION
-- ============================================
local function simulateTouch(part, rootPart)
    if not part or not rootPart or not part.Parent then return false end
    
    local touchInterest = part:FindFirstChild("TouchInterest")
    if not touchInterest then return false end
    
    -- Method 1: firetouchinterest (executor API)
    if firetouchinterest then
        local success = pcall(function()
            firetouchinterest(part, rootPart, 0)
            firetouchinterest(part, rootPart, 1)
        end)
        if success then return true end
    end
    
    -- Method 2: Direct remote call (fallback)
    return tryFadeOutFogBlock(part)
end

local function touchNearbyFog(rootPart, touchRadius)
    local boundaries = getBoundariesFolder()
    if not boundaries then return 0 end
    
    local touched = 0
    local pos = rootPart.Position
    
    for _, part in ipairs(boundaries:GetChildren()) do
        if isFogPart(part) then
            local dist = (Vector3.new(part.Position.X, 0, part.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
            if dist <= touchRadius then
                if simulateTouch(part, rootPart) then
                    touched = touched + 1
                end
            end
        end
    end
    
    return touched
end

-- ============================================
-- FLY SYSTEM
-- ============================================
local function startFly(character, rootPart, humanoid)
    if FlyState.IsFlying or not rootPart or not humanoid then return end
    
    FlyState.IsFlying = true
    humanoid.PlatformStand = true
    
    -- BodyGyro for rotation stability
    FlyState.BodyGyro = Instance.new("BodyGyro")
    FlyState.BodyGyro.Name = "MapRevealBodyGyro"
    FlyState.BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    FlyState.BodyGyro.P = 50000
    FlyState.BodyGyro.D = 1000
    FlyState.BodyGyro.CFrame = rootPart.CFrame
    FlyState.BodyGyro.Parent = rootPart
    
    -- BodyPosition for position control
    FlyState.BodyPos = Instance.new("BodyPosition")
    FlyState.BodyPos.Name = "MapRevealBodyPosition"
    FlyState.BodyPos.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    FlyState.BodyPos.P = 50000
    FlyState.BodyPos.D = 1000
    FlyState.BodyPos.Position = rootPart.Position
    FlyState.BodyPos.Parent = rootPart
    
    -- BodyVelocity for smooth movement
    FlyState.BodyVel = Instance.new("BodyVelocity")
    FlyState.BodyVel.Name = "MapRevealBodyVelocity"
    FlyState.BodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    FlyState.BodyVel.Velocity = Vector3.zero
    FlyState.BodyVel.Parent = rootPart
    
    -- NoClip connection
    FlyState.NoClipConnection = RunService.Heartbeat:Connect(function()
        if not FlyState.IsFlying or not character or not character.Parent then return end
        
        -- Cache parts on character change
        if character ~= FlyState.CachedCharRef then
            FlyState.CachedCharRef = character
            FlyState.CharacterPartsCache = {}
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    table.insert(FlyState.CharacterPartsCache, part)
                end
            end
        end
        
        -- Disable collision
        for _, part in ipairs(FlyState.CharacterPartsCache) do
            if part.Parent and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
    
    -- Gyro update connection
    FlyState.FlyConnection = RunService.Heartbeat:Connect(function()
        if not FlyState.IsFlying or not rootPart or not rootPart.Parent then return end
        
        if FlyState.BodyGyro then
            FlyState.BodyGyro.CFrame = rootPart.CFrame
        end
        if FlyState.BodyPos then
            FlyState.BodyPos.Position = rootPart.Position
        end
    end)
end

local function stopFly(character, rootPart, humanoid)
    if not FlyState.IsFlying then return end
    
    FlyState.IsFlying = false
    
    -- Disconnect connections
    if FlyState.FlyConnection then
        pcall(function() FlyState.FlyConnection:Disconnect() end)
        FlyState.FlyConnection = nil
    end
    
    if FlyState.NoClipConnection then
        pcall(function() FlyState.NoClipConnection:Disconnect() end)
        FlyState.NoClipConnection = nil
    end
    
    -- Cleanup body movers from rootPart
    if rootPart then
        for _, child in pairs(rootPart:GetChildren()) do
            if child.Name:match("^MapReveal") then
                pcall(function() child:Destroy() end)
            end
        end
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end
    
    -- Nil out references
    FlyState.BodyGyro = nil
    FlyState.BodyPos = nil
    FlyState.BodyVel = nil
    
    -- Re-enable collision on main parts
    if character then
        for _, partName in pairs({"Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart"}) do
            local part = character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                pcall(function() part.CanCollide = true end)
            end
        end
    end
    
    if humanoid then
        humanoid.PlatformStand = false
    end
    
    FlyState.CharacterPartsCache = {}
    FlyState.CachedCharRef = nil
end

-- ============================================
-- CAMERA & ESP
-- ============================================
local function enableOverheadCamera(rootPart)
    local camera = Workspace.CurrentCamera
    if not camera or not rootPart then return end

    camera.CameraType = Enum.CameraType.Scriptable
    
    local CAM_HEIGHT = 200  -- Lowered from 400 to reduce StreamingEnabled issues
    local UP_VECTOR = Vector3.new(0, 0, -1)
    
    CamState.Connection = RunService.RenderStepped:Connect(function()
        if not rootPart or not rootPart.Parent then return end
        
        local targetPos = rootPart.Position
        local camPos = Vector3.new(targetPos.X, CAM_HEIGHT, targetPos.Z)
        camera.CFrame = CFrame.lookAt(camPos, targetPos, UP_VECTOR)
    end)
    
    print("[OP] Camera: Satellite Mode Active")
end

local function disableOverheadCamera()
    if CamState.Connection then
        CamState.Connection:Disconnect()
        CamState.Connection = nil
    end

    local camera = Workspace.CurrentCamera
    if camera then
        -- IMPORTANT: Reset CameraSubject BEFORE changing CameraType
        -- This prevents "Gameplay Paused" from StreamingEnabled
        local player = Players.LocalPlayer
        local character = player and player.Character
        if not character then
            -- Try Living folder (game-specific)
            local living = Workspace:FindFirstChild("Living")
            character = living and living:FindFirstChild(player.Name)
        end
        
        local humanoid = character and character:FindFirstChild("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        -- Force streaming to load content around player position
        if rootPart then
            pcall(function()
                player:RequestStreamAroundAsync(rootPart.Position, 0.5)  -- 0.5 second timeout
            end)
        end
        
        if humanoid then
            camera.CameraSubject = humanoid
        end
        
        -- Small delay to let streaming fully catch up
        task.wait(0.15)
        
        camera.CameraType = Enum.CameraType.Custom
    end
end

local function disablePlayerESP(character)
    -- Cleanup ScreenGui ESP
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChild("PlayerGui")
    if playerGui then
        local espGui = playerGui:FindFirstChild("MapRevealerESP")
        if espGui then espGui:Destroy() end
    end
end

local function enablePlayerESP(character)
    if not character then return end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    disablePlayerESP(character)
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MapRevealerESP"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    -- Marker Frame (red dot with ring)
    local markerFrame = Instance.new("Frame")
    markerFrame.Name = "Marker"
    markerFrame.Size = UDim2.new(0, 60, 0, 60)
    markerFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    markerFrame.BackgroundTransparency = 0.3
    markerFrame.BorderSizePixel = 0
    markerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    markerFrame.Parent = screenGui
    
    -- Make it circular
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = markerFrame
    
    -- Add stroke (ring)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 4
    stroke.Parent = markerFrame
    
    -- Center dot
    local centerDot = Instance.new("Frame")
    centerDot.Size = UDim2.new(0, 16, 0, 16)
    centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    centerDot.BorderSizePixel = 0
    centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
    centerDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    centerDot.Parent = markerFrame
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = centerDot
    
    -- Text label
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(0, 100, 0, 30)
    label.Position = UDim2.new(0.5, 0, 1, 10)
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.BackgroundTransparency = 1
    label.Text = "YOU"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.TextSize = 24
    label.Font = Enum.Font.GothamBold
    label.Parent = markerFrame
    
    -- Update position every frame
    local updateConn = RunService.RenderStepped:Connect(function()
        if not rootPart or not rootPart.Parent then return end
        if not screenGui or not screenGui.Parent then return end
        
        local camera = Workspace.CurrentCamera
        if not camera then return end
        
        local screenPos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
        
        if onScreen then
            markerFrame.Visible = true
            markerFrame.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
        else
            markerFrame.Visible = false
        end
    end)
    
    -- Cleanup on destroy
    screenGui.Destroying:Connect(function()
        pcall(function() updateConn:Disconnect() end)
    end)
end

-- ============================================
-- CAMPFIRE DETECTION
-- ============================================
local function getCampfireCenter()
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local playerPos = root and root.Position or Vector3.new(0, 10, 0)

    local closestFire = nil
    local minDst = math.huge
    
    local function checkCandidate(obj)
        if not obj then return end
        local pos = nil
        
        if obj:IsA("BasePart") then
            pos = obj.Position
        elseif obj:IsA("Model") then
            if obj.PrimaryPart then
                pos = obj.PrimaryPart.Position
            elseif obj:FindFirstChild("Center") then
                pos = obj.Center.Position
            else
                local cf = obj:GetBoundingBox()
                pos = cf.Position
            end
        end
        
        if pos then
            local dst = (pos - playerPos).Magnitude
            if dst < minDst then
                minDst = dst
                closestFire = pos
            end
        end
    end

    -- Fast path checks
    local explicitPaths = {
        Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Campground") and Workspace.Map.Campground:FindFirstChild("MainFire"),
        Workspace:FindFirstChild("Campground") and Workspace.Campground:FindFirstChild("MainFire"),
        Workspace:FindFirstChild("MainFire"),
    }
    for _, obj in ipairs(explicitPaths) do checkCandidate(obj) end

    -- Recursive fallback
    local searchRoot = Workspace:FindFirstChild("Map") or Workspace
    checkCandidate(searchRoot:FindFirstChild("MainFire", true))
    checkCandidate(searchRoot:FindFirstChild("Camp", true))

    if closestFire then
        print(string.format("[OP] MapRevealer: Found Campfire at %s (Dist: %.1f)", tostring(closestFire), minDst))
        return closestFire
    end

    -- Fallback: near origin
    if (playerPos - Vector3.zero).Magnitude < 200 then
        print("[OP] MapRevealer: Near origin, using 0,3.5,0")
        return Vector3.new(0, 3.5, 0)
    end

    print("[OP] MapRevealer: Using player position as center")
    return playerPos
end

-- ============================================
-- MAIN SPIRAL REVEAL
-- ============================================
local function runSpiralReveal(onProgress, onComplete)
    if State.Scanning then
        warn("[OP] MapRevealer: Already scanning!")
        return
    end
    
    State.Scanning = true
    State.Cancelled = false
    
    local player = Players.LocalPlayer
    local character = Workspace:FindFirstChild("Living") and Workspace.Living:FindFirstChild(player.Name)
    if not character then character = player.Character end
    
    local humanoid = character and character:FindFirstChild("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart or not humanoid then
        warn("[OP] MapRevealer: Character not found!")
        State.Scanning = false
        if onComplete then onComplete(0) end
        return
    end
    
    local center = getCampfireCenter()
    local flyHeight = CONFIG.FlyHeight
    
    print("[OP] MapRevealer: Spiral from " .. tostring(center) .. " at height " .. flyHeight)
    
    -- Enable features
    if CONFIG.UseSatelliteCamera then
        enableOverheadCamera(rootPart)
        enablePlayerESP(character)
    end
    
    -- Start fly
    startFly(character, rootPart, humanoid)
    task.wait(0.2)
    
    local totalRevealed = 0
    local startTime = tick()
    
    print("[OP] MapRevealer: Starting (speed=" .. CONFIG.FlySpeed .. ")")
    
    -- Spiral parameters
    local angle = 0
    local radius = CONFIG.SpiralSpacing
    local maxRadius = CONFIG.MaxRadius
    
    local function getTargetPos()
        local x = center.X + math.cos(angle) * radius
        local z = center.Z + math.sin(angle) * radius
        return Vector3.new(x, flyHeight, z)
    end
    
    local targetPos = getTargetPos()
    
    -- Main spiral loop
    while radius <= maxRadius do
        if State.Cancelled or not State.Scanning then break end
        if not rootPart.Parent then break end
        
        local currentPos = rootPart.Position
        local direction = (targetPos - currentPos)
        local distance = direction.Magnitude
        
        if distance < 5 then
            -- Reached waypoint - touch nearby fog
            totalRevealed = totalRevealed + touchNearbyFog(rootPart, CONFIG.TouchRadius)
            
            -- Calculate next spiral point
            local arcLength = CONFIG.SpiralSpacing * 0.8
            local angleStep = arcLength / math.max(radius, 10)
            
            angle = angle + angleStep
            radius = radius + (CONFIG.SpiralSpacing * angleStep / (2 * math.pi))
            
            targetPos = getTargetPos()
            
            if onProgress then
                onProgress("Spiral", math.floor(radius), maxRadius)
            end
        else
            -- Move towards target
            local velocity = direction.Unit * CONFIG.FlySpeed
            
            if FlyState.BodyVel then
                FlyState.BodyVel.Velocity = velocity
            else
                rootPart.AssemblyLinearVelocity = velocity
            end
            
            if FlyState.BodyPos then
                FlyState.BodyPos.Position = targetPos
            end
        end
        
        task.wait(1/60)
    end
    
    -- Stop movement
    if FlyState.BodyVel then FlyState.BodyVel.Velocity = Vector3.zero end
    rootPart.AssemblyLinearVelocity = Vector3.zero

    -- ========================================
    -- SAFE RETURN (Simple Teleport)
    -- ========================================
    local targetSafePos = center + Vector3.new(0, 5, 0)
    
    -- Teleport to campfire
    if rootPart and rootPart.Parent then
        rootPart.CFrame = CFrame.new(targetSafePos)
    end
    
    print("[OP] MapRevealer: Teleported to campfire")
    
    -- Disable features
    if CONFIG.UseSatelliteCamera then
        disableOverheadCamera()
        disablePlayerESP(character)
    end
    
    -- Stop fly
    stopFly(character, rootPart, humanoid)
    
    print("[OP] MapRevealer: Done!")
    
    State.Scanning = false
    
    if onComplete then
        onComplete(totalRevealed)
    end
end

-- ============================================
-- PUBLIC API
-- ============================================
function MapRevealer.Init(deps)
    Remote = deps.Remote
end

function MapRevealer.RevealSpiral(onProgress, onComplete)
    task.spawn(function()
        runSpiralReveal(onProgress, onComplete)
    end)
end

function MapRevealer.SetSpiralRadius(radius)
    CONFIG.MaxRadius = radius or 600
    print("[OP] MapRevealer: Radius set to " .. CONFIG.MaxRadius)
end

function MapRevealer.GetSpiralRadius()
    return CONFIG.MaxRadius
end

function MapRevealer.SetUseSatelliteCamera(enabled)
    CONFIG.UseSatelliteCamera = enabled
end

-- Full cleanup function (for unload)
function MapRevealer.Cleanup()
    -- Stop scanning
    State.Cancelled = true
    State.Scanning = false
    
    -- Stop camera
    disableOverheadCamera()
    
    -- Stop ESP (ScreenGui-based - will cleanup automatically)
    disablePlayerESP()
    
    -- Stop fly system
    if FlyState.IsFlying then
        local player = Players.LocalPlayer
        local character = Workspace:FindFirstChild("Living") and Workspace.Living:FindFirstChild(player.Name) or player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChild("Humanoid")
        stopFly(character, rootPart, humanoid)
        
        -- Ensure player is unanchored
        if rootPart and rootPart.Parent then
            rootPart.Anchored = false
        end
    end
    
    -- Disconnect any remaining connections
    if FlyState.FlyConnection then
        pcall(function() FlyState.FlyConnection:Disconnect() end)
        FlyState.FlyConnection = nil
    end
    
    if FlyState.NoClipConnection then
        pcall(function() FlyState.NoClipConnection:Disconnect() end)
        FlyState.NoClipConnection = nil
    end
    
    if CamState.Connection then
        pcall(function() CamState.Connection:Disconnect() end)
        CamState.Connection = nil
    end
    
    -- Clear caches
    FlyState.CharacterPartsCache = {}
    FlyState.CachedCharRef = nil
    FlyState.BodyGyro = nil
    FlyState.BodyPos = nil
    FlyState.BodyVel = nil
    
    print("[OP] MapRevealer: Cleanup complete")
end

-- Stop current operation
function MapRevealer.Stop()
    if State.Scanning then
        State.Cancelled = true
        print("[OP] MapRevealer: Stop requested")
    end
    
    -- Cleanup ESP and camera
    disableOverheadCamera()
    disablePlayerESP()
end

function MapRevealer.IsScanning() return State.Scanning end
function MapRevealer.IsCancelled() return State.Cancelled end
function MapRevealer.GetConfig() return CONFIG end

-- Legacy aliases (deprecated)
MapRevealer.RevealFullMap = MapRevealer.RevealSpiral
MapRevealer.RevealSmartClustered = MapRevealer.RevealSpiral

return MapRevealer
