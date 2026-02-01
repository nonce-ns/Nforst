--[[
    Mobile Fly Module for TheForge
    Touch controls for mobile flying
    
    Usage: Loaded by main.lua via loadstring
]]

local Fly = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Config
local Config = {
    Enabled = false,
    FlySpeed = 25,
    CarpetOffset = -3.5,
    ContainerSize = Vector2.new(230, 310),
    ButtonSize = Vector2.new(60, 60),
    ContainerPadding = 16,
}

local DefaultFlySpeed = 25

-- State
local State = {
    IsFlying = false,
    MoveDirection = Vector3.zero,
    ActiveButtons = {},
}

local UI = {
    ScreenGui = nil,
    Container = nil,
    Buttons = {},
    Connections = {},
    SpeedLabel = nil,
}

-- Physics objects
local MagicCarpet = nil
local BodyGyro = nil
local BodyPos = nil
local FlyConnection = nil
local NoClipConnection = nil
local CharacterPartsCache = {}
local CachedCharRef = nil

local WindUI = nil

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function safeCall(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[Fly] " .. label .. " error: " .. tostring(err))
    end
    return ok
end

local function notify(title, content, duration)
    if WindUI and WindUI.Notify then
        safeCall("Notify", function()
            WindUI:Notify({Title = title, Content = content, Duration = duration or 3})
        end)
    else
        warn("[Fly] " .. tostring(title) .. ": " .. tostring(content))
    end
end

local function getCharacter()
    local living = Workspace:FindFirstChild("Living")
    if living then
        return living:FindFirstChild(LocalPlayer.Name)
    end
    return LocalPlayer.Character
end

local function getRoot(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ============================================
-- MOVE DIRECTION
-- ============================================

local function updateMoveDirection()
    local sum = Vector3.zero
    for _, dir in pairs(State.ActiveButtons) do
        sum = sum + dir
    end
    State.MoveDirection = sum
end

-- ============================================
-- MAGIC CARPET
-- ============================================

local function createMagicCarpet()
    if MagicCarpet then return end
    MagicCarpet = Instance.new("Part")
    MagicCarpet.Name = "FlyCarpet"
    MagicCarpet.Size = Vector3.new(0.06, 0.06, 0.06)
    MagicCarpet.Transparency = 1
    MagicCarpet.Anchored = false
    MagicCarpet.CanCollide = false
    MagicCarpet.CanTouch = false
    MagicCarpet.CanQuery = false
    MagicCarpet.Parent = Workspace
end

local function updateMagicCarpet(rootPart)
    if not MagicCarpet or not rootPart or not rootPart.Parent then return end
    local newCFrame = rootPart.CFrame * CFrame.new(0, Config.CarpetOffset, 0)
    MagicCarpet.CFrame = newCFrame
end

local function destroyMagicCarpet()
    if MagicCarpet then
        MagicCarpet:Destroy()
        MagicCarpet = nil
    end
end

-- ============================================
-- UI FUNCTIONS
-- ============================================

local function disconnectUIConnections()
    for _, conn in ipairs(UI.Connections) do
        conn:Disconnect()
    end
    if table.clear then
        table.clear(UI.Connections)
    else
        UI.Connections = {}
    end
end

local function setButtonState(btn, isPressed)
    if isPressed then
        btn.BackgroundColor3 = Color3.fromRGB(105, 140, 255)
        btn.TextColor3 = Color3.fromRGB(20, 25, 40)
    else
        btn.BackgroundColor3 = Color3.fromRGB(63, 75, 110)
        btn.TextColor3 = Color3.fromRGB(230, 235, 245)
    end
end

local function onButtonPress(btn, dir)
    State.ActiveButtons[btn] = dir
    setButtonState(btn, true)
    updateMoveDirection()
end

local function onButtonRelease(btn)
    if State.ActiveButtons[btn] then
        State.ActiveButtons[btn] = nil
        setButtonState(btn, false)
        updateMoveDirection()
    end
end

local function attachButtonHandlers(btn, dir)
    table.insert(UI.Connections, btn.InputBegan:Connect(function(input)
        local isPress = input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        if isPress then
            onButtonPress(btn, dir)
        end
    end))

    table.insert(UI.Connections, btn.InputEnded:Connect(function(input)
        local isRelease = input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        if isRelease then
            onButtonRelease(btn)
        end
    end))
end

local function updateSpeedLabel()
    if UI.SpeedLabel then
        UI.SpeedLabel.Text = string.format("Speed: %d", Config.FlySpeed)
    end
end

local function createButton(parent, data)
    local btn = Instance.new("TextButton")
    btn.Name = data.name
    btn.Size = UDim2.new(0, Config.ButtonSize.X, 0, Config.ButtonSize.Y)
    btn.Position = data.position
    btn.BackgroundColor3 = Color3.fromRGB(63, 75, 110)
    btn.Text = data.label
    btn.TextColor3 = Color3.fromRGB(230, 235, 245)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamSemibold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    attachButtonHandlers(btn, data.direction)
    setButtonState(btn, false)

    UI.Buttons[data.name] = btn
end

local function createFlyUI()
    if UI.ScreenGui then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FlyControlUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, Config.ContainerSize.X, 0, Config.ContainerSize.Y)
    container.Position = UDim2.new(0, Config.ContainerPadding, 1, -Config.ContainerSize.Y - Config.ContainerPadding)
    container.BackgroundColor3 = Color3.fromRGB(24, 26, 35)
    container.BackgroundTransparency = 0.15
    container.BorderSizePixel = 0
    container.Parent = gui

    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 14)
    containerCorner.Parent = container

    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Size = UDim2.new(1, -20, 0, 30)
    header.Position = UDim2.new(0, 10, 0, 10)
    header.BackgroundTransparency = 1
    header.Text = "Fly Controls"
    header.TextColor3 = Color3.fromRGB(230, 235, 245)
    header.TextSize = 18
    header.Font = Enum.Font.GothamBold
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = container

    -- Enable dragging
    local dragging = false
    local dragOffset = Vector2.zero

    table.insert(UI.Connections, header.InputBegan:Connect(function(input)
        local isPress = input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        if isPress then
            dragging = true
            dragOffset = Vector2.new(input.Position.X, input.Position.Y)
                - Vector2.new(container.AbsolutePosition.X, container.AbsolutePosition.Y)
        end
    end))

    table.insert(UI.Connections, header.InputEnded:Connect(function(input)
        local isRelease = input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        if isRelease then
            dragging = false
        end
    end))

    table.insert(UI.Connections, UserInputService.InputChanged:Connect(function(input)
        local isDrag = input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseMovement
        if dragging and isDrag then
            local camera = Workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
            local newX = math.clamp(input.Position.X - dragOffset.X, 0, viewport.X - Config.ContainerSize.X)
            local newY = math.clamp(input.Position.Y - dragOffset.Y, 0, viewport.Y - Config.ContainerSize.Y)
            container.Position = UDim2.new(0, newX, 0, newY)
        end
    end))

    local buttonArea = Instance.new("Frame")
    buttonArea.Name = "ButtonArea"
    buttonArea.Size = UDim2.new(1, -20, 0, 230)
    buttonArea.Position = UDim2.new(0, 10, 0, 50)
    buttonArea.BackgroundTransparency = 1
    buttonArea.Parent = container

    local buttons = {
        {name = "Up", label = "Up", position = UDim2.new(0.5, -Config.ButtonSize.X / 2, 0, 0), direction = Vector3.new(0, 1, 0)},
        {name = "Forward", label = "Forward", position = UDim2.new(0.5, -Config.ButtonSize.X / 2, 0, 55), direction = Vector3.new(0, 0, -1)},
        {name = "Left", label = "Left", position = UDim2.new(0, 0, 0, 55), direction = Vector3.new(-1, 0, 0)},
        {name = "Right", label = "Right", position = UDim2.new(1, -Config.ButtonSize.X, 0, 55), direction = Vector3.new(1, 0, 0)},
        {name = "Backward", label = "Back", position = UDim2.new(0.5, -Config.ButtonSize.X / 2, 0, 110), direction = Vector3.new(0, 0, 1)},
        {name = "Down", label = "Down", position = UDim2.new(0.5, -Config.ButtonSize.X / 2, 0, 165), direction = Vector3.new(0, -1, 0)},
    }

    for _, data in ipairs(buttons) do
        createButton(buttonArea, data)
    end

    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "SpeedLabel"
    speedLabel.Size = UDim2.new(1, -20, 0, 20)
    speedLabel.Position = UDim2.new(0, 10, 1, -26)
    speedLabel.BackgroundTransparency = 1
    speedLabel.TextColor3 = Color3.fromRGB(180, 185, 200)
    speedLabel.TextSize = 14
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.Parent = container

    UI.ScreenGui = gui
    UI.Container = container
    UI.SpeedLabel = speedLabel

    updateSpeedLabel()
