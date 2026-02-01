--[[
    Features/ItemCollector.lua
    Auto-collect items from workspace.Items to selected destination
]]

local ItemCollector = {}

-- Services
local Players = game:GetService("Players")

-- Constants
local LocalPlayer = Players.LocalPlayer
local ITEMS_FOLDER = "Items"

-- Speed Presets (delay between drags)
local SPEED_PRESETS = {
    Instant = nil,   -- task.wait() = 1 frame (~0.016s)
    Fast = 0.05,     -- 30ms, ~33 items/sec
    Normal = 0.1,    -- 100ms, 10 items/sec
    Slow = 0.3,      -- 300ms, ~3 items/sec
}

-- Dependencies (injected)
local Remote = nil

-- State
local State = {
    Enabled = false,
    Threads = {},            -- Multiple parallel collection threads
    ItemCache = {},         -- {["Log"] = {count=100, items={item1, item2...}}}
    SelectedItems = {},     -- {"Log", "Coal"} selected item types
    QuantityLimits = {},    -- {["Log"] = 50, ["Coal"] = 100}
    GlobalLimit = 50,       -- Default max per type
    Destination = "Player", -- Player/Campfire/Scrapper/OtherPlayer
    TargetPlayer = "",      -- For OtherPlayer mode
    Speed = "Fast",       -- Instant/Fast/Normal/Slow
    DropHeight = 0,         -- Height offset for dropping items (0-20)
    CollectedCount = 0,     -- Session counter
    -- Organization Mode
    OrganizeEnabled = false, -- Toggle for organization mode
    OrganizeMode = "Grid",   -- Grid/Line
    GridSpacing = 1,         -- Gap between items (studs) - default 1
    MaxLayers = 1,           -- Vertical stacking layers (1-2)
    PreviewEnabled = false,
    PreviewFolder = nil,
    -- Failure tracking
    ConsecutiveFailures = 0,
    MAX_CONSECUTIVE_FAILURES = 5,
    -- Callbacks
    OnScanCallback = nil,
    -- Auto Rescan
    AutoRescanEnabled = false,
    AutoRescanThread = nil,
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
    end
    return nil
end

local function getDelay()
    local preset = SPEED_PRESETS[State.Speed]
    return preset -- nil = task.wait() will yield 1 frame
end

-- Get base height offset for destination (Campfire/Scrapper need extra height)
local function getBaseHeightOffset()
    if State.Destination == "Campfire" or State.Destination == "Scrapper" then
        return 20  -- Base height of 8 studs for Campfire/Scrapper
    end
    return 0
end

-- Get center position from a destination object (reduces code duplication)
local function getCenterPosition(dest)
    if not dest then return nil end
    
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
-- PREVIEW & GRID FUNCTIONS
-- ============================================

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
    return Vector3.new(1, 1, 1) -- Default size (compact)
end

local function generateGridPositions(center, itemCount, itemSize, spacing)
    local positions = {}
    if itemCount == 0 then return positions end
    
    local maxLayers = math.clamp(State.MaxLayers or 1, 1, 2)
    local itemsPerLayer = math.ceil(itemCount / maxLayers)
    
    -- Find optimal grid dimensions for items per layer
    -- Goal: Square-ish grid, allow up to 20% waste for better shape
    local bestCols = 1
    local bestRows = itemsPerLayer
    local bestScore = 999999
    
    -- Start from square root for most balanced starting point
    local sqrtItems = math.sqrt(itemsPerLayer)
    
    for cols = 1, itemsPerLayer do
        local rows = math.ceil(itemsPerLayer / cols)
        local totalCells = cols * rows
        local waste = totalCells - itemsPerLayer
        local wastePercent = waste / itemsPerLayer
        
        -- Allow up to 30% waste for better grid shapes
        if wastePercent <= 0.3 then
            -- Score: prioritize balanced aspect ratio
            -- Lower ratio = more square = better
            local ratio = math.max(cols, rows) / math.max(math.min(cols, rows), 1)
            
            -- Penalize extreme shapes heavily
            local score = ratio * 100 + waste
            
            if score < bestScore then
                bestCols = cols
                bestRows = rows
                bestScore = score
            end
        end
        
        -- Early exit if we've gone past optimal range
        if cols > sqrtItems * 2 then
            break
        end
    end
    
    local cols = bestCols
    local rows = bestRows
    
    -- Use sizes for tighter packing
    local sizeX = itemSize.X * 0.5
    local sizeZ = math.min(itemSize.Z, itemSize.X * 1.2) * 0.5
    local sizeY = itemSize.Y * 0.8 -- Height for stacking
    
    local cellWidth = sizeX + spacing
    local cellDepth = sizeZ + spacing
    local layerHeight = sizeY + 0.5 -- Gap between layers
    
    local totalWidth = (cols - 1) * cellWidth
    local totalDepth = (rows - 1) * cellDepth
    local startX = center.X - totalWidth / 2
    local startZ = center.Z - totalDepth / 2
    
    -- Calculate actual layers needed
    local actualLayers = math.min(maxLayers, math.ceil(itemCount / (cols * rows)))
    
    -- Log grid info
    print("[OP] ItemCollector: Grid = " .. cols .. "x" .. rows .. "x" .. actualLayers .. " layers (" .. (cols * rows * actualLayers) .. " cells)")
    
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
    
    -- Use compact sizing (same as Grid for consistency)
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
    
    -- Get destination center
    local dest = getDestinationObject()
    if not dest then return end
    
    local center = getCenterPosition(dest)
    if not center then return end
    
    -- Count selected items
    local itemCount = 0
    local sampleItem = nil
    for _, itemName in ipairs(State.SelectedItems) do
        local cacheEntry = State.ItemCache[itemName]
        if cacheEntry then
            local limit = State.QuantityLimits[itemName] or State.GlobalLimit
            itemCount = itemCount + math.min(cacheEntry.count, limit)
            if not sampleItem and cacheEntry.items[1] then
                sampleItem = cacheEntry.items[1]
            end
        end
    end
    
    if itemCount == 0 then
        if State.PreviewFolder then clearPreview() end
        return
    end
    
    -- Get item size for spacing
    local itemSize = getItemBoundingBox(sampleItem)
    
    -- Generate positions
    local positions
    if State.OrganizeMode == "Grid" then
        positions = generateGridPositions(center, itemCount, itemSize, State.GridSpacing)
    else -- Line
        positions = generateLinePositions(center, itemCount, itemSize, State.GridSpacing)
    end
    
    -- Ensure folder exists
    if not State.PreviewFolder then
        State.PreviewFolder = Instance.new("Folder")
        State.PreviewFolder.Name = "ItemCollectorPreview"
        State.PreviewFolder.Parent = workspace
    end
    
    -- Create/update preview parts
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
    
    -- Destroy excess parts (not just hide)
    for i = #positions + 1, #PreviewPool do
        if PreviewPool[i] then
            pcall(function() PreviewPool[i]:Destroy() end)
            PreviewPool[i] = nil
        end
    end
end

-- Debounce for preview updates (prevents lag from rapid slider changes)
-- Must be defined AFTER updatePreview to avoid nil reference
local previewDebounce = nil
local function queuePreviewUpdate()
    if previewDebounce then
        pcall(task.cancel, previewDebounce)
    end
    previewDebounce = task.delay(0.05, function()
        updatePreview()
        previewDebounce = nil
    end)
end

-- ============================================
-- CORE FUNCTIONS
-- ============================================

-- Scan all items in workspace.Items and group by name
function ItemCollector.ScanItems()
    State.ItemCache = {}
    
    local folder = getItemsFolder()
    if not folder then
        print("[OP] ItemCollector: workspace.Items not found")
        return {}
    end
    
    for _, item in ipairs(folder:GetChildren()) do
        local name = item.Name
        
        -- TEMPORARY: Blacklist disabled for debugging - show ALL items
        -- local nameLower = name:lower()
        -- if nameLower:find("item chest") or nameLower:find("crate") then
        --     continue
        -- end
        
        if not State.ItemCache[name] then
            State.ItemCache[name] = {
                count = 0,
                items = {}
            }
        end
        State.ItemCache[name].count = State.ItemCache[name].count + 1
        table.insert(State.ItemCache[name].items, item)
    end
    
    -- Count total
    local totalItems = 0
    local totalTypes = 0
    for name, data in pairs(State.ItemCache) do
        totalItems = totalItems + data.count
        totalTypes = totalTypes + 1
    end
    
    print("[OP] ItemCollector: Scanned " .. totalItems .. " items (" .. totalTypes .. " types)")
    
    -- Debug: Print all item names sorted alphabetically (combined to avoid scramble)
    local sortedNames = {}
    for name, _ in pairs(State.ItemCache) do
        table.insert(sortedNames, name)
    end
    table.sort(sortedNames)
    
    local lines = {"=== ALL ITEMS (" .. #sortedNames .. " types) ==="}
    for i, name in ipairs(sortedNames) do
        local count = State.ItemCache[name].count
        table.insert(lines, string.format("%02d. %s (%d)", i, name, count))
    end
    table.insert(lines, "=== END LIST ===")
    print("[OP]\n" .. table.concat(lines, "\n"))
    
    -- Trigger callback if set
    if State.OnScanCallback then
        task.spawn(function()
            State.OnScanCallback(State.ItemCache)
        end)
    end
    
    return State.ItemCache
end

-- Get formatted list for dropdown: {"Log (1000)", "Coal (500)"}
function ItemCollector.GetItemList()
    local list = {}
    
    -- Sort by name
    local names = {}
    for name, _ in pairs(State.ItemCache) do
        table.insert(names, name)
    end
    table.sort(names)
    
    for _, name in ipairs(names) do
        local data = State.ItemCache[name]
        table.insert(list, name .. " (" .. data.count .. ")")
    end
    
    return list
end

-- Get raw item names (without count)
function ItemCollector.GetItemNames()
    local names = {}
    for name, _ in pairs(State.ItemCache) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Parse "Log (1000)" to "Log"
function ItemCollector.ParseItemName(formatted)
    if not formatted then return nil end
    local name = string.match(formatted, "^(.+) %(")
    return name or formatted
end

-- Set selected items (from multi-dropdown)
function ItemCollector.SetSelectedItems(selected)
    State.SelectedItems = {}
    
    if type(selected) == "table" then
        for key, value in pairs(selected) do
            local name = nil
            if type(key) == "string" and value == true then
                -- Format: {["Log (100)"] = true}
                name = ItemCollector.ParseItemName(key)
            elseif type(key) == "number" and type(value) == "string" then
                -- Format: {"Log (100)", "Coal (50)"}
                name = ItemCollector.ParseItemName(value)
            end
            if name then
                table.insert(State.SelectedItems, name)
            end
        end
    end
    
    -- Log selected items with names
    if #State.SelectedItems > 0 then
        print("[OP] ItemCollector: Selected: " .. table.concat(State.SelectedItems, ", "))
    else
        print("[OP] ItemCollector: Selected: (none)")
    end
end

-- Set quantity limit for specific item
function ItemCollector.SetQuantity(itemName, qty)
    if itemName and qty then
        State.QuantityLimits[itemName] = qty
    end
end

-- Set global limit (default max per type)
function ItemCollector.SetGlobalLimit(qty)
    State.GlobalLimit = qty or 50
    print("[OP] ItemCollector: Global limit = " .. State.GlobalLimit)
end

-- Set destination
function ItemCollector.SetDestination(dest)
    State.Destination = dest or "Player"
    print("[OP] ItemCollector: Destination = " .. State.Destination)
end

-- Set target player name (for OtherPlayer mode)
function ItemCollector.SetTargetPlayer(name)
    State.TargetPlayer = name or ""
end

-- Set callback for when scan completes (for UI updates)
function ItemCollector.SetOnScanCallback(callback)
    State.OnScanCallback = callback
end

-- Set speed
function ItemCollector.SetSpeed(speed)
    if SPEED_PRESETS[speed] ~= nil or speed == "Instant" then
        State.Speed = speed
        print("[OP] ItemCollector: Speed = " .. speed)
    end
end

-- Set drop height
function ItemCollector.SetDropHeight(height)
    State.DropHeight = math.clamp(height or 0, 0, 20)
    queuePreviewUpdate()
end

-- Organization Mode Setters
function ItemCollector.SetOrganizeEnabled(enabled)
    State.OrganizeEnabled = enabled
    if enabled then
        print("[OP] ItemCollector: Organization Mode ON")
    else
        print("[OP] ItemCollector: Organization Mode OFF")
        clearPreview()
    end
    queuePreviewUpdate()
end

function ItemCollector.SetOrganizeMode(mode)
    if mode == "Grid" or mode == "Line" then
        State.OrganizeMode = mode
        print("[OP] ItemCollector: Organize Mode = " .. mode)
        queuePreviewUpdate()
    end
end

function ItemCollector.SetGridSpacing(spacing)
    State.GridSpacing = math.clamp(spacing or 1, 0, 20)
    queuePreviewUpdate()
end

function ItemCollector.SetMaxLayers(layers)
    State.MaxLayers = math.clamp(layers or 1, 1, 2)
    print("[OP] ItemCollector: Max Layers = " .. State.MaxLayers)
    queuePreviewUpdate()
end

function ItemCollector.TogglePreview(enabled)
    State.PreviewEnabled = enabled
    if enabled then
        updatePreview()
    else
        clearPreview()
    end
end

function ItemCollector.ClearPreview()
    clearPreview()
end

-- Get current stats
function ItemCollector.GetStats()
    return {
        enabled = State.Enabled,
        collected = State.CollectedCount,
        selectedCount = #State.SelectedItems,
        destination = State.Destination,
        speed = State.Speed,
    }
end

-- Get selected item names (for UI updates)
function ItemCollector.GetSelectedItems()
    return State.SelectedItems
end

-- Auto Rescan toggle (rescans after each collection finishes)
function ItemCollector.SetAutoRescan(enabled)
    State.AutoRescanEnabled = enabled
    
    if enabled then
        print("[OP] ItemCollector: Auto Rescan ON (after collection)")
    else
        print("[OP] ItemCollector: Auto Rescan OFF")
    end
end

-- Lightweight scan - only count SELECTED items (much faster!)
function ItemCollector.ScanSelectedOnly()
    if #State.SelectedItems == 0 then return end
    
    local itemsFolder = getItemsFolder()
    if not itemsFolder then return end
    
    -- Build lookup for selected items
    local selectedLookup = {}
    for _, name in ipairs(State.SelectedItems) do
        selectedLookup[name] = true
        -- Update cache entry
        State.ItemCache[name] = {
            count = 0,
            items = {}
        }
    end
    
    -- Only iterate and count selected types
    for _, item in ipairs(itemsFolder:GetChildren()) do
        local name = item.Name
        if selectedLookup[name] then
            State.ItemCache[name].count = State.ItemCache[name].count + 1
            table.insert(State.ItemCache[name].items, item)
        end
    end
    
    -- Auto-unselect items with count 0
    local newSelected = {}
    local removed = {}
    for _, name in ipairs(State.SelectedItems) do
        if State.ItemCache[name] and State.ItemCache[name].count > 0 then
            table.insert(newSelected, name)
        else
            table.insert(removed, name)
            -- Remove from cache so it doesn't show in dropdown
            State.ItemCache[name] = nil
        end
    end
    
    local itemsWereRemoved = #removed > 0
    if itemsWereRemoved then
        State.SelectedItems = newSelected
        print("[OP] ItemCollector: Auto-removed (0 left): " .. table.concat(removed, ", "))
    end
    
    -- Trigger callback with partial cache (selected only)
    -- Pass flag to indicate if items were removed (so UI can refresh dropdown)
    if State.OnScanCallback then
        task.spawn(function()
            State.OnScanCallback(State.ItemCache, itemsWereRemoved)
        end)
    end
end

-- ============================================
-- COLLECT LOGIC
-- ============================================

local function collectItem(item, targetPos)
    if not item or not item.Parent then return false end
    if not Remote then return false end
    
    -- Verify item is still in workspace.Items (not already collected)
    local itemsFolder = getItemsFolder()
    if not itemsFolder or item.Parent ~= itemsFolder then
        return false  -- Item already moved/collected
    end
    
    -- Get destination position
    local destPos = targetPos
    
    if not destPos then
        -- Default behavior: get destination from state
        local dest = getDestinationObject()
        if not dest then return false end
        
        if dest:IsA("Model") and dest:FindFirstChild("HumanoidRootPart") then
            destPos = dest.HumanoidRootPart.Position
        elseif dest:IsA("BasePart") then
            destPos = dest.Position
        elseif dest:IsA("Model") and dest.PrimaryPart then
            destPos = dest.PrimaryPart.Position
        else
            local part = dest:FindFirstChildWhichIsA("BasePart")
            if part then
                destPos = part.Position
            else
                return false
            end
        end
        
        -- Apply height offset (base height + user drop height)
        local baseHeight = getBaseHeightOffset()
        destPos = destPos + Vector3.new(0, baseHeight + State.DropHeight, 0)
    end
    
    -- Start dragging
    Remote.RequestStartDraggingItem(item)
    
    -- Teleport item to destination
    local itemPart = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart")
    if itemPart then
        itemPart.CFrame = CFrame.new(destPos)
    end
    
    -- Delay for server processing (0.03s more reliable than 0.01s)
    task.wait(0.08)
    
    -- Stop dragging
    Remote.StopDraggingItem(item)
    
    State.CollectedCount = State.CollectedCount + 1
    return true
end

function ItemCollector.Start()
    -- Allow parallel collection (no guard clause)
    
    -- Auto-rescan if enabled (get fresh counts before collecting)
    if State.AutoRescanEnabled then
        ItemCollector.ScanSelectedOnly()
    end
    
    -- Validate
    if #State.SelectedItems == 0 then
        warn("[OP] ItemCollector: No items selected!")
        return
    end
    
    -- Validate OtherPlayer destination
    if State.Destination == "OtherPlayer" then
        if not State.TargetPlayer or State.TargetPlayer == "" then
            warn("[OP] ItemCollector: No target player selected! Choose from dropdown.")
            return
        end
        local targetPlayer = Players:FindFirstChild(State.TargetPlayer)
        if not targetPlayer then
            warn("[OP] ItemCollector: Target player '" .. State.TargetPlayer .. "' not found!")
            return
        end
    end
    
    local dest = getDestinationObject()
    if not dest then
        warn("[OP] ItemCollector: Destination not found!")
        return
    end
    
    clearPreview() -- Clear preview when starting
    State.Enabled = true
    
    local threadId = #State.Threads + 1
    local modeStr = State.OrganizeEnabled and ("Organize=" .. State.OrganizeMode) or "Stack"
    local itemsStr = table.concat(State.SelectedItems, ", ")
    print("[OP] ItemCollector: Thread #" .. threadId .. " ON | Items: " .. itemsStr .. " | Dest: " .. State.Destination .. ", Speed: " .. State.Speed .. ", Mode: " .. modeStr)
    
    local thread = task.spawn(function()
        local delay = getDelay()
        
        -- Organization mode only works for Player/OtherPlayer destinations
        local canUseOrganizedMode = (State.Destination == "Player" or State.Destination == "OtherPlayer")
        local useOrganizedMode = State.OrganizeEnabled and canUseOrganizedMode
        
        if not canUseOrganizedMode and State.OrganizeEnabled then
            print("[OP] ItemCollector: Organization mode disabled for " .. State.Destination .. " (only works for Player/OtherPlayer)")
        end
        
        if useOrganizedMode then
            -- Organized mode: generate positions first, then place items
            
            -- Get center position (using helper function)
            local center = getCenterPosition(dest)
            
            if not center then
                warn("[OP] ItemCollector: Could not get center position!")
                cleanup() -- Proper cleanup
                return
            end
            
            -- Collect all items to place
            local itemsToPlace = {}
            for _, itemName in ipairs(State.SelectedItems) do
                local cacheEntry = State.ItemCache[itemName]
                if cacheEntry and cacheEntry.items then
                    local limit = State.QuantityLimits[itemName] or State.GlobalLimit
                    local count = 0
                    for _, item in ipairs(cacheEntry.items) do
                        if count >= limit then break end
                        if item and item.Parent then
                            table.insert(itemsToPlace, item)
                            count = count + 1
                        end
                    end
                end
            end
            
            if #itemsToPlace == 0 then
                print("[OP] ItemCollector: No valid items to collect!")
                cleanup() -- Proper cleanup
                return
            end
            
            -- Get sample item size
            local itemSize = getItemBoundingBox(itemsToPlace[1])
            
            -- Generate positions
            local positions
            if State.OrganizeMode == "Grid" then
                positions = generateGridPositions(center, #itemsToPlace, itemSize, State.GridSpacing)
            else -- Line
                positions = generateLinePositions(center, #itemsToPlace, itemSize, State.GridSpacing)
            end
            
            -- Place each item at its FIXED position (captured at start)
            State.ConsecutiveFailures = 0  -- Reset failure counter
            
            for i, item in ipairs(itemsToPlace) do
                if not State.Enabled then break end
                
                if item and item.Parent and positions[i] then
                    local success = collectItem(item, positions[i])
                    
                    -- Track failures
                    if success then
                        State.ConsecutiveFailures = 0
                    else
                        State.ConsecutiveFailures = State.ConsecutiveFailures + 1
                        warn("[OP] ItemCollector: Failed (" .. State.ConsecutiveFailures .. "/" .. State.MAX_CONSECUTIVE_FAILURES .. ")")
                        
                        if State.ConsecutiveFailures >= State.MAX_CONSECUTIVE_FAILURES then
                            warn("[OP] ItemCollector: Too many consecutive failures, stopping!")
                            break
                        end
                    end
                    
                    if delay then
                        task.wait(delay)
                    else
                        task.wait()
                    end
                end
            end
        else
            -- Stack mode: FIXED position (captured at start, same as Grid/Line)
            State.ConsecutiveFailures = 0  -- Reset failure counter
            
            -- Capture FIXED destination position at start (using helper function)
            local fixedDestPos = getCenterPosition(dest)
            
            if not fixedDestPos then
                warn("[OP] ItemCollector: Could not get destination position!")
                cleanup()
                return
            end
            
            -- Apply height offset (base height + user drop height)
            local baseHeight = getBaseHeightOffset()
            fixedDestPos = fixedDestPos + Vector3.new(0, baseHeight + State.DropHeight, 0)
            
            print("[OP] ItemCollector: Stack position FIXED at " .. tostring(fixedDestPos))
            
            for _, itemName in ipairs(State.SelectedItems) do
                if not State.Enabled then break end
                
                local cacheEntry = State.ItemCache[itemName]
                if cacheEntry and cacheEntry.items then
                    local limit = State.QuantityLimits[itemName] or State.GlobalLimit
                    local collected = 0
                    
                    for _, item in ipairs(cacheEntry.items) do
                        if not State.Enabled then break end
                        if collected >= limit then break end
                        
                        if item and item.Parent then
                            local success = collectItem(item, fixedDestPos)  -- Use FIXED position!
                            
                            -- Track failures
                            if success then
                                State.ConsecutiveFailures = 0
                                collected = collected + 1
                            else
                                State.ConsecutiveFailures = State.ConsecutiveFailures + 1
                                warn("[OP] ItemCollector: Failed (" .. State.ConsecutiveFailures .. "/" .. State.MAX_CONSECUTIVE_FAILURES .. ")")
                                
                                if State.ConsecutiveFailures >= State.MAX_CONSECUTIVE_FAILURES then
                                    warn("[OP] ItemCollector: Too many consecutive failures, stopping!")
                                    State.Enabled = false
                                    break
                                end
                            end
                            
                            if delay then
                                task.wait(delay)
                            else
                                task.wait()
                            end
                        end
                    end
                end
            end
        end
        
        -- Done - show per-item collected counts
        local itemsStr = table.concat(State.SelectedItems, ", ")
        print("[OP] ItemCollector: Finished! Total collected: " .. State.CollectedCount .. " (" .. itemsStr .. ")")
        
        -- Auto-rescan if enabled (after each thread finishes)
        if State.AutoRescanEnabled then
            task.defer(function()
                ItemCollector.ScanSelectedOnly()
            end)
        end
        
        -- Remove this thread from active threads when done
        for i, t in ipairs(State.Threads) do
            if t == thread then
                table.remove(State.Threads, i)
                break
            end
        end
        
        -- If no more threads, set Enabled to false and auto-rescan
        if #State.Threads == 0 then
            State.Enabled = false
            -- Auto-rescan to refresh cache after all collections complete
            task.defer(function()
                ItemCollector.ScanItems()
                print("[OP] ItemCollector: Cache refreshed after collection")
            end)
        end
    end)
    
    -- Add thread to tracking array
    table.insert(State.Threads, thread)
end

function ItemCollector.Stop()
    if not State.Enabled then return end
    
    local threadCount = #State.Threads
    cleanup()
    print("[OP] ItemCollector: STOPPED " .. threadCount .. " thread(s) (Collected " .. State.CollectedCount .. " items)")
    
    -- Auto-rescan if enabled
    if State.AutoRescanEnabled then
        task.defer(function()
            ItemCollector.ScanSelectedOnly()
        end)
    end
end

function ItemCollector.Cleanup()
    cleanup()
    clearPreview() -- Prevent memory leak from preview parts
    
    -- Stop auto-rescan
    State.AutoRescanEnabled = false
    if State.AutoRescanThread then
        pcall(task.cancel, State.AutoRescanThread)
        State.AutoRescanThread = nil
    end
    
    State.ItemCache = {}
    State.SelectedItems = {}
    State.QuantityLimits = {}
    State.CollectedCount = 0
end

-- ============================================
-- INIT
-- ============================================
function ItemCollector.Init(deps)
    deps = deps or {}
    Remote = deps.Remote
    print("[OP] ItemCollector: Initialized")
end

return ItemCollector
