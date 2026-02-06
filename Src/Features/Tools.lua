--[[
    Features/Tools.lua
    Free Camera & Spectator Mode
    
    v1.0 Features:
    - Free Camera: Detach camera, WASD+QE movement, mobile support
    - Spectator Mode: Follow other players, zoom control
    - Clean cleanup on disable
]]

local Tools = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

-- Local Player
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    -- Free Camera
    CamSpeed = 50,
    FastMultiplier = 2.5,
    Sensitivity = 0.15,
    
    -- Spectator
    MinDistance = 5,
    MaxDistance = 100,
    DefaultDistance = 20,
    OrbitSpeed = 0.5,
    
    -- NPC Detection
    NPCRadius = 200, -- studs
    NPCTypes = {"Wolf", "Deer", "Bear", "LostChild", "Bunny", "Fox", "Crow"}, -- common NPCs
}

-- ============================================
-- STATE
-- ============================================
local State = {
    -- Active mode
    ActiveMode = nil, -- "FreeCamera" | "Spectator" | nil
    
    -- Original camera settings (backup)
    Original = {
        CameraType = nil,
        CameraSubject = nil,
        CameraMaxZoomDistance = nil,
        CameraMinZoomDistance = nil,
    },
    
    -- Free Camera state
    FreeCam = {
        Position = nil,
        Rotation = nil, -- CFrame rotation only
        Velocity = Vector3.zero,
        AngularVelocity = Vector2.zero,
        IsFast = false,
    },
    
    -- Spectator state
    Spectator = {
        TargetType = "Players", -- "Self" | "Players" | "NPCs"
        TargetPlayer = nil,
        TargetNPC = nil,
        Distance = CONFIG.DefaultDistance,
        Angle = Vector2.new(0, math.rad(20)), -- Horizontal, Vertical
        NPCList = {}, -- cached nearby NPCs
    },
    
    -- Input state
    Input = {
        W = false, A = false, S = false, D = false,
        Q = false, E = false,
        MouseDelta = Vector2.zero,
        TouchDelta = Vector2.zero,
    },
    
    -- Mobile control states
    Anchored = false, -- Prevents character movement while orbiting
    GuiHidden = false, -- Hides mobile GUI for cleaner view
    
    -- Connections
    Connections = {},
    
    -- Mobile GUI
    MobileGui = nil,
}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function getCamera()
    return Workspace.CurrentCamera
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function backupCamera()
    local camera = getCamera()
    if camera then
        State.Original.CameraType = camera.CameraType
        State.Original.CameraSubject = camera.CameraSubject
    end
    
    if LocalPlayer then
        State.Original.CameraMaxZoomDistance = LocalPlayer.CameraMaxZoomDistance
        State.Original.CameraMinZoomDistance = LocalPlayer.CameraMinZoomDistance
    end
end

local function restoreCamera()
    local camera = getCamera()
    if camera then
        -- Restore subject first (important for StreamingEnabled)
        if State.Original.CameraSubject then
            camera.CameraSubject = State.Original.CameraSubject
        else
            local hum = getHumanoid()
            if hum then camera.CameraSubject = hum end
        end
        
        -- Small delay for streaming
        task.wait(0.1)
        
        -- Restore camera type
        camera.CameraType = State.Original.CameraType or Enum.CameraType.Custom
    end
    
    if LocalPlayer then
        LocalPlayer.CameraMaxZoomDistance = State.Original.CameraMaxZoomDistance or 400
        LocalPlayer.CameraMinZoomDistance = State.Original.CameraMinZoomDistance or 0.5
    end
end

