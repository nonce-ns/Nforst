--[[
    Features/ItemCollector.lua
    Auto-collect items from workspace.Items to selected destination
    REWRITTEN: Physics Safety, Smart Verification, Retry Logic
]]

local ItemCollector = {}

-- Services
local Players = game:GetService("Players")

-- Constants
local LocalPlayer = Players.LocalPlayer
local ITEMS_FOLDER = "Items"
local MAX_RETRIES = 3           -- Max attempts per item
local RETRY_DELAY = 0.05        -- 50ms (very fast retry)
local NETWORK_WAIT = 0.05       -- 50ms wait for server ownership
local VERIFY_RADIUS = 8         -- Distance to consider "arrived"

-- Speed Presets (delay between items)
-- "Instant" is now 0, but we have internal safety waits
local SPEED_PRESETS = {
    Instant = 0,      -- As fast as possible
    Fast = 0.03,      -- ~30ms
    Normal = 0.1,     -- 100ms
    Slow = 0.3,       -- 300ms
}

-- Item Categories with pattern matching
local ITEM_CATEGORIES = {
    {
        name = "Campfire",
        icon = "lucide:flame",
        patterns = {"Log", "Oil Barrel", "Fuel Canister", "Fuel", "Corpse"},
        exactMatch = {"Log", "Chair", "Cultist", "Coal"}
    },
    {
        name = "Scrapper",
        icon = "lucide:recycle",
        patterns = {"Broken", "Metal", "Engine", "Radio", "Washing", "Tyre", "Bolt"},
        exactMatch = {"Cultist Gem"}
    },
    {
        name = "Anvil",
        icon = "lucide:hammer",
        patterns = {"Anvil"},
        exactMatch = {}
    },
    {
        name = "Armor",
        icon = "lucide:shield",
        patterns = {"Body"},
        exactMatch = {}
    },
    {
        name = "Weapons",
        icon = "lucide:sword",
        patterns = {"Rifle", "Ammo", "Axe", "Gun", "Sword", "Canon", "Morningstar", "Crossbow", "Chainsaw", "Raygun", "Spear", "Shotgun"},
        exactMatch = {}
    },
    {
        name = "Tools",
        icon = "lucide:wrench",
        patterns = {"Rod", "Flashlight", "Flute"},
        exactMatch = {}
    },
    {
        name = "Food",
        icon = "lucide:drumstick",
        patterns = {},
        exactMatch = {"Apple", "Berry", "Steak", "Morsel", "Cake", "Carrot", "Corn", "Pumpkin", "Acorn", "Bandage", "MedKit"}
    },
    {
        name = "Animal Parts",
        icon = "lucide:paw-print",
        patterns = {"Pelt", "Foot"},
        exactMatch = {}
    },
    {
        name = "Containers",
        icon = "lucide:package",
        patterns = {},
        exactMatch = {"Seed Box", "Giant Sack"}
    },
    {
        name = "Blacklist",
        icon = "lucide:ban",
        patterns = {"Chest", "Crate", "StoneChest"},
        exactMatch = {}
    },
}

-- Dependencies (injected)
local Remote = nil

-- State
local State = {
    Enabled = false,
    Threads = {},            -- Multiple parallel collection threads (max 3)
    ItemCache = {},          -- {["Log"] = true, ["Coal"] = true} - name-only cache
    SelectedItems = {},      -- {"Log", "Coal"} selected item types
    QuantityLimits = {},     -- {["Log"] = 50, ["Coal"] = 100}
    GlobalLimit = 50,        -- Default max per type
    Destination = "Player",  -- Player/Campfire/Scrapper/OtherPlayer
    TargetPlayer = "",       -- For OtherPlayer mode
    Speed = "Fast",          -- Instant/Fast/Normal/Slow
    DropHeight = 0,          -- Height offset for dropping items (0-20)
    CollectedCount = 0,      -- Session counter
    -- Organization Mode
    OrganizeEnabled = false, -- Toggle for organization mode
    OrganizeMode = "Grid",   -- Grid/Line
    GridSpacing = 1,         -- Gap between items (studs)
    MaxLayers = 1,           -- Vertical stacking layers
    PreviewEnabled = false,
    PreviewFolder = nil,
    -- Exclude Nearby
    ExcludeNearbyEnabled = false,  -- Skip items near player
    ExcludeRadius = 20,            -- Radius in studs
    ExcludeCircle = nil,           -- Visual circle part
    ExcludeConnection = nil,       -- RenderStepped connection
    -- Fixed Position
    FixedPositionEnabled = false,  -- Lock drop position at start
    -- Callbacks
    OnScanCallback = nil,
}

