--[[
    Features/AutoPlant.lua
    Auto Plant Sapling with Circle Pattern
    
    EXPLOIT: Uses nil instances to reuse same sapling infinitely
    - Pick 1 sapling → Plant 100+ times
    - Circle pattern around player/center
]]

local AutoPlant = {}

-- Dependencies
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Utils = nil
local Remote = nil

-- Settings (configurable via UI)
local Settings = {
    Pattern = "Circle",    -- Circle, Square, Triangle, Heart, Star, Spiral
    Radius = 20,           -- Circle radius (5-1000)
    Spacing = 1,           -- Distance between plants (0.1-10)
    PlantDelay = 0.05,     -- Delay between each plant (0.01-0.2)
    Height = 2,            -- Y position for planting (-5 to 50)
    UsePlayerCenter = true, -- Use player position as center
    UseCampfireCenter = false, -- Use nearest campfire as center
    CustomCenter = Vector3.new(0, 2, 0), -- Custom center (campfire position)
    ShowPreview = false,   -- Show visual preview of planting area
}

-- State
local State = {
    Enabled = false,
    Thread = nil,
    CurrentSapling = nil,
    CurrentDebugId = nil,
    PlantCount = 0,
    PreviewFolder = nil,   -- Folder for preview parts
    PreviewEnabled = false,
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Get item from nil instances by name and debugId
local function GetNil(Name, DebugId)
    if not getnilinstances then return nil end
    
    for _, Object in ipairs(getnilinstances()) do
        if Object.Name == Name then
            local success, objDebugId = pcall(function()
                return Object:GetDebugId()
            end)
            if success and objDebugId == DebugId then
                return Object
            end
        end
    end
    return nil
end

-- Find sapling in workspace.Items
local function findSaplingInWorkspace()
    local items = Workspace:FindFirstChild("Items")
    if not items then return nil end
    
    for _, item in ipairs(items:GetChildren()) do
        if item.Name == "Sapling" then
            return item
        end
    end
    return nil
end

-- Find nearest campfire (prioritizes MainFire.Center)
local function findNearestCampfire()
    -- Priority 1: Check exact known path (Campground MainFire)
    local map = Workspace:FindFirstChild("Map")
    if map then
        local campground = map:FindFirstChild("Campground")
        if campground then
            local mainFire = campground:FindFirstChild("MainFire")
            if mainFire then
                local center = mainFire:FindFirstChild("Center")
                if center and center:IsA("BasePart") then
                    return center.Position
                end
                -- Fallback to MainFire itself
                if mainFire:IsA("BasePart") then
                    return mainFire.Position
                elseif mainFire:IsA("Model") then
                    local primary = mainFire.PrimaryPart or mainFire:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        return primary.Position
                    end
                end
            end
        end
    end
    
    -- Priority 2: Search for any campfire/fire nearby
    local root = Utils and Utils.getRoot()
    if not root then return nil end
    
    local playerPos = root.Position
    local nearest = nil
    local nearestDist = math.huge
    
    -- Search in workspace for campfire/fire
    local function searchFolder(folder)
        for _, obj in ipairs(folder:GetChildren()) do
            local name = obj.Name:lower()
            if name:find("campfire") or name:find("mainfire") or name:find("firepit") or name:find("fire") then
                local pos = nil
                -- Check for Center child first
                local center = obj:FindFirstChild("Center")
                if center and center:IsA("BasePart") then
                    pos = center.Position
                elseif obj:IsA("BasePart") then
                    pos = obj.Position
                elseif obj:IsA("Model") then
                    local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        pos = primary.Position
                    end
                end
                
                if pos then
                    local dist = (pos - playerPos).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = pos
                    end
                end
            end
        end
    end
    
    -- Search common locations
    if map then
        searchFolder(map)
        local campground = map:FindFirstChild("Campground")
        if campground then searchFolder(campground) end
        local structures = map:FindFirstChild("Structures")
        if structures then searchFolder(structures) end
    end
    
    local items = Workspace:FindFirstChild("Items")
    if items then searchFolder(items) end
    
    return nearest
end

-- Get sapling (from nil instances or workspace)
local function getSapling()
    -- Try to get from nil instances first (reuse)
    if State.CurrentDebugId then
        local nilSapling = GetNil("Sapling", State.CurrentDebugId)
        if nilSapling then
            return nilSapling
        end
    end
    
    -- Otherwise find new one in workspace
    local sapling = findSaplingInWorkspace()
    if sapling then
        local success, debugId = pcall(function()
            return sapling:GetDebugId()
        end)
        if success then
            State.CurrentDebugId = debugId
            State.CurrentSapling = sapling
        end
        return sapling
    end
    
    return nil
end

-- Generate positions based on pattern
local function generatePositions(center, radius, spacing, height, pattern)
    local positions = {}
    pattern = pattern or "Circle"
    
    -- Helper to add point if valid
    local function addPos(pos)
        table.insert(positions, Vector3.new(pos.X, height, pos.Z))
    end
    
    -- LINEAR INTERPOLATION (for straight line shapes)
    local function drawLine(p1, p2)
        local dist = (p1 - p2).Magnitude
        local steps = math.floor(dist / spacing)
        if steps < 1 then steps = 1 end
        
        for i = 0, steps - 1 do -- -1 to avoid double planting corners
            local t = i / steps
            addPos(p1:Lerp(p2, t))
        end
    end

    if pattern == "Circle" then
        local circumference = 2 * math.pi * radius
        local numPoints = math.floor(circumference / spacing)
        if numPoints < 1 then numPoints = 1 end
        
        for i = 0, numPoints - 1 do
            local angle = (i / numPoints) * 2 * math.pi
            local x = center.X + radius * math.cos(angle)
            local z = center.Z + radius * math.sin(angle)
            addPos(Vector3.new(x, 0, z))
        end

    elseif pattern == "Square" then
        -- 4 Corners
        local r = radius
        local c1 = center + Vector3.new(r, 0, r)
        local c2 = center + Vector3.new(-r, 0, r)
        local c3 = center + Vector3.new(-r, 0, -r)
        local c4 = center + Vector3.new(r, 0, -r)
        
        drawLine(c1, c2)
        drawLine(c2, c3)
        drawLine(c3, c4)
        drawLine(c4, c1)

    elseif pattern == "Triangle" then
        -- 3 Corners (Equilateral)
        local p1 = center + Vector3.new(0, 0, -radius) -- Top
        local p2 = center + Vector3.new(radius * 0.866, 0, radius * 0.5) -- Bottom Right
        local p3 = center + Vector3.new(-radius * 0.866, 0, radius * 0.5) -- Bottom Left
        
        drawLine(p1, p2)
        drawLine(p2, p3)
        drawLine(p3, p1)

    elseif pattern == "Star" then
        -- 5 Point Star (Pentagram style)
        local points = 5
        local innerRadius = radius * 0.4 -- Star depth
        local vertices = {}
        
        for i = 0, (points * 2) - 1 do
            local angle = (i / (points * 2)) * 2 * math.pi - (math.pi/2) -- Start from top
            local r = (i % 2 == 0) and radius or innerRadius
            local x = center.X + r * math.cos(angle)
            local z = center.Z + r * math.sin(angle)
            table.insert(vertices, Vector3.new(x, 0, z))
        end
        
        for i = 1, #vertices do
            local nextIdx = (i % #vertices) + 1
            drawLine(vertices[i], vertices[nextIdx])
        end

    elseif pattern == "Heart" then
        -- Parametric Heart Equation
        -- x = 16sin^3(t)
        -- y = 13cos(t) - 5cos(2t) - 2cos(3t) - cos(4t)
        -- Scaled to radius
        local scale = radius / 16
        local circumferenceEst = 2 * math.pi * radius -- Rough estimate
        local numPoints = math.floor(circumferenceEst / spacing)
        
        for i = 0, numPoints do
            local t = (i / numPoints) * 2 * math.pi
            local xOffset = 16 * math.pow(math.sin(t), 3)
            local zOffset = -(13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)) -- Inverted Z for correct orientation
            
            local x = center.X + (xOffset * scale)
            local z = center.Z + (zOffset * scale)
            addPos(Vector3.new(x, 0, z))
        end

    elseif pattern == "Spiral" then
        -- Archimedean Spiral: r = a + b*angle
        local coils = 3
        local maxAngle = coils * 2 * math.pi
        local totalLength = 0.5 * maxAngle * radius -- Approx length
        local numPoints = math.floor(totalLength / spacing * 2) -- More density for spiral
        
        for i = 0, numPoints do
            local t = i / numPoints
            local angle = t * maxAngle
            local currentRadius = t * radius
            
            local x = center.X + currentRadius * math.cos(angle)
            local z = center.Z + currentRadius * math.sin(angle)
            addPos(Vector3.new(x, 0, z))
        end
    end
    
    return positions
end

-- Plant at position
local function plantAt(sapling, position)
    if not sapling then return false end
    if not Remote then return false end
    
    local success, result = pcall(function()
        return Remote.RequestPlantItem(sapling, position)
    end)
    
    return success
end

-- ============================================
-- VISUAL PREVIEW SYSTEM (Live Update & Pooled)
-- ============================================
local PreviewPool = {} -- Part pool to prevent FPS drops
local PreviewConnection = nil -- Connection handle for cleanup

local function clearPreview()
    -- Fully destroy folders and parts to ensure NO memory leak
    if State.PreviewFolder then
        pcall(function() State.PreviewFolder:Destroy() end)
        State.PreviewFolder = nil
    end
    
    -- Also clear the pool
    for i, part in pairs(PreviewPool) do
        pcall(function() part:Destroy() end)
        PreviewPool[i] = nil
    end
    table.clear(PreviewPool)
    
    State.PreviewEnabled = false
end

local function createPreviewPart(position, size, color, transparency)
    local part = Instance.new("Part")
    part.Name = "PlantPreview"
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.Size = size or Vector3.new(0.5, 0.5, 0.5)
    part.Position = position
    part.Color = color or Color3.fromRGB(0, 255, 100) -- Green
    part.Transparency = transparency or 0.5
    part.Material = Enum.Material.Neon
    part.Parent = State.PreviewFolder
    return part
end

local function updatePreview()
    if not Settings.ShowPreview then
        if State.PreviewFolder then clearPreview() end
        return
    end

    local center
    if Settings.UseCampfireCenter then
        local pos = findNearestCampfire()
        if pos then center = pos end
    end
    if not center and Settings.UsePlayerCenter then
        local root = Utils and Utils.getRoot()
        if root then center = root.Position end
    end
    if not center then center = Settings.CustomCenter end
    
    local radius = Settings.Radius
    local spacing = Settings.Spacing
    local height = Settings.Height
    
    -- Generate positions using shared logic
    local positions = generatePositions(center, Settings.Radius, Settings.Spacing, Settings.Height, Settings.Pattern)
    local numPoints = #positions
    
    -- Cap to 500 parts for performance safety
    if numPoints > 500 then 
        numPoints = 500 
        -- truncate positions? No, just render first 500 is safer or let it be. 
        -- Actually, let's just properly limit the loop.
    end
    
    -- Ensure folder exists
    if not State.PreviewFolder then
        State.PreviewFolder = Instance.new("Folder")
        State.PreviewFolder.Name = "AutoPlantPreview"
        State.PreviewFolder.Parent = Workspace
    end
    
    -- 1. Center Marker (Index 1)
    if not PreviewPool[1] then
        PreviewPool[1] = createPreviewPart(center, Vector3.new(0.3, 2, 0.3), Color3.fromRGB(255, 0, 0), 0.5)
    end
    PreviewPool[1].Position = Vector3.new(center.X, height + 1, center.Z)
    PreviewPool[1].Parent = State.PreviewFolder
    
    -- 2. Plant Markers (Index 2 to numPoints+1)
    for i = 1, numPoints do
        local poolIndex = i + 1
        local pos = positions[i]
        
        -- Override height for preview to be slightly above ground? No, follow logic.
        -- Logic says pos.Y is height. Preview usually likes to be explicit.
        -- pos is Vector3(x, height, z) from generatesPositions
        
        local part = PreviewPool[poolIndex]
        if not part then
            part = createPreviewPart(pos, Vector3.new(0.1, 0.4, 0.1), Color3.fromRGB(0, 255, 100), 0.2)
            PreviewPool[poolIndex] = part
        end
        
        part.Position = pos
        part.Parent = State.PreviewFolder
    end
    
    -- 3. Hide/Cleanup unused parts from pool
    for i = numPoints + 2, #PreviewPool do
        if PreviewPool[i] then
            PreviewPool[i].Parent = nil -- Just hide in pool, don't destroy (reuse later)
        end
    end
end

-- ============================================
-- MAIN LOGIC & PUBLIC API
-- ============================================

local function cleanup()
    -- Clear preview first
    clearPreview()
    
    if State.Thread then
        pcall(function() task.cancel(State.Thread) end)
        State.Thread = nil
    end
    State.Enabled = false
    -- Clear object references to prevent memory leaks
    State.CurrentSapling = nil
    State.CurrentDebugId = nil
end

function AutoPlant.Init(deps)
    Utils = deps.Utils
    Remote = deps.Remote
    print("[OP] AutoPlant: Initialized (Multi-Pattern, Infinite Sapling)")
    
    -- Start Preview Loop using Heartbeat (more efficient than RenderStepped)
    if not PreviewConnection then
        PreviewConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if Settings.ShowPreview then
                updatePreview()
            end
        end)
    end