local function disconnectAll()
    for _, conn in ipairs(State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    State.Connections = {}
end

local function resetInputState()
    State.Input.W = false
    State.Input.A = false
    State.Input.S = false
    State.Input.D = false
    State.Input.Q = false
    State.Input.E = false
    State.Input.MouseDelta = Vector2.zero
    State.Input.TouchDelta = Vector2.zero
    State.FreeCam.IsFast = false
end

local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Get Characters folder (NPCs)
local function getCharactersFolder()
    return Workspace:FindFirstChild("Characters") or Workspace:FindFirstChild("NPCs")
end

-- Scan NPCs in radius
local function getNPCsInRadius(radius)
    radius = radius or CONFIG.NPCRadius
    local npcs = {}
    local playerRoot = getRootPart()
    local playerPos = playerRoot and playerRoot.Position or Vector3.zero
    
    local charsFolder = getCharactersFolder()
    if not charsFolder then return npcs end
    
    for _, npc in ipairs(charsFolder:GetChildren()) do
        local npcRoot = npc:FindFirstChild("HumanoidRootPart")
        local npcHum = npc:FindFirstChildOfClass("Humanoid")
        
        if npcRoot and npcHum and npcHum.Health > 0 then
            local dist = (npcRoot.Position - playerPos).Magnitude
            if dist <= radius then
                table.insert(npcs, {
                    Model = npc,
                    Name = npc.Name,
                    Distance = dist,
                    Root = npcRoot,
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(npcs, function(a, b) return a.Distance < b.Distance end)
    
    return npcs
end

-- Get NPC names list for dropdown (includes distance for uniqueness)
local function getNPCNames()
    local npcs = getNPCsInRadius()
    local names = {}
    local nameCount = {}
    
    for i, npc in ipairs(npcs) do
        -- Count duplicates
        nameCount[npc.Name] = (nameCount[npc.Name] or 0) + 1
        local displayName
        if nameCount[npc.Name] > 1 then
            -- Add index for duplicates
            displayName = npc.Name .. " #" .. nameCount[npc.Name] .. " (" .. math.floor(npc.Distance) .. "m)"
        else
            displayName = npc.Name .. " (" .. math.floor(npc.Distance) .. "m)"
        end
        table.insert(names, displayName)
    end
    
    if #names == 0 then
        return {"(No NPCs nearby)"}
    end
    return names
end

-- Find NPC by display name (uses sorted list, picks closest matching)
local function getNPCByName(displayName)
    -- Parse display name: "Name #N (Xm)" or "Name (Xm)"
    local cleanName = displayName:match("^(.+) #%d+ %(%d+m%)$") or displayName:match("^(.+) %(%d+m%)$") or displayName
    local targetIndex = displayName:match("#(%d+)") and tonumber(displayName:match("#(%d+)")) or 1
    local targetDist = displayName:match("%((%d+)m%)") and tonumber(displayName:match("%((%d+)m%)")) or nil
    
    local npcs = getNPCsInRadius()
    local nameCount = {}
    
    for _, npc in ipairs(npcs) do
        nameCount[npc.Name] = (nameCount[npc.Name] or 0) + 1
        
        if npc.Name == cleanName then
            -- If we're looking for specific index
            if nameCount[npc.Name] == targetIndex then
                return npc.Model
            end
            -- Or match by distance if provided
            if targetDist and math.floor(npc.Distance) == targetDist then
                return npc.Model
            end
        end
    end
    
    -- Fallback: return first matching name (closest)
    for _, npc in ipairs(npcs) do
        if npc.Name == cleanName then
            return npc.Model
        end
    end
    
    return nil
end

-- ============================================
-- MOBILE GUI
-- ============================================
local function createMobileGui(mode)
    -- Cleanup existing
    if State.MobileGui then
        State.MobileGui:Destroy()
        State.MobileGui = nil
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "ToolsMobileGui"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer:FindFirstChild("PlayerGui")
    
    State.MobileGui = gui
    
    if mode == "FreeCamera" then
        -- Movement Joystick (Left side)
        local moveFrame = Instance.new("Frame")
        moveFrame.Name = "MoveJoystick"
        moveFrame.Size = UDim2.new(0, 150, 0, 150)
        moveFrame.Position = UDim2.new(0, 30, 1, -180)
        moveFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        moveFrame.BackgroundTransparency = 0.5
        moveFrame.Parent = gui
        
        local moveCorner = Instance.new("UICorner")
        moveCorner.CornerRadius = UDim.new(1, 0)
        moveCorner.Parent = moveFrame
        
        local moveStroke = Instance.new("UIStroke")
        moveStroke.Color = Color3.fromRGB(255, 255, 255)
        moveStroke.Thickness = 2
        moveStroke.Parent = moveFrame
        
        -- Joystick thumb
        local moveThumb = Instance.new("Frame")
        moveThumb.Name = "Thumb"
        moveThumb.Size = UDim2.new(0, 50, 0, 50)
        moveThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
        moveThumb.AnchorPoint = Vector2.new(0.5, 0.5)
        moveThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        moveThumb.Parent = moveFrame
        
        local thumbCorner = Instance.new("UICorner")
        thumbCorner.CornerRadius = UDim.new(1, 0)
        thumbCorner.Parent = moveThumb
        
        -- Joystick input handling
        local moveCenter = moveFrame.AbsolutePosition + moveFrame.AbsoluteSize / 2
        local maxRadius = 50
        
        moveFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                local touchPos = Vector2.new(input.Position.X, input.Position.Y)
                local delta = touchPos - moveCenter
                local magnitude = math.min(delta.Magnitude, maxRadius)
                local direction = delta.Magnitude > 0 and delta.Unit or Vector2.zero
                
                -- Update thumb position
                moveThumb.Position = UDim2.new(0.5, direction.X * magnitude, 0.5, direction.Y * magnitude)
                
                -- Convert to movement input
                State.Input.W = direction.Y < -0.3
                State.Input.S = direction.Y > 0.3
                State.Input.A = direction.X < -0.3
                State.Input.D = direction.X > 0.3
            end
        end)
        
        moveFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                moveCenter = moveFrame.AbsolutePosition + moveFrame.AbsoluteSize / 2
                local touchPos = Vector2.new(input.Position.X, input.Position.Y)
                local delta = touchPos - moveCenter
                local magnitude = math.min(delta.Magnitude, maxRadius)
                local direction = delta.Magnitude > 0 and delta.Unit or Vector2.zero
                
                moveThumb.Position = UDim2.new(0.5, direction.X * magnitude, 0.5, direction.Y * magnitude)
                
                State.Input.W = direction.Y < -0.3
                State.Input.S = direction.Y > 0.3
                State.Input.A = direction.X < -0.3
                State.Input.D = direction.X > 0.3
            end
        end)
        
        moveFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                moveThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
                State.Input.W = false
                State.Input.S = false
                State.Input.A = false
                State.Input.D = false
            end
        end)
        
        -- Up/Down Buttons (Right side)
        local upBtn = Instance.new("TextButton")
        upBtn.Name = "UpButton"
        upBtn.Size = UDim2.new(0, 80, 0, 60)
        upBtn.Position = UDim2.new(1, -100, 1, -180)
        upBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        upBtn.Text = "▲ UP"
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.TextSize = 18
        upBtn.Font = Enum.Font.GothamBold
        upBtn.Parent = gui
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0, 10)
        upCorner.Parent = upBtn
        
        upBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                State.Input.E = true
            end
        end)
        upBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                State.Input.E = false
            end
        end)
        
        local downBtn = Instance.new("TextButton")
        downBtn.Name = "DownButton"
        downBtn.Size = UDim2.new(0, 80, 0, 60)
        downBtn.Position = UDim2.new(1, -100, 1, -110)
        downBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        downBtn.Text = "▼ DOWN"
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.TextSize = 18
        downBtn.Font = Enum.Font.GothamBold
        downBtn.Parent = gui
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0, 10)
        downCorner.Parent = downBtn
        
        downBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                State.Input.Q = true
            end
        end)
        downBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                State.Input.Q = false
            end
        end)
        
        -- Speed Button
        local speedBtn = Instance.new("TextButton")
        speedBtn.Name = "SpeedButton"
        speedBtn.Size = UDim2.new(0, 80, 0, 40)
        speedBtn.Position = UDim2.new(1, -100, 1, -230)
        speedBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
        speedBtn.Text = "⚡ FAST"
        speedBtn.TextColor3 = Color3.new(1, 1, 1)
        speedBtn.TextSize = 16
        speedBtn.Font = Enum.Font.GothamBold
        speedBtn.Parent = gui
        
        local speedCorner = Instance.new("UICorner")
        speedCorner.CornerRadius = UDim.new(0, 10)
        speedCorner.Parent = speedBtn
        
        speedBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                State.FreeCam.IsFast = true
                speedBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 50)
            end
        end)
        speedBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                State.FreeCam.IsFast = false
                speedBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
            end
        end)
        
        -- =============================================
        -- ANCHOR BUTTON for FreeCamera (Stops character)
        -- =============================================
        local anchorBtn = Instance.new("TextButton")
        anchorBtn.Name = "AnchorButton"
        anchorBtn.Size = UDim2.new(0, 80, 0, 35)
        anchorBtn.Position = UDim2.new(0, 30, 0.5, -60)
        anchorBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        anchorBtn.Text = "ANCHOR"
        anchorBtn.TextColor3 = Color3.new(1, 1, 1)
        anchorBtn.TextSize = 12
        anchorBtn.Font = Enum.Font.GothamBold
        anchorBtn.Parent = gui
        
        local anchorCorner = Instance.new("UICorner")
        anchorCorner.CornerRadius = UDim.new(0, 8)
        anchorCorner.Parent = anchorBtn
        
        anchorBtn.MouseButton1Click:Connect(function()
            State.Anchored = not State.Anchored
            if State.Anchored then
                anchorBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                anchorBtn.Text = "LOCKED"
                local char = LocalPlayer.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.Anchored = true
                    end
                end
            else
                anchorBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                anchorBtn.Text = "ANCHOR"
                local char = LocalPlayer.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.Anchored = false
                    end
                end
            end
        end)
        
        -- =============================================
        -- HIDE GUI BUTTON for FreeCamera
        -- =============================================
        local hideBtn = Instance.new("TextButton")
        hideBtn.Name = "HideButton"
        hideBtn.Size = UDim2.new(0, 80, 0, 30)
        hideBtn.Position = UDim2.new(0, 30, 0.5, -100)
        hideBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        hideBtn.Text = "HIDE"
        hideBtn.TextColor3 = Color3.new(1, 1, 1)
        hideBtn.TextSize = 12
        hideBtn.Font = Enum.Font.GothamBold
        hideBtn.Parent = gui
        hideBtn.ZIndex = 100
        
        local hideCorner = Instance.new("UICorner")
        hideCorner.CornerRadius = UDim.new(0, 8)
        hideCorner.Parent = hideBtn
        
        hideBtn.MouseButton1Click:Connect(function()
            State.GuiHidden = not State.GuiHidden
            for _, child in ipairs(gui:GetChildren()) do
                if child.Name ~= "HideButton" then
                    child.Visible = not State.GuiHidden
                end
            end
            hideBtn.Text = State.GuiHidden and "SHOW" or "HIDE"
            hideBtn.BackgroundTransparency = State.GuiHidden and 0.5 or 0
        end)
        
    elseif mode == "Spectator" then
        -- Zoom In/Out buttons
        local zoomInBtn = Instance.new("TextButton")
        zoomInBtn.Name = "ZoomIn"
        zoomInBtn.Size = UDim2.new(0, 50, 0, 35)
        zoomInBtn.Position = UDim2.new(1, -65, 0.5, -40)
        zoomInBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        zoomInBtn.Text = "+"
        zoomInBtn.TextColor3 = Color3.new(1, 1, 1)
        zoomInBtn.TextSize = 22
        zoomInBtn.Font = Enum.Font.GothamBold
        zoomInBtn.Parent = gui
        
        local zoomInCorner = Instance.new("UICorner")
        zoomInCorner.CornerRadius = UDim.new(0, 10)
        zoomInCorner.Parent = zoomInBtn
        
        zoomInBtn.MouseButton1Click:Connect(function()
            State.Spectator.Distance = math.max(CONFIG.MinDistance, State.Spectator.Distance - 5)
        end)
        
        local zoomOutBtn = Instance.new("TextButton")
        zoomOutBtn.Name = "ZoomOut"
        zoomOutBtn.Size = UDim2.new(0, 50, 0, 35)
        zoomOutBtn.Position = UDim2.new(1, -65, 0.5, 0)
        zoomOutBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        zoomOutBtn.Text = "-"
        zoomOutBtn.TextColor3 = Color3.new(1, 1, 1)
        zoomOutBtn.TextSize = 22
        zoomOutBtn.Font = Enum.Font.GothamBold
        zoomOutBtn.Parent = gui
        
        local zoomOutCorner = Instance.new("UICorner")
        zoomOutCorner.CornerRadius = UDim.new(0, 10)
        zoomOutCorner.Parent = zoomOutBtn
        
        zoomOutBtn.MouseButton1Click:Connect(function()
            State.Spectator.Distance = math.min(CONFIG.MaxDistance, State.Spectator.Distance + 5)
        end)
        
        -- Distance Label
        local distLabel = Instance.new("TextLabel")
        distLabel.Name = "DistanceLabel"
        distLabel.Size = UDim2.new(0, 50, 0, 20)
        distLabel.Position = UDim2.new(1, -65, 0.5, 40)
        distLabel.BackgroundTransparency = 1
        distLabel.Text = tostring(State.Spectator.Distance) .. " studs"
        distLabel.TextColor3 = Color3.new(1, 1, 1)
        distLabel.TextSize = 10
        distLabel.Font = Enum.Font.Gotham
        distLabel.Parent = gui
        
        -- Update distance label
        local updateConn = RunService.Heartbeat:Connect(function()
            if distLabel and distLabel.Parent then
                distLabel.Text = math.floor(State.Spectator.Distance) .. " studs"
            end
        end)
        table.insert(State.Connections, updateConn)
        
        -- =============================================
        -- ORBIT JOYSTICK (Left side for mobile)
        -- =============================================
        local orbitFrame = Instance.new("Frame")
        orbitFrame.Name = "OrbitJoystick"
        orbitFrame.Size = UDim2.new(0, 120, 0, 120)
        orbitFrame.Position = UDim2.new(0, 30, 1, -150)
        orbitFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        orbitFrame.BackgroundTransparency = 0.5
        orbitFrame.Parent = gui
        
        local orbitCorner = Instance.new("UICorner")
        orbitCorner.CornerRadius = UDim.new(1, 0)
        orbitCorner.Parent = orbitFrame
        
        local orbitStroke = Instance.new("UIStroke")
        orbitStroke.Color = Color3.fromRGB(100, 200, 255)
        orbitStroke.Thickness = 2
        orbitStroke.Parent = orbitFrame
        
        -- Label
        local orbitLabel = Instance.new("TextLabel")
        orbitLabel.Size = UDim2.new(1, 0, 0, 20)
        orbitLabel.Position = UDim2.new(0, 0, 0, -25)
        orbitLabel.BackgroundTransparency = 1
        orbitLabel.Text = "ORBIT"
        orbitLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        orbitLabel.TextSize = 14
        orbitLabel.Font = Enum.Font.GothamBold
        orbitLabel.Parent = orbitFrame
        
        -- Joystick thumb
        local orbitThumb = Instance.new("Frame")
        orbitThumb.Name = "Thumb"
        orbitThumb.Size = UDim2.new(0, 40, 0, 40)
        orbitThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
        orbitThumb.AnchorPoint = Vector2.new(0.5, 0.5)
        orbitThumb.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
        orbitThumb.Parent = orbitFrame
        
        local thumbCorner = Instance.new("UICorner")
        thumbCorner.CornerRadius = UDim.new(1, 0)
        thumbCorner.Parent = orbitThumb
        
        -- Orbit joystick touch handling
        local orbitTouching = false
        local orbitStartPos = nil
        
        orbitFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                orbitTouching = true
                orbitStartPos = Vector2.new(input.Position.X, input.Position.Y)
            end
        end)
        
        orbitFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and orbitTouching then
                local frameCenter = orbitFrame.AbsolutePosition + orbitFrame.AbsoluteSize / 2
                local touchPos = Vector2.new(input.Position.X, input.Position.Y)
                local delta = touchPos - frameCenter
                local maxRadius = 40
                
                -- Clamp thumb position
                local magnitude = math.min(delta.Magnitude, maxRadius)
                local direction = delta.Magnitude > 0 and delta.Unit or Vector2.zero
                orbitThumb.Position = UDim2.new(0.5, direction.X * magnitude, 0.5, direction.Y * magnitude)
                
                -- Apply orbit rotation
                local orbitSpeed = 0.03
                State.Spectator.Angle = Vector2.new(
                    State.Spectator.Angle.X - direction.X * orbitSpeed,
                    math.clamp(State.Spectator.Angle.Y + direction.Y * orbitSpeed, -math.rad(80), math.rad(80))
                )
            end
        end)
        
        orbitFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                orbitTouching = false
                orbitThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
            end
        end)
        
        -- =============================================
        -- ANCHOR BUTTON (Stops character movement)
        -- =============================================
        local anchorBtn = Instance.new("TextButton")
        anchorBtn.Name = "AnchorButton"
        anchorBtn.Size = UDim2.new(0, 50, 0, 28)
        anchorBtn.Position = UDim2.new(1, -65, 0.5, -75)
        anchorBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        anchorBtn.Text = "ANCHOR"
        anchorBtn.TextColor3 = Color3.new(1, 1, 1)
        anchorBtn.TextSize = 9
        anchorBtn.Font = Enum.Font.GothamBold
        anchorBtn.Parent = gui
        
        local anchorCorner = Instance.new("UICorner")
        anchorCorner.CornerRadius = UDim.new(0, 8)
        anchorCorner.Parent = anchorBtn
        
        anchorBtn.MouseButton1Click:Connect(function()
            State.Anchored = not State.Anchored
            if State.Anchored then
                anchorBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                anchorBtn.Text = "LOCKED"
                local char = LocalPlayer.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.Anchored = true
                    end
                end
            else
                anchorBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                anchorBtn.Text = "ANCHOR"
                local char = LocalPlayer.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.Anchored = false
                    end
                end
            end
        end)
        
        -- =============================================
        -- HIDE GUI BUTTON (Toggle visibility)
        -- =============================================
        local hideBtn = Instance.new("TextButton")
        hideBtn.Name = "HideButton"
        hideBtn.Size = UDim2.new(0, 50, 0, 25)
        hideBtn.Position = UDim2.new(1, -65, 0.5, -105)
        hideBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        hideBtn.Text = "HIDE"
        hideBtn.TextColor3 = Color3.new(1, 1, 1)
        hideBtn.TextSize = 9
        hideBtn.Font = Enum.Font.GothamBold
        hideBtn.Parent = gui
        hideBtn.ZIndex = 100
        
        local hideCorner = Instance.new("UICorner")
        hideCorner.CornerRadius = UDim.new(0, 8)
        hideCorner.Parent = hideBtn
        
        hideBtn.MouseButton1Click:Connect(function()
            State.GuiHidden = not State.GuiHidden
            for _, child in ipairs(gui:GetChildren()) do
                if child.Name ~= "HideButton" then
                    child.Visible = not State.GuiHidden
                end
            end
            hideBtn.Text = State.GuiHidden and "SHOW" or "HIDE"
            hideBtn.BackgroundTransparency = State.GuiHidden and 0.5 or 0
        end)
    end
    
    return gui
