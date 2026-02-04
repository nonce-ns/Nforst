--[[
    Features/ChestExplorer.lua
    Features:
    - Auto Scan Chests/Crates
    - Stable Fly Mode (MapRevealer Style) to prevent falling/stuck
    - Instant Teleport for speed
    - Return to Start Position
]]

local ChestExplorer = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Constants
local REMOTE_NAME = "RequestOpenItemChest"
local CHEST_PATTERNS = {"Chest", "Crate", "Box", "Safe", "Container"} 
local INTERACTION_DELAY = 0.5 
local OPEN_DELAY = 0.5

-- State
local State = {
    IsRunning = false,
    OpenedChests = {}, 
    TotalOpened = 0,
    TotalFound = 0,
    CurrentThread = nil,
    OriginalPosition = nil,
}

local FlyState = {
    IsFlying = false,
    BodyGyro = nil,
    BodyPos = nil, -- Used for stabilization
    FlyConnection = nil,
    NoClipConnection = nil,
    CharacterPartsCache = {},
    CachedCharRef = nil,
}

local Remote = nil

-- ============================================
-- FLY SYSTEM (Stabilizer Mode)
-- ============================================

local function startFly(character, rootPart, humanoid)
    if FlyState.IsFlying or not rootPart or not humanoid then return end
    
    FlyState.IsFlying = true
    humanoid.PlatformStand = true 
    
    -- BodyGyro for rotation stability
    local bg = Instance.new("BodyGyro")
    bg.Name = "ChestExpBodyGyro"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 50000
    bg.D = 1000
    bg.CFrame = rootPart.CFrame
    bg.Parent = rootPart
    FlyState.BodyGyro = bg
    
    -- BodyPosition to HOLD position in air (Anti-Gravity)
    local bp = Instance.new("BodyPosition")
    bp.Name = "ChestExpBodyPosition"
    bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bp.P = 50000
    bp.D = 1000
    bp.Position = rootPart.Position -- Hold current pos
    bp.Parent = rootPart
    FlyState.BodyPos = bp
    
    -- NoClip Loop
    FlyState.NoClipConnection = RunService.Heartbeat:Connect(function()
        if not FlyState.IsFlying or not character or not character.Parent then return end
        
        -- Cache parts
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
    
    -- Orientation Loop
    FlyState.FlyConnection = RunService.Heartbeat:Connect(function()
        if not FlyState.IsFlying or not rootPart or not rootPart.Parent then return end
        if FlyState.BodyGyro then
            FlyState.BodyGyro.CFrame = CFrame.new(rootPart.Position) -- Keep upright
        end
        -- Ensure BodyPos matches current position if we teleported
        -- Wait, if we use BP for holding, we must update BP when we teleport!
    end)
    
    print("[ChestExplorer] Fly Stabilizer: STARTED")
end

local function stopFly(character, rootPart, humanoid)
    if not FlyState.IsFlying then return end
    
    FlyState.IsFlying = false
    
    -- Disconnect
    if FlyState.FlyConnection then pcall(function() FlyState.FlyConnection:Disconnect() end) end
    if FlyState.NoClipConnection then pcall(function() FlyState.NoClipConnection:Disconnect() end) end
    FlyState.FlyConnection = nil
    FlyState.NoClipConnection = nil
    
    -- Cleanup Movers
    if rootPart then
        for _, child in pairs(rootPart:GetChildren()) do
            if child.Name:match("^ChestExpBody") then
                child:Destroy()
            end
        end
        rootPart.AssemblyLinearVelocity = Vector3.zero
    end
    
    -- Reset Physics
    if humanoid then humanoid.PlatformStand = false end
    
    -- Restore Collision (SAFE MODE: Only body parts)
    if character then
        -- Restore key body parts only to avoid accessories causing fling/stuck
        local restoreList = {"Head", "UpperTorso", "LowerTorso", "Torso", "LeftLeg", "RightLeg", "LeftArm", "RightArm", "HumanoidRootPart"}
        for _, name in pairs(restoreList) do
            local part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        -- Also check R15 limbs generally if needed, but the above covers R6/R15 main parts
    end
    
    FlyState.CachedCharRef = nil
    print("[ChestExplorer] Fly Stabilizer: STOPPED")
end

-- Monitor Character Death
local function monitorCharacter(char)
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if State.IsRunning then
                warn("[ChestExplorer] Character died! Emergency Stop.")
                ChestExplorer.Stop()
            end
        end)
    end
