--[[
    Features/PhysicsOptimizer.lua
    Reduce lag by modifying physics properties of items in workspace.Items
    
    3 Toggles:
    - Anchor: Disable gravity/physics simulation
    - NoCollide: Disable collision checks
    - Massless: Remove mass calculation
]]

local PhysicsOptimizer = {}

-- Dependencies
local Workspace = game:GetService("Workspace")

-- Constants
local STORAGE_HEIGHT_OFFSET = 1500  -- How high above player (Y offset) - far from physics
local BOX_SIZE = 300       -- 300x300 interior space
local WALL_THICKNESS = 5   -- Wall thickness
local BOX_HEIGHT = 100     -- Height of the box

-- State
local State = {
    SelectedTypes = {},      -- {"Log", "Sapling", ...}
    AnchorEnabled = false,
    NoCollideEnabled = false,
    MasslessEnabled = false,
    ModifiedCount = 0,
    StoragePosition = nil,   -- Teleport position (corner of box)
    StorageCenter = nil,     -- Center of box (for placing items)
    StorageParts = {},       -- All parts of the storage box
}

-- Cache of original values (for reverting)
local OriginalValues = {}  -- {[item] = {Anchored=bool, CanCollide=bool, Massless=bool}}

-- ============================================
-- STORAGE BOX (6-sided cube enclosure)
-- ============================================

local function createWall(name, size, position, color)
    local wall = Instance.new("Part")
    wall.Name = "OP_Storage_" .. name
    wall.Size = size
    wall.Position = position
    wall.Anchored = true
    wall.CanCollide = true
    wall.CanTouch = false
    wall.CanQuery = false
    wall.CastShadow = false
    wall.Transparency = 0.3
    wall.Color = color
    wall.Material = Enum.Material.Glass
    wall.Parent = Workspace
    return wall
end

local function createStorageBox()
    -- Cleanup existing parts first
    for _, part in ipairs(State.StorageParts) do
        pcall(function() part:Destroy() end)
    end
    table.clear(State.StorageParts)
    
    -- Get player position and create box HIGH above it
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    local playerPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
    
    -- Storage box position: Same X/Z as player, but very high up (Y + 500)
    local center = Vector3.new(playerPos.X, playerPos.Y + STORAGE_HEIGHT_OFFSET, playerPos.Z)
    
    local halfSize = BOX_SIZE / 2
    local halfHeight = BOX_HEIGHT / 2
    local defaultColor = Color3.new(1, 1, 1)  -- Default Roblox white
    
    -- Floor (bottom)
    local floor = createWall("Floor", 
        Vector3.new(BOX_SIZE, WALL_THICKNESS, BOX_SIZE),
        center - Vector3.new(0, halfHeight, 0),
        defaultColor)
    table.insert(State.StorageParts, floor)
    
    -- Ceiling (top)
    local ceiling = createWall("Ceiling",
        Vector3.new(BOX_SIZE, WALL_THICKNESS, BOX_SIZE),
        center + Vector3.new(0, halfHeight, 0),
        defaultColor)
    table.insert(State.StorageParts, ceiling)
    
    -- Wall 1 (Front -Z)
    local wall1 = createWall("WallFront",
        Vector3.new(BOX_SIZE, BOX_HEIGHT, WALL_THICKNESS),
        center - Vector3.new(0, 0, halfSize),
        defaultColor)
    table.insert(State.StorageParts, wall1)
    
    -- Wall 2 (Back +Z)
    local wall2 = createWall("WallBack",
        Vector3.new(BOX_SIZE, BOX_HEIGHT, WALL_THICKNESS),
        center + Vector3.new(0, 0, halfSize),
        defaultColor)
    table.insert(State.StorageParts, wall2)
    
    -- Wall 3 (Left -X)
    local wall3 = createWall("WallLeft",
        Vector3.new(WALL_THICKNESS, BOX_HEIGHT, BOX_SIZE),
        center - Vector3.new(halfSize, 0, 0),
        defaultColor)
    table.insert(State.StorageParts, wall3)
    
    -- Wall 4 (Right +X)
    local wall4 = createWall("WallRight",
        Vector3.new(WALL_THICKNESS, BOX_HEIGHT, BOX_SIZE),
        center + Vector3.new(halfSize, 0, 0),
        defaultColor)
    table.insert(State.StorageParts, wall4)
    
    -- Save CENTER of box (for placing items - slightly above floor)
    State.StorageCenter = center - Vector3.new(0, halfHeight - 5, 0)
    
    -- Set TELEPORT position to CORNER of box (offset 100 studs so player can see items)
    State.StoragePosition = center + Vector3.new(-100, -halfHeight + 10, -100)
    
    print("[PhysicsOptimizer] Storage box created at " .. tostring(center) .. " (High above player)")
    return State.StorageParts