end

local function destroyFlyUI()
    disconnectUIConnections()
    UI.Buttons = {}
    UI.Container = nil
    UI.SpeedLabel = nil
    if UI.ScreenGui then
        UI.ScreenGui:Destroy()
        UI.ScreenGui = nil
    end
    State.ActiveButtons = {}
    State.MoveDirection = Vector3.zero
end

-- ============================================
-- FLY SYSTEM
-- ============================================

local function stopFlying()
    State.IsFlying = false
    State.MoveDirection = Vector3.zero
    State.ActiveButtons = {}

    -- Disconnect connections first
    if FlyConnection then
        pcall(function() FlyConnection:Disconnect() end)
        FlyConnection = nil
    end

    if NoClipConnection then
        pcall(function() NoClipConnection:Disconnect() end)
        NoClipConnection = nil
    end

    -- Cleanup character
    local char = getCharacter()
    if char then
        local root = getRoot(char)
        local hum = char:FindFirstChild("Humanoid")

        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            
            -- Remove BodyGyro and BodyPosition by name from root
            for _, child in pairs(root:GetChildren()) do
                if child.Name == "FlyBodyGyro" or child.Name == "FlyBodyPosition" then
                    pcall(function() child:Destroy() end)
                end
            end
        end

        if hum then
            hum.PlatformStand = false
        end

        -- Restore CanCollide ONLY for Head and Torso (game default!)
        -- Arms and Legs should stay CanCollide = false
        local collisionParts = {"Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
        for _, partName in pairs(collisionParts) do
            local part = char:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                pcall(function() part.CanCollide = true end)
            end
        end
    end

    -- Destroy physics objects (fallback)
    if BodyGyro then
        pcall(function() BodyGyro:Destroy() end)
        BodyGyro = nil
    end
    
    if BodyPos then
        pcall(function() BodyPos:Destroy() end)
        BodyPos = nil
    end
    
    -- Clear cache
    CharacterPartsCache = {}
    CachedCharRef = nil

    -- Cleanup FlyCarpet from Workspace
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name == "FlyCarpet" then
            pcall(function() obj:Destroy() end)
        end
    end
    MagicCarpet = nil

    destroyFlyUI()
end

local function startFlying()
    if State.IsFlying then return end

    local char = getCharacter()
    local root = getRoot(char)
    local hum = char and char:FindFirstChild("Humanoid")

    if not root or not hum then
        notify("Fly Error", "Character not found", 2)
        return
    end

    State.IsFlying = true
    State.MoveDirection = Vector3.zero
    State.ActiveButtons = {}

    createFlyUI()
    createMagicCarpet()

    hum.PlatformStand = true

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.Name = "FlyBodyGyro"
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = 50000
    BodyGyro.D = 1000
    BodyGyro.CFrame = root.CFrame
    BodyGyro.Parent = root

    BodyPos = Instance.new("BodyPosition")
    BodyPos.Name = "FlyBodyPosition"
    BodyPos.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    BodyPos.P = 50000
    BodyPos.D = 1000
    BodyPos.Position = root.Position
    BodyPos.Parent = root

    NoClipConnection = RunService.Heartbeat:Connect(function()
        if not State.IsFlying then return end
        local chr = getCharacter()
        if not chr then return end
        
        if chr ~= CachedCharRef then
            CachedCharRef = chr
            CharacterPartsCache = {}
            for _, part in pairs(chr:GetDescendants()) do
                if part:IsA("BasePart") then
                    CharacterPartsCache[#CharacterPartsCache + 1] = part
                end
            end
        end
        
        for _, part in ipairs(CharacterPartsCache) do
            if part.Parent and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)

    FlyConnection = RunService.Heartbeat:Connect(function(dt)
        if not State.IsFlying then return end

        local chr = getCharacter()
        local rt = getRoot(chr)
        if not rt then return end

        local camera = Workspace.CurrentCamera
        local camCF = (camera and camera.CFrame) or CFrame.new()
        local moveDir = State.MoveDirection

        local newPosition = rt.Position
        if moveDir.Magnitude > 0 then
            local camLook = camCF.LookVector
            local camRight = camCF.RightVector
            local planarLook = Vector3.new(camLook.X, 0, camLook.Z)
            if planarLook.Magnitude < 1e-3 then
                planarLook = Vector3.new(0, 0, -1)
            else
                planarLook = planarLook.Unit
            end
            local planarRight = Vector3.new(camRight.X, 0, camRight.Z)
            if planarRight.Magnitude < 1e-3 then
                planarRight = Vector3.new(1, 0, 0)
            else
                planarRight = planarRight.Unit
            end

            local vertical = Vector3.new(0, moveDir.Y, 0)
            local horizontal = planarLook * -moveDir.Z + planarRight * moveDir.X
            local worldMove = horizontal + vertical

            if worldMove.Magnitude > 0 then
                newPosition = rt.Position + worldMove.Unit * Config.FlySpeed * dt
            end
        end

        local _, yaw = camCF:ToOrientation()
        rt.CFrame = CFrame.new(newPosition) * CFrame.Angles(0, yaw, 0)

        if BodyGyro then
            BodyGyro.CFrame = rt.CFrame
        end
        
        if BodyPos then
            BodyPos.Position = newPosition
        end

        updateMagicCarpet(rt)

        rt.AssemblyLinearVelocity = Vector3.zero
        rt.AssemblyAngularVelocity = Vector3.zero
    end)

    notify("Fly Mode", "Mobile controls enabled", 2)
end

-- ============================================
-- MODULE API
-- ============================================

function Fly:Init()
    print("[Fly] Module initialized")
end

function Fly:SetWindUI(ui)
    WindUI = ui
end

function Fly:Toggle(enabled)
    Config.Enabled = enabled
    if enabled then
        startFlying()
    else
        stopFlying()
    end
end

function Fly:SetSpeed(speed)
    Config.FlySpeed = speed
    updateSpeedLabel()
end

function Fly:Cleanup()
    stopFlying()
    Config.Enabled = false
end

function Fly:Reset()
    stopFlying()
    Config.FlySpeed = DefaultFlySpeed
    Config.Enabled = false
end

function Fly:Destroy()
    stopFlying()
    Config.Enabled = false
    
    -- Clear all references
    WindUI = nil
    CharacterPartsCache = {}
    CachedCharRef = nil
    
    print("[Fly] Module destroyed")
end

return Fly