-- Preview pool for reusing parts
local PreviewPool = {}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function getItemsFolder()
    return workspace:FindFirstChild(ITEMS_FOLDER)
end

local function getDestinationObject()
    if State.Destination == "Player" then
        return LocalPlayer.Character
    elseif State.Destination == "Campfire" then
        local map = workspace:FindFirstChild("Map")
        if map then
            local campground = map:FindFirstChild("Campground")
            if campground then
                local mainFire = campground:FindFirstChild("MainFire")
                if mainFire then
                    return mainFire:FindFirstChild("Center") or mainFire
                end
            end
        end
        return nil
    elseif State.Destination == "Scrapper" then
        local map = workspace:FindFirstChild("Map")
        if map then
            local campground = map:FindFirstChild("Campground")
            if campground then
                return campground:FindFirstChild("Scrapper")
            end
        end
        return nil
    elseif State.Destination == "OtherPlayer" then
        if State.TargetPlayer and State.TargetPlayer ~= "" then
            local player = Players:FindFirstChild(State.TargetPlayer)
            if player and player.Character then
                return player.Character
            end
        end
        return nil
    elseif State.Destination == "StorageBox" then
        -- Use PhysicsOptimizer storage box center
        local PhysicsOptimizer = getgenv().OP_FEATURES and getgenv().OP_FEATURES.PhysicsOptimizer
        if PhysicsOptimizer and PhysicsOptimizer.HasPlatform and PhysicsOptimizer.HasPlatform() then
            -- Return a dummy part-like table with Position property
            local center = PhysicsOptimizer.GetStorageCenter and PhysicsOptimizer.GetStorageCenter()
            if center then
                return {Position = center, IsStorageBox = true}
            end
        end
        return nil
    end
    return nil
end

local function getDelay()
    return SPEED_PRESETS[State.Speed] or 0.05
end

-- Get base height offset for destination
local function getBaseHeightOffset()
    if State.Destination == "Campfire" or State.Destination == "Scrapper" then
        return 20  -- Base height of 20 studs for Campfire/Scrapper
    end
    return 0
end

-- Get center position from a destination object
local function getCenterPosition(dest)
    if not dest then return nil end
    
    -- Handle StorageBox (returns table with Position, not Instance)
    if type(dest) == "table" and dest.IsStorageBox and dest.Position then
        return dest.Position
    end
    
    if dest:IsA("Model") and dest:FindFirstChild("HumanoidRootPart") then
        return dest.HumanoidRootPart.Position
    elseif dest:IsA("BasePart") then
        return dest.Position
    elseif dest:IsA("Model") and dest.PrimaryPart then
        return dest.PrimaryPart.Position
    else
        local part = dest:FindFirstChildWhichIsA("BasePart")
        if part then return part.Position end
    end
    
    return nil
end

local function cleanup()
    State.Enabled = false
    -- Cancel ALL parallel threads
    for i, thread in ipairs(State.Threads) do
        pcall(task.cancel, thread)
    end
    State.Threads = {}
end

-- ============================================
-- PHYSICS HELPERS (NEW)
-- ============================================