end

local function destroyMobileGui()
    -- Unanchor character if it was anchored
    if State.Anchored then
        State.Anchored = false
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                root.Anchored = false
            end
        end
    end
    
    -- Reset GUI hidden state
    State.GuiHidden = false
    
    if State.MobileGui then
        State.MobileGui:Destroy()
        State.MobileGui = nil
    end
end

-- ============================================
-- FREE CAMERA
-- ============================================
local FreeCamera = {}

function FreeCamera.Start()
    if State.ActiveMode then
        Tools.StopAll()
    end
    
    local camera = getCamera()
    if not camera then return end
    
    -- Backup original settings
    backupCamera()
    
    -- Initialize free cam state
    State.FreeCam.Position = camera.CFrame.Position
    State.FreeCam.Rotation = camera.CFrame - camera.CFrame.Position
    
    -- Set camera to scriptable
    camera.CameraType = Enum.CameraType.Scriptable
    
    State.ActiveMode = "FreeCamera"
    resetInputState()
    
    -- Create mobile GUI if needed
    if isMobile() then
        createMobileGui("FreeCamera")
    end
    
    -- Input handling for PC
    local inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.W then State.Input.W = true end
        if input.KeyCode == Enum.KeyCode.A then State.Input.A = true end
        if input.KeyCode == Enum.KeyCode.S then State.Input.S = true end
        if input.KeyCode == Enum.KeyCode.D then State.Input.D = true end
        if input.KeyCode == Enum.KeyCode.Q then State.Input.Q = true end
        if input.KeyCode == Enum.KeyCode.E then State.Input.E = true end
        if input.KeyCode == Enum.KeyCode.LeftShift then State.FreeCam.IsFast = true end
    end)
    table.insert(State.Connections, inputBeganConn)
    
    local inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.W then State.Input.W = false end
        if input.KeyCode == Enum.KeyCode.A then State.Input.A = false end
        if input.KeyCode == Enum.KeyCode.S then State.Input.S = false end
        if input.KeyCode == Enum.KeyCode.D then State.Input.D = false end
        if input.KeyCode == Enum.KeyCode.Q then State.Input.Q = false end
        if input.KeyCode == Enum.KeyCode.E then State.Input.E = false end
        if input.KeyCode == Enum.KeyCode.LeftShift then State.FreeCam.IsFast = false end
    end)
    table.insert(State.Connections, inputEndedConn)
    
    -- Mouse movement (hold right click to rotate)
    local mouseConn = UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                State.Input.MouseDelta = Vector2.new(input.Delta.X, input.Delta.Y)
            else
                State.Input.MouseDelta = Vector2.zero
            end
        end
        
        -- Touch rotation (swipe on right side of screen)
        if input.UserInputType == Enum.UserInputType.Touch then
            local screenWidth = camera.ViewportSize.X
            if input.Position.X > screenWidth * 0.5 then
                State.Input.TouchDelta = Vector2.new(input.Delta.X, input.Delta.Y)
            end
        end
    end)
    table.insert(State.Connections, mouseConn)
    
    -- Main update loop
    local updateConn = RunService.RenderStepped:Connect(function(dt)
        if State.ActiveMode ~= "FreeCamera" then return end
        
        local camera = getCamera()
        if not camera then return end
        
        -- Calculate movement direction
        local moveDir = Vector3.zero
        local currentCFrame = CFrame.new(State.FreeCam.Position) * State.FreeCam.Rotation
        
        local forward = currentCFrame.LookVector
        local right = currentCFrame.RightVector
        local up = Vector3.new(0, 1, 0)
        
        if State.Input.W then moveDir = moveDir + forward end
        if State.Input.S then moveDir = moveDir - forward end
        if State.Input.D then moveDir = moveDir + right end
        if State.Input.A then moveDir = moveDir - right end
        if State.Input.E then moveDir = moveDir + up end
        if State.Input.Q then moveDir = moveDir - up end
        
        -- Normalize and apply speed
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end
        
        local speed = CONFIG.CamSpeed
        if State.FreeCam.IsFast then
            speed = speed * CONFIG.FastMultiplier
        end
        
        State.FreeCam.Position = State.FreeCam.Position + moveDir * speed * dt
        
        -- Apply rotation from mouse/touch
        local rotDelta = State.Input.MouseDelta + State.Input.TouchDelta
        if rotDelta.Magnitude > 0 then
            local yaw = -rotDelta.X * CONFIG.Sensitivity * dt * 10
            local pitch = -rotDelta.Y * CONFIG.Sensitivity * dt * 10
            
            local x, y, z = State.FreeCam.Rotation:ToEulerAnglesYXZ()
            local newPitch = math.clamp(x + pitch, -math.rad(89), math.rad(89))
            local newYaw = y + yaw
            
            State.FreeCam.Rotation = CFrame.fromEulerAnglesYXZ(newPitch, newYaw, 0)
        end
        
        -- Reset deltas
        State.Input.MouseDelta = Vector2.zero
        State.Input.TouchDelta = Vector2.zero
        
        -- Apply to camera
        camera.CFrame = CFrame.new(State.FreeCam.Position) * State.FreeCam.Rotation
    end)
    table.insert(State.Connections, updateConn)
    
    print("[Tools] Free Camera: Enabled")
