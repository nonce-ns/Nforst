--[[
    Features/TreeFarm.lua
    Auto Chop Trees (AXE ONLY)
    
    - Auto-detects equipped axe
    - Chops all trees in range
    - Fixed 75 studs range
]]

local TreeFarm = {}

-- Dependencies
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Utils = nil
local Remote = nil

-- Constants
local RANGE = 75
local CYCLE_DELAY = 0.2  -- Optimized: was 0.1

-- Tree Catalog (display name -> tier required)
-- Tier: 1 = Basic (any axe), 2 = Strong (Strong Axe, Ice Axe)
local TreeCatalog = {
    -- Normal trees
    ["Small Tree"] = 1,
    ["TreeBig1"] = 2,
    ["TreeBig2"] = 2,
    ["TreeBig3"] = 2,
    -- Fairy trees (same tier as normal)
    ["Fairy Small Tree"] = 1,
    ["FairyTreeBig1"] = 2,
    ["FairyTreeBig2"] = 2,
    ["FairyTreeBig3"] = 2,
}

-- Note: CHOP_DELAY removed - using parallel processing now

-- Strong axes that can chop tier 2 trees
local STRONG_AXE_KEYWORDS = {
    "strong", "ice", "chainsaw",
}

-- Axe keyword (required tool)
local AXE_KEYWORD = "axe"

-- State
local State = {
    Enabled = false,
    Thread = nil,
    HitCounter = 0,
    LastBigTreeWarning = 0,
    MapFolder = nil,
}