end

function AutoPlant.Start()
    if State.Enabled then return end
    
    cleanup()
    State.Enabled = true
    State.PlantCount = 0
    State.CurrentDebugId = nil
    
    print("[OP] AutoPlant: ON")
    
    State.Thread = task.spawn(function()
        -- Get center position (priority: Campfire > Player > Custom)
        local center
        local centerType = "Custom"
        
        if Settings.UseCampfireCenter then
            local campfirePos = findNearestCampfire()
            if campfirePos then
                center = campfirePos
                centerType = "Campfire"
            end
        end
        
        if not center and Settings.UsePlayerCenter then
            local root = Utils and Utils.getRoot()
            if root then
                center = root.Position
                centerType = "Player"
            end
        end
        
        if not center then
            center = Settings.CustomCenter
            centerType = "Custom"
        end
        
        print("[OP] AutoPlant: Center = " .. tostring(center) .. " (" .. centerType .. ")")
        
        -- Generate positions (Selected Pattern)
        local positions = generatePositions(center, Settings.Radius, Settings.Spacing, Settings.Height, Settings.Pattern)
        print("[OP] AutoPlant: Generated " .. #positions .. " plant positions (" .. Settings.Pattern .. ")")
        
        -- Find initial sapling
        local sapling = getSapling()
        if not sapling then
            warn("[OP] AutoPlant: No Sapling found in workspace.Items!")
            cleanup()
            return
        end
        
        print("[OP] AutoPlant: Found sapling, DebugId = " .. tostring(State.CurrentDebugId))
        
        -- Plant at each position
        for i, pos in ipairs(positions) do
            if not State.Enabled then break end
            
            -- Get sapling (reuse from nil instances)
            sapling = getSapling()
            if not sapling then
                warn("[OP] AutoPlant: Lost sapling reference at plant #" .. i)
                break
            end
            
            -- Plant
            local success = plantAt(sapling, pos)
            if success then
                State.PlantCount = State.PlantCount + 1
            end
            
            task.wait(Settings.PlantDelay)
        end
        
        print("[OP] AutoPlant: Completed! Planted " .. State.PlantCount .. " saplings")
        cleanup()
    end)
end

function AutoPlant.Stop()
    if not State.Enabled then return end
    
    cleanup()
    print("[OP] AutoPlant: OFF (Planted " .. State.PlantCount .. " total)")
end

function AutoPlant.IsEnabled()
    return State.Enabled
end

function AutoPlant.Cleanup()
    clearPreview()  -- Destroy all preview parts and pool
    
    -- Disconnect render loop
    if PreviewConnection then
        pcall(function() PreviewConnection:Disconnect() end)
        PreviewConnection = nil
    end
    
    cleanup()
    State.PlantCount = 0
end

-- Settings API
function AutoPlant.UpdateSetting(key, value)
    if Settings[key] ~= nil then
        Settings[key] = value
        
        -- Handle ShowPreview toggle
        if key == "ShowPreview" then
            if not value then
                clearPreview() -- Full cleanup of pool when toggled off
            end
        end
        
        -- Update preview when relevant settings change
        -- Since use RenderStepped, just flags is enough, but force update for pause mode
        -- Actually RenderStepped handles it.
    end
end

function AutoPlant.GetSettings()
    return Settings
end

function AutoPlant.GetPlantCount()
    return State.PlantCount
end

return AutoPlant