end

function FreeCamera.Stop()
    if State.ActiveMode ~= "FreeCamera" then return end
    
    disconnectAll()
    destroyMobileGui()
    resetInputState()
    restoreCamera()
    
    State.ActiveMode = nil
    print("[Tools] Free Camera: Disabled")
end

-- ============================================
-- SPECTATOR MODE
-- ============================================
local SpectatorMode = {}

-- Get target root part based on current target type
local function getSpectatorTargetRoot()
    local targetType = State.Spectator.TargetType
    
    if targetType == "Self" then
        return getRootPart()
    elseif targetType == "Players" then
        local target = State.Spectator.TargetPlayer
        if target and target.Character then
            return target.Character:FindFirstChild("HumanoidRootPart")
        end
    elseif targetType == "NPCs" then
        local npc = State.Spectator.TargetNPC
        if npc and npc.Parent then
            return npc:FindFirstChild("HumanoidRootPart")
        end
    end
    
    return nil
end

-- Check if target is still valid
local function isTargetValid()
    local targetType = State.Spectator.TargetType
    print("[Tools][DEBUG] isTargetValid called, targetType:", targetType)
    
    if targetType == "Self" then
        local char = getCharacter()
        local valid = char ~= nil
        print("[Tools][DEBUG] - Self mode, character:", char and char.Name or "nil", "valid:", valid)
        return valid
    elseif targetType == "Players" then
        local target = State.Spectator.TargetPlayer
        local valid = target and target.Parent and target.Character
        print("[Tools][DEBUG] - Players mode")
        print("[Tools][DEBUG] - target:", target and target.Name or "nil")
        print("[Tools][DEBUG] - target.Parent:", target and target.Parent and "exists" or "nil")
        print("[Tools][DEBUG] - target.Character:", target and target.Character and "exists" or "nil")
        print("[Tools][DEBUG] - valid:", valid and true or false)
        return valid
    elseif targetType == "NPCs" then
        local npc = State.Spectator.TargetNPC
        print("[Tools][DEBUG] - NPCs mode, npc:", npc and npc.Name or "nil")
        if npc and npc.Parent then
            local hum = npc:FindFirstChildOfClass("Humanoid")
            local valid = hum and hum.Health > 0
            print("[Tools][DEBUG] - npc.Parent:", npc.Parent and "exists" or "nil")
            print("[Tools][DEBUG] - Humanoid:", hum and ("HP=" .. hum.Health) or "nil")
            print("[Tools][DEBUG] - valid:", valid and true or false)
            return valid
        end
        print("[Tools][DEBUG] - NPC or Parent is nil")
    else
        print("[Tools][DEBUG] - Unknown targetType:", targetType)
    end
    
    print("[Tools][DEBUG] - Returning FALSE")
    return false