end

-- ============================================
-- MAIN LOGIC
-- ============================================

local function isChest(item)
    if not item or not item:IsA("Model") then return false end
    local name = item.Name:lower()
    for _, pattern in ipairs(CHEST_PATTERNS) do
        if name:find(pattern:lower()) then return true end
    end
    return false
end

function ChestExplorer.ScanChests()
    local chests = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if itemsFolder then
        for _, item in ipairs(itemsFolder:GetChildren()) do
            if isChest(item) and not State.OpenedChests[item] then
                table.insert(chests, item)
            end
        end
    end
    State.TotalFound = #chests
    return chests
end

local function safeTeleport(targetPos)
    local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    print("[ChestExplorer] Teleporting to: " .. tostring(targetPos))
    
    -- 1. Update BodyPosition target FIRST so it catches us upon arrival
    if FlyState.BodyPos then
        FlyState.BodyPos.Position = targetPos
    end
    
    -- 2. Teleport Character
    root.CFrame = CFrame.new(targetPos)
    
    -- 3. Kill velocity
    root.AssemblyLinearVelocity = Vector3.zero
end

local function openChest(chest)
    if not chest or not chest.Parent then return false end
    
    print("[ChestExplorer] Targeting: " .. chest.Name)
    local chestPos = chest:GetPivot()
    if not chestPos then return false end
    
    -- Target: 5 studs ABOVE chest (safe hovering)
    local targetPos = chestPos.Position + Vector3.new(0, 5, 0)
    
    -- Instant Teleport (with Fly active to hold us there)
    safeTeleport(targetPos)
    
    if not State.IsRunning then return false end
    
    -- Interact
    print("[ChestExplorer] Opening...")
    task.wait(INTERACTION_DELAY)
    
    if Remote then
        Remote:FireServer(chest)
    end
    
    State.OpenedChests[chest] = true
    State.TotalOpened = State.TotalOpened + 1
    
    task.wait(OPEN_DELAY)
    return true
end

function ChestExplorer.StartOpenAll(callback)
    if State.IsRunning then return end
    State.IsRunning = true
    State.TotalOpened = 0
    
    -- Setup Character
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    if not root or not hum then
        warn("[ChestExplorer] Character not found!")
        State.IsRunning = false
        return
    end
    
    -- Monitor Death
    monitorCharacter(char)
    
    -- Record Start Position
    State.OriginalPosition = root.Position
    print("[ChestExplorer] Recorded Start Pos: " .. tostring(State.OriginalPosition))
    
    -- Enable Fly Stabilizer
    startFly(char, root, hum)
    
    State.CurrentThread = task.spawn(function()
        local chests = ChestExplorer.ScanChests()
        if callback then callback("Found " .. #chests .. " chests...") end
        print("[ChestExplorer] Opening " .. #chests .. " chests")
        
        for i, chest in ipairs(chests) do
            if not State.IsRunning then break end
            
            if chest.Parent then
                if callback then 
                    callback("Run: " .. i .. "/" .. #chests .. " | " .. chest.Name) 
                end
                openChest(chest)
            end
        end
        
        ChestExplorer.Stop() -- Trigger return logic
    end)
end

function ChestExplorer.Stop()
    local wasRunning = State.IsRunning
    State.IsRunning = false
    
    if State.CurrentThread then
        task.cancel(State.CurrentThread)
        State.CurrentThread = nil
    end
    
    -- Return to Start Position
    if wasRunning and State.OriginalPosition then
        local char = Players.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        -- Check if dead
        local hum = char and char:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 then
            print("[ChestExplorer] Returning to start position...")
            if FlyState.IsFlying then
                safeTeleport(State.OriginalPosition)
                task.wait(0.5) -- Wait a bit to stabilize before dropping
            end
        end
    end
    
    -- Stop Fly
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    stopFly(char, root, hum)
    
    print("[ChestExplorer] Stopped/Finished")
end

-- Clean cleanup for reloads
function ChestExplorer.Cleanup()
    ChestExplorer.Stop()
    State.OpenedChests = {}
    print("[ChestExplorer] Cleaned up resources")
end

function ChestExplorer.Init(deps)
    local events = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if events then
        Remote = events:FindFirstChild(REMOTE_NAME)
    end
    print("[ChestExplorer] Initialized (Teleport + Fly Mode)")
end

return ChestExplorer