end

local function destroyStorageBox()
    for _, part in ipairs(State.StorageParts) do
        pcall(function() part:Destroy() end)
    end
    table.clear(State.StorageParts)
    State.StoragePosition = nil
    print("[PhysicsOptimizer] Storage box destroyed")
end

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function getItemsFolder()
    return Workspace:FindFirstChild("Items")
end

-- Blacklist patterns (same as ItemCollector)
local BLACKLIST_PATTERNS = {"Chest", "Crate", "StoneChest"}

local function isBlacklisted(itemName)
    for _, pattern in ipairs(BLACKLIST_PATTERNS) do
        if string.find(itemName, pattern) then
            return true
        end
    end
    return false
end

-- Get all unique item type names (excluding blacklisted)
function PhysicsOptimizer.ScanItemTypes()
    local types = {}
    local seen = {}
    
    local items = getItemsFolder()
    if not items then return types end
    
    for _, item in ipairs(items:GetChildren()) do
        if not seen[item.Name] and not isBlacklisted(item.Name) then
            seen[item.Name] = true
            table.insert(types, item.Name)
        end
    end
    
    table.sort(types)
    return types
end

-- Apply settings to a single item
local function applyToItem(item)
    if not item then return false end
    
    local modified = false
    
    for _, part in ipairs(item:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Save original values if not saved yet
            if not OriginalValues[part] then
                OriginalValues[part] = {
                    Anchored = part.Anchored,
                    CanCollide = part.CanCollide,
                    Massless = part.Massless,
                }
            end
            
            -- Apply settings
            if State.AnchorEnabled then
                part.Anchored = true
                modified = true
            end
            
            if State.NoCollideEnabled then
                part.CanCollide = false
                modified = true
            end
            
            if State.MasslessEnabled then
                part.Massless = true
                modified = true
            end
        end
    end
    
    -- Also check if item itself is a BasePart
    if item:IsA("BasePart") then
        if not OriginalValues[item] then
            OriginalValues[item] = {
                Anchored = item.Anchored,
                CanCollide = item.CanCollide,
                Massless = item.Massless,
            }
        end
        
        if State.AnchorEnabled then item.Anchored = true; modified = true end
        if State.NoCollideEnabled then item.CanCollide = false; modified = true end
        if State.MasslessEnabled then item.Massless = true; modified = true end
    end
    
    return modified
end

-- Revert settings on a single item
local function revertItem(item, property)
    if not item then return end
    
    for _, part in ipairs(item:GetDescendants()) do
        if part:IsA("BasePart") and OriginalValues[part] then
            if property == "Anchored" then
                part.Anchored = OriginalValues[part].Anchored
                
            elseif property == "CanCollide" then
                -- SAFETY: Reset velocity before enabling collision to prevent fling
                if OriginalValues[part].CanCollide then
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                    -- Small upward nudge if it was noclip (optional, but safer)
                    -- part.CFrame = part.CFrame + Vector3.new(0, 0.1, 0)
                end
                
                part.CanCollide = OriginalValues[part].CanCollide
                
            elseif property == "Massless" then
                part.Massless = OriginalValues[part].Massless
            end
        end
    end
    
    if item:IsA("BasePart") and OriginalValues[item] then
        if property == "Anchored" then
            item.Anchored = OriginalValues[item].Anchored
        elseif property == "CanCollide" then
            -- SAFETY: Reset velocity before enabling collision to prevent fling
            if OriginalValues[item].CanCollide then
                item.AssemblyLinearVelocity = Vector3.zero
                item.AssemblyAngularVelocity = Vector3.zero
                -- Small upward nudge if it was noclip (optional, but safer)
                -- item.CFrame = item.CFrame + Vector3.new(0, 0.1, 0)
            end
            item.CanCollide = OriginalValues[item].CanCollide
        elseif property == "Massless" then
            item.Massless = OriginalValues[item].Massless
        end
    end
end

-- ============================================
-- PUBLIC API
-- ============================================

function PhysicsOptimizer.Init()
    print("[PhysicsOptimizer] Initialized")
end

function PhysicsOptimizer.SetSelectedTypes(types)
    State.SelectedTypes = types or {}
end

function PhysicsOptimizer.GetSelectedTypes()
    return State.SelectedTypes
end

-- Toggle setters
function PhysicsOptimizer.SetAnchor(enabled)
    State.AnchorEnabled = enabled
    PhysicsOptimizer.Apply()
end

function PhysicsOptimizer.SetNoCollide(enabled)
    State.NoCollideEnabled = enabled
    PhysicsOptimizer.Apply()
end

function PhysicsOptimizer.SetMassless(enabled)
    State.MasslessEnabled = enabled
    PhysicsOptimizer.Apply()
end

-- Apply current settings to all selected item types
function PhysicsOptimizer.Apply()
    local items = getItemsFolder()
    if not items then 
        warn("[PhysicsOptimizer] workspace.Items not found")
        return 0 
    end
    
    -- Build lookup for selected types
    local selectedLookup = {}
    for _, typeName in ipairs(State.SelectedTypes) do
        selectedLookup[typeName] = true
    end
    
    if next(selectedLookup) == nil then
        print("[PhysicsOptimizer] No item types selected")
        return 0
    end
    
    local count = 0
    
    for _, item in ipairs(items:GetChildren()) do
        if selectedLookup[item.Name] then
            if applyToItem(item) then
                count = count + 1
            end
        end
    end
    
    State.ModifiedCount = count
    print("[PhysicsOptimizer] Applied to " .. count .. " items")
    return count
end

-- Revert specific property on all items
function PhysicsOptimizer.Revert(property)
    local items = getItemsFolder()
    if not items then return end
    
    local selectedLookup = {}
    for _, typeName in ipairs(State.SelectedTypes) do
        selectedLookup[typeName] = true
    end
    
    for _, item in ipairs(items:GetChildren()) do
        if selectedLookup[item.Name] then
            revertItem(item, property)
        end
    end
    
    print("[PhysicsOptimizer] Reverted " .. property .. " on selected items")
end

-- Get stats
function PhysicsOptimizer.GetStats()
    return {
        selectedCount = #State.SelectedTypes,
        modifiedCount = State.ModifiedCount,
        anchorEnabled = State.AnchorEnabled,
        noCollideEnabled = State.NoCollideEnabled,
        masslessEnabled = State.MasslessEnabled,
    }
end

-- Yeet items far away (outside terrain)
function PhysicsOptimizer.YeetItems()
    local items = getItemsFolder()
    if not items then 
        warn("[PhysicsOptimizer] workspace.Items not found")
        return 0 
    end
    
    local selectedLookup = {}
    for _, typeName in ipairs(State.SelectedTypes) do
        selectedLookup[typeName] = true
    end
    
    if next(selectedLookup) == nil then
        print("[PhysicsOptimizer] No item types selected for yeet")
        return 0
    end
    
    local count = 0
    local farPosition = CFrame.new(99999, 99999, 99999)
    
    for _, item in ipairs(items:GetChildren()) do
        if selectedLookup[item.Name] then
            pcall(function()
                -- Try to move the whole model/part
                if item:IsA("Model") and item.PrimaryPart then
                    item:SetPrimaryPartCFrame(farPosition)
                elseif item:IsA("BasePart") then
                    item.CFrame = farPosition
                else
                    -- Move all parts inside
                    for _, part in ipairs(item:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CFrame = farPosition
                        end
                    end
                end
                count = count + 1
            end)
        end
    end
    
    print("[PhysicsOptimizer] Yeeted " .. count .. " items to (99999, 99999, 99999)")
    return count
end

-- Set storage position (current player position)
function PhysicsOptimizer.SetStoragePosition()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        State.StoragePosition = hrp.Position
        print("[PhysicsOptimizer] Storage position set to: " .. tostring(State.StoragePosition))
        return State.StoragePosition
    else
        warn("[PhysicsOptimizer] Could not get player position")
        return nil
    end
end

-- Get storage position (for teleport - corner)
function PhysicsOptimizer.GetStoragePosition()
    return State.StoragePosition
end

-- Get storage center (for placing items)
function PhysicsOptimizer.GetStorageCenter()
    return State.StorageCenter
end

-- Move items to storage CENTER (with grid layout)
function PhysicsOptimizer.MoveToStorage()
    if not State.StorageCenter then
        warn("[PhysicsOptimizer] No storage box created! Create one first.")
        return 0
    end
    
    local items = getItemsFolder()
    if not items then 
        warn("[PhysicsOptimizer] workspace.Items not found")
        return 0 
    end
    
    local selectedLookup = {}
    for _, typeName in ipairs(State.SelectedTypes) do
        selectedLookup[typeName] = true
    end
    
    if next(selectedLookup) == nil then
        print("[PhysicsOptimizer] No item types selected for storage")
        return 0
    end
    
    local count = 0
    local basePos = State.StorageCenter  -- Use CENTER of box, not corner
    local spacing = 3 -- Spacing between items in grid
    local gridSize = 10 -- Items per row
    
    for _, item in ipairs(items:GetChildren()) do
        if selectedLookup[item.Name] then
            pcall(function()
                -- Calculate grid position
                local row = math.floor(count / gridSize)
                local col = count % gridSize
                local offset = Vector3.new(col * spacing, 2, row * spacing)
                local targetCFrame = CFrame.new(basePos + offset)
                
                -- Move item
                if item:IsA("Model") and item.PrimaryPart then
                    item:SetPrimaryPartCFrame(targetCFrame)
                elseif item:IsA("BasePart") then
                    item.CFrame = targetCFrame
                else
                    for _, part in ipairs(item:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CFrame = targetCFrame
                            break -- Only move first part, rest will follow
                        end
                    end
                end
                count = count + 1
            end)
        end
    end
    
    print("[PhysicsOptimizer] Moved " .. count .. " items to storage at " .. tostring(basePos))
    return count
end

-- ============================================
-- STORAGE BOX PUBLIC API
-- ============================================

-- Create storage box (auto-sets position)
function PhysicsOptimizer.CreatePlatform()
    createStorageBox()
    return State.StoragePosition
end

-- Destroy storage box
function PhysicsOptimizer.DestroyPlatform()
    destroyStorageBox()
end

-- Check if storage box exists
function PhysicsOptimizer.HasPlatform()
    return #State.StorageParts > 0
end

-- Teleport player to storage box
function PhysicsOptimizer.TeleportToStorage()
    if not State.StoragePosition then
        warn("[PhysicsOptimizer] No storage box created! Create one first.")
        return false
    end
    
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local char = LocalPlayer and LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if not hrp then
        warn("[PhysicsOptimizer] Player character not found")
        return false
    end
    
    -- Safe teleport sequence
    task.spawn(function()
        -- Freeze
        hrp.Anchored = true
        
        -- Request stream around target
        pcall(function()
            LocalPlayer:RequestStreamAroundAsync(State.StoragePosition)
        end)
        
        -- Teleport
        hrp.CFrame = CFrame.new(State.StoragePosition)
        
        -- Wait for geometry
        task.wait(0.3)
        
        -- Unfreeze
        hrp.Anchored = false
    end)
    
    print("[PhysicsOptimizer] Teleported to storage at " .. tostring(State.StoragePosition))
    return true
end

-- ============================================
-- CLEANUP (Memory Leak Prevention)
-- ============================================

function PhysicsOptimizer.Cleanup()
    -- Destroy storage box
    destroyStorageBox()
    
    -- Clear original values cache
    table.clear(OriginalValues)
    
    -- Reset state
    State.SelectedTypes = {}
    State.AnchorEnabled = false
    State.NoCollideEnabled = false
    State.MasslessEnabled = false
    State.ModifiedCount = 0
    State.StoragePosition = nil
    
    print("[PhysicsOptimizer] Cleanup complete - no memory leaks")
end

return PhysicsOptimizer