-- Reset velocity to prevent flinging
local function resetPhysics(item)
    if not item then return end
    
    local parts = {}
    if item:IsA("BasePart") then
        table.insert(parts, item)
    else
        for _, part in ipairs(item:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(parts, part)
            end
        end
    end
    
    for _, part in ipairs(parts) do
        -- Stop physical movement
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end
end

-- ============================================
-- PREVIEW & GRID FUNCTIONS
-- ============================================
-- (Kept largely the same, just included for completeness)

local function clearPreview()
    if State.PreviewFolder then
        pcall(function() State.PreviewFolder:Destroy() end)
        State.PreviewFolder = nil
    end
    for i, part in pairs(PreviewPool) do
        pcall(function() part:Destroy() end)
        PreviewPool[i] = nil
    end
    table.clear(PreviewPool)
    State.PreviewEnabled = false
end

local function createPreviewPart(position, size, color, transparency)
    local part = Instance.new("Part")
    part.Name = "CollectPreview"
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.Size = size or Vector3.new(1, 1, 1)
    part.Position = position
    part.Color = color or Color3.fromRGB(0, 200, 255)
    part.Transparency = transparency or 0.6
    part.Material = Enum.Material.Neon
    part.Parent = State.PreviewFolder
    return part
end

local function getItemBoundingBox(item)
    if not item then return Vector3.new(1, 1, 1) end
    
    local success, cf, size = pcall(function()
        if item:IsA("Model") then
            return item:GetBoundingBox()
        elseif item:IsA("BasePart") then
            return item.CFrame, item.Size
        end
    end)
    
    if success and size then
        return size
    end
    return Vector3.new(1, 1, 1)
end

local function generateGridPositions(center, itemCount, itemSize, spacing)
    local positions = {}
    if itemCount == 0 then return positions end
    
    local maxLayers = math.clamp(State.MaxLayers or 1, 1, 2)
    local itemsPerLayer = math.ceil(itemCount / maxLayers)
    
    local bestCols = 1
    local bestRows = itemsPerLayer
    local bestScore = 999999
    local sqrtItems = math.sqrt(itemsPerLayer)
    
    for cols = 1, itemsPerLayer do
        local rows = math.ceil(itemsPerLayer / cols)
        local totalCells = cols * rows
        local waste = totalCells - itemsPerLayer
        local wastePercent = waste / itemsPerLayer
        
        if wastePercent <= 0.3 then
            local ratio = math.max(cols, rows) / math.max(math.min(cols, rows), 1)
            local score = ratio * 100 + waste
            if score < bestScore then
                bestCols = cols
                bestRows = rows
                bestScore = score
            end
        end
        if cols > sqrtItems * 2 then break end
    end
    
    local cols = bestCols
    local rows = bestRows
    
    local sizeX = itemSize.X * 0.5
    local sizeZ = math.min(itemSize.Z, itemSize.X * 1.2) * 0.5
    local sizeY = itemSize.Y * 0.8
    
    local cellWidth = sizeX + spacing
    local cellDepth = sizeZ + spacing
    local layerHeight = sizeY + 0.5
    
    local totalWidth = (cols - 1) * cellWidth
    local totalDepth = (rows - 1) * cellDepth
    local startX = center.X - totalWidth / 2
    local startZ = center.Z - totalDepth / 2
    
    for i = 1, itemCount do
        local layer = math.floor((i - 1) / (cols * rows))
        local indexInLayer = (i - 1) % (cols * rows)
        local row = math.floor(indexInLayer / cols)
        local col = indexInLayer % cols
        
        local x = startX + col * cellWidth
        local z = startZ + row * cellDepth
        local y = center.Y + getBaseHeightOffset() + State.DropHeight + (layer * layerHeight)
        
        table.insert(positions, Vector3.new(x, y, z))
    end
    
    return positions
end

local function generateLinePositions(center, itemCount, itemSize, spacing)
    local positions = {}
    if itemCount == 0 then return positions end
    
    local sizeX = itemSize.X * 0.5
    local cellWidth = sizeX + spacing
    local totalWidth = (itemCount - 1) * cellWidth
    local startX = center.X - totalWidth / 2
    
    for i = 1, itemCount do
        local x = startX + (i - 1) * cellWidth
        table.insert(positions, Vector3.new(x, center.Y + getBaseHeightOffset() + State.DropHeight, center.Z))
    end
    
    return positions
end

local function updatePreview()
    if not State.PreviewEnabled or not State.OrganizeEnabled then
        if State.PreviewFolder then clearPreview() end
        return
    end
    
    local dest = getDestinationObject()
    if not dest then return end
    
    local center = getCenterPosition(dest)
    if not center then return end
    
    -- Count items directly from workspace (no cache dependency)
    local itemsFolder = getItemsFolder()
    if not itemsFolder then
        if State.PreviewFolder then clearPreview() end
        return
    end
    
    local selectedLookup = {}
    for _, name in ipairs(State.SelectedItems) do
        selectedLookup[name] = true
    end
    
    local itemCount = 0
    local sampleItem = nil
    local itemCounts = {} -- Track per-item counts for limit checking
    
    for _, item in ipairs(itemsFolder:GetChildren()) do
        if selectedLookup[item.Name] then
            itemCounts[item.Name] = (itemCounts[item.Name] or 0) + 1
            local limit = State.QuantityLimits[item.Name] or State.GlobalLimit
            if itemCounts[item.Name] <= limit then
                itemCount = itemCount + 1
                if not sampleItem then sampleItem = item end
            end
        end
    end
    
    if itemCount == 0 then
        if State.PreviewFolder then clearPreview() end
        return
    end
    
    local itemSize = getItemBoundingBox(sampleItem)
    local positions
    if State.OrganizeMode == "Grid" then
        positions = generateGridPositions(center, itemCount, itemSize, State.GridSpacing)
    else
        positions = generateLinePositions(center, itemCount, itemSize, State.GridSpacing)
    end
    
    if not State.PreviewFolder then
        State.PreviewFolder = Instance.new("Folder")
        State.PreviewFolder.Name = "ItemCollectorPreview"
        State.PreviewFolder.Parent = workspace
    end
    
    local previewSize = Vector3.new(itemSize.X * 0.8, 0.3, itemSize.Z * 0.8)
    for i, pos in ipairs(positions) do
        local part = PreviewPool[i]
        if not part then
            part = createPreviewPart(pos, previewSize, Color3.fromRGB(0, 200, 255), 0.5)
            PreviewPool[i] = part
        end
        part.Position = pos
        part.Size = previewSize
        part.Parent = State.PreviewFolder
    end
    
    for i = #positions + 1, #PreviewPool do
        if PreviewPool[i] then
            pcall(function() PreviewPool[i]:Destroy() end)
            PreviewPool[i] = nil
        end
    end
end

local previewDebounce = nil
local function queuePreviewUpdate()
    if previewDebounce then pcall(task.cancel, previewDebounce) end
    previewDebounce = task.delay(0.05, function()
        updatePreview()
        previewDebounce = nil
    end)
end

-- ============================================
-- CORE FUNCTIONS
-- ============================================

function ItemCollector.ScanItems()
    -- LIGHTWEIGHT: Only collect unique item NAMES (no counting, no caching objects)
    local folder = getItemsFolder()
    if not folder then return {} end
    
    local uniqueNames = {}
    for _, item in ipairs(folder:GetChildren()) do
        uniqueNames[item.Name] = true -- Just mark name as existing
    end
    
    -- Merge with existing known names (preserve selections)
    for name, _ in pairs(uniqueNames) do
        if not State.ItemCache[name] then
            State.ItemCache[name] = true
        end
    end
    
    if State.OnScanCallback then
        task.spawn(function() State.OnScanCallback(State.ItemCache) end)
    end
    return State.ItemCache
end

local function isBlacklisted(itemName)
    local blacklist = nil
    for _, cat in ipairs(ITEM_CATEGORIES) do
        if cat.name == "Blacklist" then
            blacklist = cat
            break
        end
    end
    if not blacklist then return false end
    
    for _, exact in ipairs(blacklist.exactMatch or {}) do
        if itemName == exact then return true end
    end
    
    local nameLower = itemName:lower()
    for _, pattern in ipairs(blacklist.patterns or {}) do
        if nameLower:find(pattern:lower()) then return true end
    end
    return false
end

function ItemCollector.GetItemList()
    -- Returns sorted list of item NAMES only (no counts)
    local names = {}
    for name, _ in pairs(State.ItemCache) do
        if not isBlacklisted(name) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

function ItemCollector.GetItemNames()
    local names = {}
    for name, _ in pairs(State.ItemCache) do
        if not isBlacklisted(name) then table.insert(names, name) end
    end
    table.sort(names)
    return names
end

function ItemCollector.GetCache() return State.ItemCache end

function ItemCollector.GetCategories()
    local categories = {}
    for _, cat in ipairs(ITEM_CATEGORIES) do
        table.insert(categories, {name = cat.name, icon = cat.icon or "lucide:box"})
    end
    return categories
end

local function itemMatchesCategory(itemName, category)
    for _, exact in ipairs(category.exactMatch or {}) do
        if itemName == exact then return true end
    end
    local nameLower = itemName:lower()
    for _, pattern in ipairs(category.patterns or {}) do
        if nameLower:find(pattern:lower()) then return true end
    end
    return false
end

function ItemCollector.GetItemsByCategory(categoryName)
    -- Returns sorted list of item NAMES in a category (no counts)
    local result = {}
    local category = nil
    for _, cat in ipairs(ITEM_CATEGORIES) do
        if cat.name == categoryName then
            category = cat
            break
        end
    end
    if not category then return result end
    
    for name, _ in pairs(State.ItemCache) do
        if itemMatchesCategory(name, category) then 
            table.insert(result, name) 
        end
    end
    table.sort(result)
    return result
end

function ItemCollector.ParseItemName(formatted)
    -- Since we no longer use counts in names, just return as-is
    -- But keep backward compatibility for old format "Name (123)"
    if not formatted then return nil end
    local name = string.match(formatted, "^(.+) %(")
    return name or formatted
end

function ItemCollector.SetSelectedItems(selected)
    State.SelectedItems = {}
    if type(selected) == "table" then
        for key, value in pairs(selected) do
            local name = nil
            if type(key) == "string" and value == true then
                name = ItemCollector.ParseItemName(key)
            elseif type(key) == "number" and type(value) == "string" then
                name = ItemCollector.ParseItemName(value)
            end
            if name then table.insert(State.SelectedItems, name) end
        end
    end
end

function ItemCollector.AddToSelection(itemName)
    if not itemName then return false end
    for _, name in ipairs(State.SelectedItems) do
        if name == itemName then return false end
    end
    table.insert(State.SelectedItems, itemName)
    print("[ItemCollector] Selected: " .. itemName) -- Debug Log
    return true
end

function ItemCollector.RemoveFromSelection(itemName)
    if not itemName then return false end
    for i, name in ipairs(State.SelectedItems) do
        if name == itemName then
            table.remove(State.SelectedItems, i)
            print("[ItemCollector] Unselected: " .. itemName) -- Debug Log
            return true
        end
    end
    return false
end

function ItemCollector.ClearSelection() 
    local count = #State.SelectedItems
    State.SelectedItems = {} 
    if count > 0 then
        print("[ItemCollector] Cleared selection (removed " .. count .. " items).") -- Debug Log
    end
end
function ItemCollector.SetQuantity(itemName, qty) if itemName and qty then State.QuantityLimits[itemName] = qty end end
function ItemCollector.SetGlobalLimit(qty) State.GlobalLimit = qty or 50 end
function ItemCollector.SetDestination(dest) State.Destination = dest or "Player" end
function ItemCollector.SetTargetPlayer(name) State.TargetPlayer = name or "" end
function ItemCollector.SetOnScanCallback(callback) State.OnScanCallback = callback end
function ItemCollector.SetSpeed(speed) if SPEED_PRESETS[speed] ~= nil or speed == "Instant" then State.Speed = speed end end
function ItemCollector.SetDropHeight(height) State.DropHeight = math.clamp(height or 0, 0, 20); queuePreviewUpdate() end
function ItemCollector.SetOrganizeEnabled(enabled) State.OrganizeEnabled = enabled; if not enabled then clearPreview() end; queuePreviewUpdate() end
function ItemCollector.SetOrganizeMode(mode) if mode == "Grid" or mode == "Line" then State.OrganizeMode = mode; queuePreviewUpdate() end end
function ItemCollector.SetGridSpacing(spacing) State.GridSpacing = math.clamp(spacing or 1, 0, 20); queuePreviewUpdate() end
function ItemCollector.SetMaxLayers(layers) State.MaxLayers = math.clamp(layers or 1, 1, 2); queuePreviewUpdate() end
function ItemCollector.TogglePreview(enabled) State.PreviewEnabled = enabled; if enabled then updatePreview() else clearPreview() end end
function ItemCollector.ClearPreview() clearPreview() end

-- ============================================
-- EXCLUDE NEARBY VISUAL CIRCLE (Ring of Neon Parts)
-- ============================================
local RunService = game:GetService("RunService")
local ExcludeCircleParts = {} -- Pool of parts forming the ring

local function clearExcludeCircle()
    for i, part in ipairs(ExcludeCircleParts) do
        pcall(function() part:Destroy() end)
    end
    table.clear(ExcludeCircleParts)
    
    if State.ExcludeCircle then
        pcall(function() State.ExcludeCircle:Destroy() end)
        State.ExcludeCircle = nil
    end
end

local function createExcludeCircle()
    if State.ExcludeCircle then return end
    
    -- Create folder to hold ring parts
    local folder = Instance.new("Folder")
    folder.Name = "ExcludeRadiusCircle"
    folder.Parent = workspace
    State.ExcludeCircle = folder
    
    -- Create ring of parts (64 segments for smooth circle)
    local numSegments = 64
    for i = 1, numSegments do
        local part = Instance.new("Part")
        part.Name = "RingSegment"
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Size = Vector3.new(0.15, 0.2, 1) -- Very thin
        part.Color = Color3.fromRGB(255, 80, 80) -- Bright red
        part.Transparency = 0.2
        part.Material = Enum.Material.Neon
        part.Parent = folder
        table.insert(ExcludeCircleParts, part)
    end
end

local function updateExcludeCirclePosition()
    if not State.ExcludeCircle then return end
    if #ExcludeCircleParts == 0 then return end
    
    local center = nil
    
    -- FIXED POSITION SYNC: Use fixed position if enabled
    if State.FixedPositionEnabled and State.FixedPositionVector then
        center = State.FixedPositionVector
    else
        -- Otherwise follow player
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then center = hrp.Position end
        end
    end
    
    if not center then return end
    
    local radius = State.ExcludeRadius
    local numSegments = #ExcludeCircleParts
    
    -- Calculate segment size based on radius
    local circumference = 2 * math.pi * radius
    local segmentLength = circumference / numSegments
    
    for i, part in ipairs(ExcludeCircleParts) do
        local angle = ((i - 1) / numSegments) * 2 * math.pi
        local x = center.X + radius * math.cos(angle)
        local z = center.Z + radius * math.sin(angle)
        
        -- Size: very thin, length slightly overlaps for seamless circle
        local segLen = math.max(segmentLength * 1.15, 0.3)
        part.Size = Vector3.new(0.1, 0.15, segLen)
        
        -- Position and rotate: segment's front should point along tangent (perpendicular to radius)
        -- Tangent direction at this point = perpendicular to radius = angle + 90 degrees
        part.CFrame = CFrame.new(x, center.Y - 2.5, z) * CFrame.Angles(0, -angle, 0)
    end
end

function ItemCollector.ShowExcludeCircle()
    createExcludeCircle()
    updateExcludeCirclePosition()
    
    -- Start update loop
    if State.ExcludeConnection then State.ExcludeConnection:Disconnect() end
    State.ExcludeConnection = RunService.Heartbeat:Connect(updateExcludeCirclePosition)
end

function ItemCollector.HideExcludeCircle()
    if State.ExcludeConnection then
        State.ExcludeConnection:Disconnect()
        State.ExcludeConnection = nil
    end
    clearExcludeCircle()
end

function ItemCollector.SetExcludeNearbyEnabled(enabled)
    State.ExcludeNearbyEnabled = enabled
    if enabled then
        ItemCollector.ShowExcludeCircle()
    else
        ItemCollector.HideExcludeCircle()
    end
end

function ItemCollector.SetExcludeRadius(radius)
    State.ExcludeRadius = math.clamp(radius or 20, 5, 100)
    if State.ExcludeCircle then
        updateExcludeCirclePosition()
    end
end

function ItemCollector.SetFixedPosition(enabled)
    State.FixedPositionEnabled = enabled
    -- Logic moved to Start(). Setting state only here.
end

function ItemCollector.GetStats()
    return {
        enabled = State.Enabled,
        collected = State.CollectedCount,
        selectedCount = #State.SelectedItems,
        destination = State.Destination,
        speed = State.Speed,
        fixedPos = State.FixedPositionEnabled,
    }
end

function ItemCollector.GetSelectedItems() return State.SelectedItems end

-- SetAutoRescan is a no-op (kept for backward compatibility with UI toggle)
function ItemCollector.SetAutoRescan(enabled) 
    -- No action needed - direct workspace iteration doesn't need auto-rescan
end

-- ScanItemCacheOnly - triggers UI refresh with current cache
function ItemCollector.ScanItemCacheOnly()
    if State.OnScanCallback then
        task.spawn(function() State.OnScanCallback(State.ItemCache) end)
    end
end

-- ============================================
-- COLLECT LOGIC (REWRITTEN)
-- ============================================

local function collectItem(item, targetPos)
    if not item or not item.Parent then return false end
    if not Remote then return false end
    
    -- Verify existence in folder
    local itemsFolder = getItemsFolder()
    if not itemsFolder or item.Parent ~= itemsFolder then return false end
    
    -- Verify destination
    if not targetPos then
        local dest = getDestinationObject()
        if not dest then return false end
        
        local rawPos = getCenterPosition(dest)
        if not rawPos then return false end
        
        local baseHeight = getBaseHeightOffset()
        targetPos = rawPos + Vector3.new(0, baseHeight + State.DropHeight, 0)
    end
    
    -- === RETRY LOOP ===
    local success = false
    
    for attempt = 1, MAX_RETRIES do
        if not State.Enabled then break end
        
        -- Debug: Log retry attempts if not the first attempt
        if attempt > 1 then
            print("[ItemCollector] Retrying item: " .. item.Name .. " (Attempt " .. attempt .. "/" .. MAX_RETRIES .. ")")
        end
        
        -- 1. Request Ownership/Drag
        Remote.RequestStartDraggingItem(item)
        
        -- 2. Smart Network Wait (prevent rubber-banding)
        -- Wait for server to register us as owner before moving
        -- "Fast" mode uses minimial wait, others use more
        local waitTime = (State.Speed == "Fast" or State.Speed == "Instant") and NETWORK_WAIT or 0.1
        task.wait(waitTime)
        
        -- 3. Reset Physics (CRITICAL FIX)
        -- Stop momentum so it doesn't fling
        resetPhysics(item)
        
        -- 4. Teleport
        local itemPart = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
        if itemPart then
            itemPart.CFrame = CFrame.new(targetPos)
        end
        
        -- 5. Wait for sync
        task.wait(RETRY_DELAY) 
        
        -- 6. VERIFICATION (CRITICAL FIX)
        -- Did it actually arrive?
        if itemPart then
            local dist = (itemPart.Position - targetPos).Magnitude
            if dist <= VERIFY_RADIUS then
                success = true
                -- Stop dragging only after verified arrival
                Remote.StopDraggingItem(item)
                break -- Exit retry loop
            else
                -- Failed to move - Reset physics again and retry
                resetPhysics(item)
            end
        else
            break -- Item destroyed
        end
    end
    
    if success then
        State.CollectedCount = State.CollectedCount + 1
        -- print("[ItemCollector] Success: " .. item.Name) -- Optional: Uncomment for very verbose logs
        return true
    else
        warn("[ItemCollector] Failed to collect: " .. item.Name .. " after " .. MAX_RETRIES .. " attempts.")
        Remote.StopDraggingItem(item) -- Cleanup attempt
        return false
    end
end

function ItemCollector.Start()
    if #State.SelectedItems == 0 then warn("[OP] ItemCollector: No items selected!"); return end
    
    -- Max 3 threads limit
    if #State.Threads >= 3 then
        warn("[ItemCollector] Max 3 threads! Please wait for one to finish.")
        return
    end
    
    clearPreview()
    State.Enabled = true
    
    -- FIXED POSITION LOCK: Capture position NOW (at start), not at toggle
    if State.FixedPositionEnabled then
        local dest = getDestinationObject()
        local pos = getCenterPosition(dest)
        if pos then
            State.FixedPositionVector = pos
            print("[ItemCollector] Fixed Position Locked at Start: " .. tostring(pos))
            if State.ExcludeCircle then updateExcludeCirclePosition() end
        else
            warn("[ItemCollector] Cannot lock Fixed Position: No valid destination found.")
            -- Do not disable the setting, just warn and don't lock
            State.FixedPositionVector = nil
        end
    else
        State.FixedPositionVector = nil
    end
    
    -- Build lookup table for selected item names
    local selectedLookup = {}
    for _, name in ipairs(State.SelectedItems) do
        selectedLookup[name] = true
    end
    
    local thread = task.spawn(function()
        local userDelay = getDelay()
        local itemsFolder = getItemsFolder()
        if not itemsFolder then 
            warn("[ItemCollector] Items folder not found!")
            State.Enabled = false
            return 
        end
        
        local dest = getDestinationObject()
        
        -- STORAGE BOX VALIDATION
        if State.Destination == "StorageBox" then
            if not dest then
                warn("[ItemCollector] Storage Box not found! Please create one in Misc Tab first.")
                if getgenv().WindUI then
                    getgenv().WindUI:Notify({
                        Title = "Missing Storage Box",
                        Content = "Create a box in Misc Tab first!",
                        Icon = "alert-circle",
                        Duration = 5,
                    })
                end
                State.Enabled = false
                return
            end
            
            -- Warn if too far (Streaming issues)
            local char = LocalPlayer.Character
            local destPos = getCenterPosition(dest)
            if char and destPos and (char.GetPivot(char).Position - destPos).Magnitude > 300 then
                 -- Just a notification, don't stop (user might know what they're doing)
                if getgenv().WindUI then
                     getgenv().WindUI:Notify({
                        Title = "Distance Warning",
                        Content = "You are far from the box! Items might fail to land.",
                        Duration = 4,
                    })
                end
            end
        end
        local canUseOrganizedMode = (State.Destination == "Player" or State.Destination == "OtherPlayer")
        local useOrganizedMode = State.OrganizeEnabled and canUseOrganizedMode
        
        if useOrganizedMode and dest then
            -- ORGANIZED MODE: Collect items first, then place in grid/line
            local center = getCenterPosition(dest)
            if center then
                -- Gather items DIRECTLY from workspace (not cache)
                local itemsToPlace = {}
                local collectedCounts = {} -- Track per-name limits
                
                for _, item in ipairs(itemsFolder:GetChildren()) do
                    if not State.Enabled then break end
                    if selectedLookup[item.Name] and item.Parent then
                        local limit = State.QuantityLimits[item.Name] or State.GlobalLimit
                        collectedCounts[item.Name] = (collectedCounts[item.Name] or 0) + 1
                        if collectedCounts[item.Name] <= limit then
                            table.insert(itemsToPlace, item)
                        end
                    end
                end
                
                if #itemsToPlace == 0 then
                    warn("[ItemCollector] No valid items found for organized mode.")
                else
                    local itemSize = getItemBoundingBox(itemsToPlace[1])
                    local positions
                    if State.OrganizeMode == "Grid" then
                        positions = generateGridPositions(center, #itemsToPlace, itemSize, State.GridSpacing)
                    else
                        positions = generateLinePositions(center, #itemsToPlace, itemSize, State.GridSpacing)
                    end
                    
                    for i, item in ipairs(itemsToPlace) do
                        if not State.Enabled then break end
                        if item and item.Parent and positions[i] then
                            collectItem(item, positions[i])
                            if userDelay > 0 then task.wait(userDelay) end
                        end
                    end
                end
            end
        else
            -- STACK MODE: Collect items DIRECTLY from workspace
            local collectedCounts = {}
            local totalCollected = 0
            local skippedNearby = 0
            
            -- Pre-calculate if we should check exclude nearby
            local shouldExcludeNearby = State.ExcludeNearbyEnabled and 
                (State.Destination == "Player" or State.Destination == "OtherPlayer")
            
            -- Fixed Position: Capture position at start (only for Player/OtherPlayer)
            local fixedDestPos = nil
            if State.FixedPositionEnabled and (State.Destination == "Player" or State.Destination == "OtherPlayer") then
                local startDest = getDestinationObject()
                local startPos = startDest and getCenterPosition(startDest)
                if startPos then
                    local baseHeight = getBaseHeightOffset()
                    fixedDestPos = startPos + Vector3.new(0, baseHeight + State.DropHeight, 0)
                    print("[ItemCollector] Fixed Position locked at: " .. tostring(fixedDestPos))
                end
            end
            
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if not State.Enabled then break end
                
                if selectedLookup[item.Name] and item.Parent then
                    -- Exclude Nearby check (only for Player/OtherPlayer destination)
                    if shouldExcludeNearby then
                        local excludeCenter = nil
                        
                        if State.FixedPositionEnabled and State.FixedPositionVector then
                            excludeCenter = State.FixedPositionVector
                        else
                            local playerChar = LocalPlayer.Character
                            if playerChar and playerChar:FindFirstChild("HumanoidRootPart") then
                                excludeCenter = playerChar.HumanoidRootPart.Position
                            end
                        end
                        
                        if excludeCenter then
                            local itemPos = item:GetPivot().Position
                            -- Ignore Y axis for distance check (optional, but good for flat circles)
                            local distance = (Vector3.new(itemPos.X, 0, itemPos.Z) - Vector3.new(excludeCenter.X, 0, excludeCenter.Z)).Magnitude
                            -- Full 3D distance check matches visual circle better in 3D space usually
                            distance = (itemPos - excludeCenter).Magnitude
                            
                            if distance < State.ExcludeRadius then
                                skippedNearby = skippedNearby + 1
                                continue -- Skip this item
                            end
                        end
                    end
                    
                    local limit = State.QuantityLimits[item.Name] or State.GlobalLimit
                    collectedCounts[item.Name] = (collectedCounts[item.Name] or 0)
                    
                    if collectedCounts[item.Name] < limit then
                        local destPos = fixedDestPos -- Use fixed position if set
                        
                        if not destPos then
                            -- Get FRESH destination for each item
                            local currentDest = getDestinationObject()
                            destPos = currentDest and getCenterPosition(currentDest)
                            if destPos then
                                local baseHeight = getBaseHeightOffset()
                                destPos = destPos + Vector3.new(0, baseHeight + State.DropHeight, 0)
                            end
                        end
                        
                        if destPos then
                            if collectItem(item, destPos) then
                                collectedCounts[item.Name] = collectedCounts[item.Name] + 1
                                totalCollected = totalCollected + 1
                                if userDelay > 0 then task.wait(userDelay) end
                            end
                        end
                    end
                end
            end
            
            -- Notify result
            if totalCollected == 0 and skippedNearby == 0 then
                warn("[ItemCollector] No matching items found in map!")
            elseif totalCollected == 0 and skippedNearby > 0 then
                warn("[ItemCollector] All " .. skippedNearby .. " items were too close (excluded).")
            else
                local msg = "[ItemCollector] Collected " .. totalCollected .. " items."
                if skippedNearby > 0 then
                    msg = msg .. " (Skipped " .. skippedNearby .. " nearby)"
                end
                print(msg)
            end
        end
        
        -- Cleanup thread using coroutine.running() since 'thread' var may not be accessible
        local currentThread = coroutine.running()
        for i = #State.Threads, 1, -1 do
            if State.Threads[i] == currentThread then
                table.remove(State.Threads, i)
                break
            end
        end
        
        State.Enabled = false
        print("[ItemCollector] Collection Thread Finished. Active threads: " .. #State.Threads)
    end)
    
    table.insert(State.Threads, thread)
    print("[ItemCollector] Started Collection Thread.")
end

function ItemCollector.Stop()
    if not State.Enabled then return end
    cleanup()
    print("[ItemCollector] Process Stopped by User.")
end

function ItemCollector.Cleanup()
    cleanup()
    clearPreview()
    State.ItemCache = {}
    State.SelectedItems = {}
    State.CollectedCount = 0
end

function ItemCollector.Init(deps)
    deps = deps or {}
    Remote = deps.Remote
    local existing = workspace:FindFirstChild("ItemCollectorPreview")
    if existing then existing:Destroy() end
end

return ItemCollector