-- Settings (can be updated via UI)
local Settings = {
    AllowedTrees = {},  -- Empty = all trees allowed
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function isAxe(name)
    if not name then return false end
    return string.find(string.lower(name), AXE_KEYWORD) ~= nil
end

local function isStrongAxe(name)
    if not name then return false end
    local lower = string.lower(name)
    for _, kw in ipairs(STRONG_AXE_KEYWORDS) do
        if string.find(lower, kw) then
            return true
        end
    end
    return false
end

local function getAxeTier(axeName)
    if isStrongAxe(axeName) then
        return 2  -- Can chop tier 1 and 2
    end
    return 1  -- Can only chop tier 1
end

local function getTreeTier(treeName)
    -- Bug #2 fix: Exact match ONLY (removed risky partial matching)
    if TreeCatalog[treeName] then
        return TreeCatalog[treeName]
    end
    
    -- Fallback: keyword-based detection for trees not in catalog
    local lower = string.lower(treeName)
    if string.find(lower, "tree") or string.find(lower, "log") or string.find(lower, "stump") then
        return 1  -- Unknown tree, assume tier 1
    end
    
    -- Not a tree at all
    return 0
end

-- Check if tree is in allowed list
local function isTreeAllowed(treeName)
    -- Empty list = all trees allowed
    if not Settings.AllowedTrees or #Settings.AllowedTrees == 0 then
        return true
    end
    -- Check exact match in allowed list
    for _, allowed in ipairs(Settings.AllowedTrees) do
        if treeName == allowed then
            return true
        end
    end
    return false
end

local function canChopTree(treeName, axeName)
    local treeTier = getTreeTier(treeName)
    local axeTier = getAxeTier(axeName)
    return axeTier >= treeTier
end

-- Get equipped axe via ToolHandle system
local function getEquippedAxe()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    -- Check ToolHandle (weapon sedang dipegang)
    local toolHandle = char:FindFirstChild("ToolHandle")
    if not toolHandle then return nil end
    
    -- Get actual weapon reference from OriginalItem
    local originalItem = toolHandle:FindFirstChild("OriginalItem")
    if not originalItem or not originalItem.Value then return nil end
    
    local weapon = originalItem.Value
    if isAxe(weapon.Name) then
        return weapon
    end
    return nil
end

local function generateHitId()
    State.HitCounter = State.HitCounter + 1
    return tostring(State.HitCounter) .. "_" .. tostring(LocalPlayer.UserId)
end

local function getTargets(axe)
    local targets = {}
    local skippedBigTrees = 0
    
    local root = Utils and Utils.getRoot()
    if not root then return targets, skippedBigTrees end
    
    if not axe then return targets, skippedBigTrees end
    
    -- Bug #1 fix: Improved cache validation with IsDescendantOf
    local foliageFolder = State.MapFolder
    if not foliageFolder or not foliageFolder.Parent or not foliageFolder:IsDescendantOf(Workspace) then
        local mapFolder = Workspace:FindFirstChild("Map")
        if mapFolder then
            foliageFolder = mapFolder:FindFirstChild("Foliage")
        else
            warn("[DEBUG] TreeFarm: 'Map' folder NOT found in Workspace!")
        end
        State.MapFolder = foliageFolder
        if not foliageFolder then
             warn("[DEBUG] TreeFarm: 'Foliage' folder NOT found in Workspace.Map!") 
        end
    end
    if not foliageFolder then return targets, skippedBigTrees end
    
    -- Scan Foliage children directly (trees are NOT in subfolders)
    for _, entity in ipairs(foliageFolder:GetChildren()) do
        if not entity:IsA("Model") then continue end
        
        local treeName = entity.Name
        local treeTier = getTreeTier(treeName)
        
        -- Skip if not a tree (tier 0)
        if treeTier == 0 then continue end
        
        -- Skip if tree not in allowed list (user filter)
        if not isTreeAllowed(treeName) then
            continue  -- Silent skip
        end
        
        -- Check if axe can chop this tree (tier check)
        if not canChopTree(treeName, axe.Name) then
            skippedBigTrees = skippedBigTrees + 1
            continue  -- Silent skip, will show summary later
        end
        
        -- Bug #5 fix: Get Trunk for position with type validation
        local trunk = entity:FindFirstChild("Trunk")
        if not trunk or not trunk:IsA("BasePart") then continue end
        
        -- Check range
        local dist = (trunk.Position - root.Position).Magnitude
        if dist <= RANGE then
            table.insert(targets, {
                Model = entity,
                Distance = dist,
                HitPart = trunk,
            })
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(targets, function(a, b) return a.Distance < b.Distance end)
    
    return targets, skippedBigTrees
end

local function chopTarget(target, axe)
    if not target or not axe then return false end
    if not State.Enabled then return false end
    
    local root = Utils and Utils.getRoot()
    if not root then return false end
    
    local hitId = generateHitId()
    local result = Remote.ToolDamageObject(target.Model, axe, hitId, root.CFrame)
    
    return result and result.Success
end

-- ============================================
-- CLEANUP
-- ============================================
local function cleanup()
    if State.Thread then
        pcall(function() task.cancel(State.Thread) end)
        State.Thread = nil
    end
    State.Enabled = false
    State.MapFolder = nil  -- Reset cache to prevent stale references
    State.HitCounter = 0   -- Bug #3 fix: Reset counter to prevent overflow
    State.LastBigTreeWarning = 0
    State.LastNoAxeWarning = 0
end

-- ============================================
-- PUBLIC API
-- ============================================
function TreeFarm.Init(deps)
    Utils = deps.Utils
    Remote = deps.Remote
    print("[OP] TreeFarm: Initialized (Axe Only, 75 studs)")
end

function TreeFarm.Start()
    if State.Enabled then return end
    
    cleanup()
    State.Enabled = true
    State.LastBigTreeWarning = 0
    
    print("[OP] TreeFarm: ON")
    
    State.Thread = task.spawn(function()
        while State.Enabled do
            -- Get equipped axe via ToolHandle
            local axe = getEquippedAxe()
            
            if not axe then
                -- Tidak pegang axe = idle (skip scan)
                task.wait(CYCLE_DELAY)
                continue
            end
            
            local targets, skippedBigTrees = getTargets(axe)
            
            -- Warn about skipped big trees (cooldown: 30 seconds)
            if skippedBigTrees > 0 then
                local now = os.clock()
                if now - State.LastBigTreeWarning >= 30 then
                    State.LastBigTreeWarning = now
                    warn("[OP] TreeFarm: " .. skippedBigTrees .. " big tree(s) nearby! Equip Strong Axe or Ice Axe to chop them.")
                end
            end
            
            -- Chop all targets (PARALLEL)
            if #targets > 0 then
                for _, target in ipairs(targets) do
                    if not State.Enabled then break end
                    task.spawn(function()
                        if State.Enabled then
                            chopTarget(target, axe)
                        end
                    end)
                end
            end
            
            task.wait(CYCLE_DELAY)
        end
    end)
end

function TreeFarm.Stop()
    if not State.Enabled then return end
    
    cleanup()
    print("[OP] TreeFarm: OFF")
end

function TreeFarm.IsEnabled()
    return State.Enabled
end

function TreeFarm.Cleanup()
    cleanup()
end

-- Update settings from UI
function TreeFarm.UpdateSetting(key, value)
    if key == "AllowedTrees" then
        Settings.AllowedTrees = value or {}
        -- Debug: Show what trees are selected
        if #Settings.AllowedTrees > 0 then
            print("[OP] TreeFarm: Filter ON - " .. table.concat(Settings.AllowedTrees, ", "))
        else
            print("[OP] TreeFarm: Filter OFF - All trees allowed")
        end
    end
end

function TreeFarm.GetTreeCatalog()
    return TreeCatalog
end

return TreeFarm