end

function SpectatorMode.Start(targetType, target)
    print("[Tools][DEBUG] SpectatorMode.Start called")
    print("[Tools][DEBUG] - targetType:", targetType)
    print("[Tools][DEBUG] - target:", target and (target.Name or tostring(target)) or "nil")
    
    if State.ActiveMode then
        print("[Tools][DEBUG] - Stopping previous mode:", State.ActiveMode)
        Tools.StopAll()
    end
    
    targetType = targetType or "Players"
    State.Spectator.TargetType = targetType
    print("[Tools][DEBUG] - TargetType set to:", targetType)
    
    -- Validate and set target based on type
    if targetType == "Self" then
        local char = getCharacter()
        print("[Tools][DEBUG] - Self mode, character:", char and char.Name or "nil")
        if not char then
            warn("[Tools] Spectator: No character found")
            return
        end
        State.Spectator.TargetPlayer = nil
        State.Spectator.TargetNPC = nil
        
    elseif targetType == "Players" then
        print("[Tools][DEBUG] - Players mode")
        print("[Tools][DEBUG] - target:", target and target.Name or "nil")
        print("[Tools][DEBUG] - LocalPlayer:", LocalPlayer and LocalPlayer.Name or "nil")
        print("[Tools][DEBUG] - target == LocalPlayer:", target == LocalPlayer)
        if not target or target == LocalPlayer then
            warn("[Tools] Spectator: Invalid player target")
            return
        end
        print("[Tools][DEBUG] - target.Character:", target.Character and "exists" or "nil")
        State.Spectator.TargetPlayer = target
        State.Spectator.TargetNPC = nil
        
    elseif targetType == "NPCs" then
        print("[Tools][DEBUG] - NPCs mode, target:", target and target.Name or "nil")
        if not target then
            warn("[Tools] Spectator: Invalid NPC target")
            return
        end
        local npcRoot = target:FindFirstChild("HumanoidRootPart")
        local npcHum = target:FindFirstChildOfClass("Humanoid")
        print("[Tools][DEBUG] - NPC HumanoidRootPart:", npcRoot and "exists" or "nil")
        print("[Tools][DEBUG] - NPC Humanoid:", npcHum and ("exists, HP=" .. npcHum.Health) or "nil")
        State.Spectator.TargetNPC = target
        State.Spectator.TargetPlayer = nil
    else
        warn("[Tools] Spectator: Unknown targetType:", targetType)
        return
    end
    
    local camera = getCamera()
    print("[Tools][DEBUG] - Camera:", camera and "exists" or "nil")
    if not camera then return end
    
    -- Backup original settings
    backupCamera()
    print("[Tools][DEBUG] - Camera backed up")
    
    State.Spectator.Distance = CONFIG.DefaultDistance
    State.Spectator.Angle = Vector2.new(0, math.rad(20))
    
    State.ActiveMode = "Spectator"
    print("[Tools][DEBUG] - ActiveMode set to: Spectator")
    
    -- Set camera to scriptable for orbit control
    camera.CameraType = Enum.CameraType.Scriptable
    
    -- Create mobile GUI
    if isMobile() then
        createMobileGui("Spectator")
    end
    
    -- Mouse/Touch input for orbit
    local inputConn = UserInputService.InputChanged:Connect(function(input, gameProcessed)
        -- Skip if not in spectator mode
        if State.ActiveMode ~= "Spectator" then return end
        
        -- PC: Right-click drag to orbit
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                local deltaX = input.Delta.X * CONFIG.OrbitSpeed * 0.01
                local deltaY = input.Delta.Y * CONFIG.OrbitSpeed * 0.01
                State.Spectator.Angle = Vector2.new(
                    State.Spectator.Angle.X - deltaX,
                    math.clamp(State.Spectator.Angle.Y + deltaY, -math.rad(80), math.rad(80))
                )
                print("[Tools][DEBUG] Orbit: deltaX=" .. string.format("%.2f", deltaX) .. " deltaY=" .. string.format("%.2f", deltaY))
            end
        end
        
        -- Mobile: Touch swipe to orbit (middle 40% of screen)
        if input.UserInputType == Enum.UserInputType.Touch then
            local cam = getCamera()
            if cam then
                local screenWidth = cam.ViewportSize.X
                if input.Position.X > screenWidth * 0.3 and input.Position.X < screenWidth * 0.7 then
                    local deltaX = input.Delta.X * CONFIG.OrbitSpeed * 0.02
                    local deltaY = input.Delta.Y * CONFIG.OrbitSpeed * 0.02
                    State.Spectator.Angle = Vector2.new(
                        State.Spectator.Angle.X - deltaX,
                        math.clamp(State.Spectator.Angle.Y + deltaY, -math.rad(80), math.rad(80))
                    )
                end
            end
        end
        
        -- PC: Scroll wheel for zoom
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            State.Spectator.Distance = math.clamp(
                State.Spectator.Distance - input.Position.Z * 5,
                CONFIG.MinDistance,
                CONFIG.MaxDistance
            )
        end
    end)
    table.insert(State.Connections, inputConn)
    
    -- Grace period for target loading
    local startTime = tick()
    local gracePeriod = 2
    
    -- Main update loop
    local updateConn = RunService.RenderStepped:Connect(function(dt)
        if State.ActiveMode ~= "Spectator" then return end
        
        local targetRoot = getSpectatorTargetRoot()
        
        -- If no target root, check if we should stop or just skip frame
        if not targetRoot then
            if tick() - startTime < gracePeriod then
                return
            end
            
            if not isTargetValid() then
                SpectatorMode.Stop()
                return
            end
            return
        end
        
        local camera = getCamera()
        if not camera then return end
        
        -- Calculate orbit position
        local distance = State.Spectator.Distance
        local hAngle = State.Spectator.Angle.X
        local vAngle = State.Spectator.Angle.Y
        
        local offset = CFrame.new(0, 0, distance)
        local rotation = CFrame.fromEulerAnglesYXZ(vAngle, hAngle, 0)
        
        local targetPos = targetRoot.Position + Vector3.new(0, 2, 0) -- Slightly above
        local camPos = targetPos + (rotation * offset).Position
        
        camera.CFrame = CFrame.lookAt(camPos, targetPos)
    end)
    table.insert(State.Connections, updateConn)
    
    -- Player leaving connection (only for Players mode)
    if targetType == "Players" then
        local leaveConn = Players.PlayerRemoving:Connect(function(player)
            if player == State.Spectator.TargetPlayer then
                SpectatorMode.Stop()
            end
        end)
        table.insert(State.Connections, leaveConn)
    end
    
    local targetName = targetType == "Self" and "Self" or (target and target.Name or "Unknown")
    print("[Tools] Spectator: Following " .. targetName .. " (" .. targetType .. ")")
