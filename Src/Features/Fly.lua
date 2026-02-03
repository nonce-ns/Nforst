--[[
    Features/Fly.lua
    Universal Fly System (PC & Mobile Support)
    - Uses BodyVelocity for smooth movement
    - Uses BodyGyro for stability
    - Uses Humanoid.MoveDirection for cross-platform control
    - Includes Camera Aim Assist + Mobile Buttons
    - Includes NoClip
]]

local Fly = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

-- Configuration
local CONFIG = {
    Speed = 60,
    VerticalMult = 0.8,
}

-- State
local State = {
    IsFlying = false,
    Connections = {},
    PartsCache = {},
    VerticalInput = 0, -- -1 (Down), 0 (Neutral), 1 (Up)
}

-- Event for UI Sync
Fly.StateChanged = Instance.new("BindableEvent")

-- Cleanup BodyMovers
local function clearMovers(root)
    if not root then return end
    for _, child in pairs(root:GetChildren()) do
        if child.Name == "FlyBodyGyro" or child.Name == "FlyBodyVelocity" then
            child:Destroy()
        end
    end
end

-- Refresh Parts Cache for NoClip
local function refreshPartsCache(char)
    State.PartsCache = {}
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                table.insert(State.PartsCache, part)
            end
        end
    end
end

-- Mobile/PC Input Handler
local function handleVertical(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        if actionName == "FlyUp" then
            State.VerticalInput = 1
        elseif actionName == "FlyDown" then
            State.VerticalInput = -1
        end
    elseif inputState == Enum.UserInputState.End then
        State.VerticalInput = 0
    end
    return Enum.ContextActionResult.Pass
end

function Fly.Start()
    if State.IsFlying then return end
    
    local player = Players.LocalPlayer
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    if not root or not hum then return end
    
    State.IsFlying = true
    hum.PlatformStand = true -- Disable gravity/physics
    refreshPartsCache(char)
    
    -- Movers
    local bg = Instance.new("BodyGyro")
    bg.Name = "FlyBodyGyro"
    bg.P = 9e4
    bg.D = 100
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.CFrame = root.CFrame
    bg.Parent = root
    
    local bv = Instance.new("BodyVelocity")
    bv.Name = "FlyBodyVelocity"
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = root
    
    -- Bind Actions (Mobile Buttons + PC Keys)
    -- "FlyUp" -> Jump Button (Mobile) / Space (PC)
    ContextActionService:BindAction("FlyUp", handleVertical, true, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
    ContextActionService:SetTitle("FlyUp", "Up")
    ContextActionService:SetPosition("FlyUp", UDim2.new(0.7, 0, 0.5, 0))

    -- "FlyDown" -> Ctrl (PC) / ButtonX (Mobile - Optional addition)
    -- On Mobile, we usually add a button. Let's bind "LeftControl" for PC.
    ContextActionService:BindAction("FlyDown", handleVertical, true, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
    ContextActionService:SetTitle("FlyDown", "Down")
    ContextActionService:SetPosition("FlyDown", UDim2.new(0.6, 0, 0.6, 0))

    -- Main Loop
    local flyConn = RunService.Heartbeat:Connect(function()
        if not root.Parent or not hum.Parent then
            Fly.Stop()
            return
        end
        
        -- Current Camera
        local cam = Workspace.CurrentCamera
        local moveDir = hum.MoveDirection -- World Space direction
        local lookVec = cam.CFrame.LookVector
        
        -- Calculate Target Velocity
        local targetVel = moveDir * CONFIG.Speed
        
        -- Vertical Movement Logic
        local vSpeed = 0
        
        -- Priority: Explicit Input > Camera Aim
        if State.VerticalInput ~= 0 then
            vSpeed = State.VerticalInput * CONFIG.Speed * CONFIG.VerticalMult
        elseif moveDir.Magnitude > 0 then
            -- Optional: "Camera Aim Assist" only if no explicit button held
            -- Reduced sensitivity (30 degrees) to prevent accidental dives
            local pitch = math.asin(math.clamp(lookVec.Y, -1, 1))
            if math.abs(pitch) > math.rad(30) then
                vSpeed = lookVec.Y * CONFIG.Speed
            end
        end
        
        targetVel = Vector3.new(targetVel.X, targetVel.Y + vSpeed, targetVel.Z)
        
        -- Apply
        bv.Velocity = targetVel
        bg.CFrame = cam.CFrame 
        
        -- NoClip (Simple Loop - Optimized to cache only collidables)
        for _, part in ipairs(State.PartsCache) do
            if part.Parent and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
    
    table.insert(State.Connections, flyConn)
    
    -- Death Monitor
    local diedConn = hum.Died:Connect(function()
        Fly.Stop()
    end)
    table.insert(State.Connections, diedConn)
    
    -- Notify UI
    Fly.StateChanged:Fire(true)
    print("[Fly] Enabled")
end

function Fly.Stop()
    if not State.IsFlying then return end
    State.IsFlying = false
    
    -- Unbind Actions
    ContextActionService:UnbindAction("FlyUp")
    ContextActionService:UnbindAction("FlyDown")
    State.VerticalInput = 0
    
    -- Disconnect
    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    State.Connections = {}
    State.PartsCache = {}
    
    local player = Players.LocalPlayer
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    
    if root then clearMovers(root) end
    if hum then hum.PlatformStand = false end
    
    -- Restore Collision (Safe Mode)
    if char then
         local restore = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso", "LeftLeg", "RightLeg", "LeftArm", "RightArm"}
         for _, name in pairs(restore) do
             local p = char:FindFirstChild(name)
             if p then p.CanCollide = true end
         end
    end
    
    -- Notify UI
    Fly.StateChanged:Fire(false)
    print("[Fly] Disabled")
end

function Fly.Toggle(val)
    if val then Fly.Start() else Fly.Stop() end
end

function Fly.SetSpeed(val)
    CONFIG.Speed = tonumber(val) or 60
end

function Fly.Init()
    print("[Fly] Initialized")
end

function Fly.Cleanup()
    Fly.Stop()
    Fly.StateChanged:Destroy()
end

return Fly