end
function SpectatorMode.Stop()
    if State.ActiveMode ~= "Spectator" then return end
    
    disconnectAll()
    destroyMobileGui()
    restoreCamera()
    
    State.Spectator.TargetPlayer = nil
    State.Spectator.TargetNPC = nil
    State.ActiveMode = nil
    print("[Tools] Spectator: Disabled")
end

function SpectatorMode.SetDistance(distance)
    State.Spectator.Distance = math.clamp(distance, CONFIG.MinDistance, CONFIG.MaxDistance)
end

function SpectatorMode.GetDistance()
    return State.Spectator.Distance
end

function SpectatorMode.NextPlayer()
    if State.Spectator.TargetType ~= "Players" then return nil end
    
    local players = Players:GetPlayers()
    local currentIdx = 1
    
    -- Find current target index
    for i, p in ipairs(players) do
        if p == State.Spectator.TargetPlayer then
            currentIdx = i
            break
        end
    end
    
    -- Find next valid player (not local)
    for i = 1, #players do
        local nextIdx = ((currentIdx + i - 1) % #players) + 1
        local nextPlayer = players[nextIdx]
        if nextPlayer ~= LocalPlayer and nextPlayer.Character then
            SpectatorMode.Start("Players", nextPlayer)
            return nextPlayer
        end
    end
    
    return nil
end

function SpectatorMode.PrevPlayer()
    if State.Spectator.TargetType ~= "Players" then return nil end
    
    local players = Players:GetPlayers()
    local currentIdx = 1
    
    for i, p in ipairs(players) do
        if p == State.Spectator.TargetPlayer then
            currentIdx = i
            break
        end
    end
    
    for i = 1, #players do
        local prevIdx = ((currentIdx - i - 1) % #players) + 1
        if prevIdx <= 0 then prevIdx = #players end
        local prevPlayer = players[prevIdx]
        if prevPlayer ~= LocalPlayer and prevPlayer.Character then
            SpectatorMode.Start("Players", prevPlayer)
            return prevPlayer
        end
    end
    
    return nil
end

-- NPC Next/Prev
function SpectatorMode.NextNPC()
    if State.Spectator.TargetType ~= "NPCs" then return nil end
    
    local npcs = getNPCsInRadius()
    if #npcs == 0 then return nil end
    
    local currentIdx = 1
    local currentNPC = State.Spectator.TargetNPC
    
    for i, npc in ipairs(npcs) do
        if npc.Model == currentNPC then
            currentIdx = i
            break
        end
    end
    
    local nextIdx = (currentIdx % #npcs) + 1
    local nextNPC = npcs[nextIdx]
    if nextNPC then
        SpectatorMode.Start("NPCs", nextNPC.Model)
        return nextNPC.Model
    end
    
    return nil
end

function SpectatorMode.PrevNPC()
    if State.Spectator.TargetType ~= "NPCs" then return nil end
    
    local npcs = getNPCsInRadius()
    if #npcs == 0 then return nil end
    
    local currentIdx = 1
    local currentNPC = State.Spectator.TargetNPC
    
    for i, npc in ipairs(npcs) do
        if npc.Model == currentNPC then
            currentIdx = i
            break
        end
    end
    
    local prevIdx = ((currentIdx - 2) % #npcs) + 1
    local prevNPC = npcs[prevIdx]
    if prevNPC then
        SpectatorMode.Start("NPCs", prevNPC.Model)
        return prevNPC.Model
    end
    
    return nil
end

-- ============================================
-- PUBLIC API
-- ============================================
function Tools.Init()
    print("[Tools] Initialized")
end

function Tools.StartFreeCamera()
    FreeCamera.Start()
end

function Tools.StopFreeCamera()
    FreeCamera.Stop()
end

function Tools.ToggleFreeCamera(enabled)
    if enabled then
        FreeCamera.Start()
    else
        FreeCamera.Stop()
    end
end

-- Spectator API (updated for targetType)
function Tools.StartSpectator(targetType, target)
    SpectatorMode.Start(targetType, target)
end

function Tools.StartSpectatorSelf()
    SpectatorMode.Start("Self", nil)
end

function Tools.StartSpectatorPlayer(player)
    SpectatorMode.Start("Players", player)
end

function Tools.StartSpectatorNPC(npc)
    SpectatorMode.Start("NPCs", npc)
end

function Tools.StopSpectator()
    SpectatorMode.Stop()
end

function Tools.ToggleSpectator(enabled, targetType, target)
    if enabled then
        SpectatorMode.Start(targetType or "Players", target)
    else
        SpectatorMode.Stop()
    end
end

function Tools.SetSpectatorDistance(distance)
    SpectatorMode.SetDistance(distance)
end

function Tools.GetSpectatorDistance()
    return SpectatorMode.GetDistance()
end

function Tools.NextSpectatorTarget()
    local targetType = State.Spectator.TargetType
    if targetType == "Players" then
        return SpectatorMode.NextPlayer()
    elseif targetType == "NPCs" then
        return SpectatorMode.NextNPC()
    end
    return nil
end

function Tools.PrevSpectatorTarget()
    local targetType = State.Spectator.TargetType
    if targetType == "Players" then
        return SpectatorMode.PrevPlayer()
    elseif targetType == "NPCs" then
        return SpectatorMode.PrevNPC()
    end
    return nil
end

function Tools.GetCurrentSpectatorTarget()
    local targetType = State.Spectator.TargetType
    if targetType == "Self" then
        return getCharacter()
    elseif targetType == "Players" then
        return State.Spectator.TargetPlayer
    elseif targetType == "NPCs" then
        return State.Spectator.TargetNPC
    end
    return nil
end

function Tools.GetSpectatorTargetType()
    return State.Spectator.TargetType
end

function Tools.GetOtherPlayers()
    local others = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(others, player)
        end
    end
    return others
end

function Tools.GetPlayerNames()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(names, player.Name)
        end
    end
    return names
end

function Tools.GetPlayerByName(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name == name then
            return player
        end
    end
    return nil
end

-- NPC API
function Tools.GetNPCsNearby(radius)
    return getNPCsInRadius(radius)
end

function Tools.GetNPCNames(radius)
    return getNPCNames(radius)
end

function Tools.GetNPCByName(name)
    return getNPCByName(name)
end

function Tools.RefreshNPCList()
    State.Spectator.NPCList = getNPCsInRadius()
    return State.Spectator.NPCList
end

function Tools.IsActive()
    return State.ActiveMode ~= nil
end

function Tools.GetActiveMode()
    return State.ActiveMode
end

function Tools.StopAll()
    if State.ActiveMode == "FreeCamera" then
        FreeCamera.Stop()
    elseif State.ActiveMode == "Spectator" then
        SpectatorMode.Stop()
    end
end

function Tools.SetCameraSpeed(speed)
    CONFIG.CamSpeed = math.clamp(speed, 10, 200)
end

function Tools.GetConfig()
    return CONFIG
end

-- Cleanup for script unload
function Tools.Cleanup()
    Tools.StopAll()
    disconnectAll()
    destroyMobileGui()
    restoreCamera()
    print("[Tools] Cleanup complete")
end

-- Alias
Tools.Stop = Tools.StopAll

return Tools
