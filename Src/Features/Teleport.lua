--[[
    Features/Teleport.lua
    Teleport System for Rescue Missions
    - Scans for "Lost Child" entities
    - Handles Safe Teleport (Anti-Void + Streaming Support)
]]

local Teleport = {}

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Configuration
local CONFIG = {
    CampfirePath = "Map.Campground.MainFire.InnerTouchZone",
    ScanPath = "Characters", -- workspace.Characters
    ChildNamePattern = "Lost Child",
    
    -- Landmark Teleport Locations
    LANDMARKS = {
        { 
            Name = "Stronghold", 
            Path = "Map.Landmarks.Stronghold.Functional.EntryDoors",
        },
        { 
            Name = "Fairy House", 
            Path = "Map.Landmarks.Fairy House.Fairy",
        },
        { 
            Name = "Enter HardMode", 
            Path = "Map.Landmarks.Research Outpost.Functional.Screens3",
            HardMode = true,
        },
        { 
            Name = "Tool Workshop", 
            Path = "Map.Landmarks.ToolWorkshop",
        },
        { 
            Name = "Fairy Tree", 
            Path = "Map.Landmarks.Fairy Tree.Sign",
        },
    },
}

-- State
local State = {
    IsTeleporting = false,
}

function Teleport.GetStaticTargets()
    return CONFIG.StaticTargets
end

-- Helper: Get Instance from Path String
local function getInstance(pathStr)
    local segments = string.split(pathStr, ".")
    local current = Workspace
    for _, name in ipairs(segments) do
        local next = current:FindFirstChild(name)
        if not next then return nil end
        current = next
    end
    return current
end

-- Helper: Search for landmark by name in workspace.Map.Landmarks
local function findLandmarkByName(landmarkName)
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return nil end
    
    local landmarksFolder = mapFolder:FindFirstChild("Landmarks")
    if not landmarksFolder then return nil end
    
    -- Search for matching landmark
    for _, child in ipairs(landmarksFolder:GetDescendants()) do
        if string.find(child.Name, landmarkName, 1, true) then
            if child:IsA("BasePart") or child:IsA("Model") then
                return child
            end
        end
    end
    
    -- Try direct child
    local directChild = landmarksFolder:FindFirstChild(landmarkName)
    if directChild then return directChild end
    
    return nil
end

function Teleport.ScanChildren(doPreload)
    -- Pre-load known locations if requested (Bypasses StreamingEnabled)
    if doPreload then
        local player = Players.LocalPlayer
        for i, pos in ipairs(CONFIG.StaticTargets) do -- Use StaticTargets for preload
            pcall(function()
                player:RequestStreamAroundAsync(pos.Position) -- Access Position field
            end)
            task.wait(0.1)
        end
        task.wait(1)
    end

    local found = {}
    local charFolder = Workspace:FindFirstChild(CONFIG.ScanPath)
    
    if not charFolder then
        return found
    end
    
    for _, model in ipairs(charFolder:GetChildren()) do
        if string.find(model.Name, CONFIG.ChildNamePattern) then
            local isLost = model:GetAttribute("Lost")
            local kidId = model:GetAttribute("KidId") or "Unknown"
            local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            
            if isLost == true and root then
                 table.insert(found, {
                    Name = model.Name .. " (" .. kidId .. ")",
                    Value = model, 
                    Position = root.Position
                })
            end
        end
    end
    
    return found
end

function Teleport.TeleportTo(targetInstanceOrCFrame, heightOffset)
    if State.IsTeleporting then return end
    State.IsTeleporting = true
    
    local player = Players.LocalPlayer
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    if not root then 
        State.IsTeleporting = false
        return 
    end
    
    -- Resolve Target
    local targetPos
    if typeof(targetInstanceOrCFrame) == "Vector3" then
        targetPos = targetInstanceOrCFrame
    elseif typeof(targetInstanceOrCFrame) == "CFrame" then
        targetPos = targetInstanceOrCFrame.Position
    elseif typeof(targetInstanceOrCFrame) == "Instance" then
        if targetInstanceOrCFrame:IsA("Model") then
            if targetInstanceOrCFrame.PrimaryPart then
                targetPos = targetInstanceOrCFrame.PrimaryPart.Position
            elseif targetInstanceOrCFrame:FindFirstChild("HumanoidRootPart") then
                targetPos = targetInstanceOrCFrame.HumanoidRootPart.Position
            end
        elseif targetInstanceOrCFrame:IsA("BasePart") then
            targetPos = targetInstanceOrCFrame.Position
        end
    elseif typeof(targetInstanceOrCFrame) == "Vector3" then
        targetPos = targetInstanceOrCFrame
    end
    
    if not targetPos then
        warn("[Teleport] Invalid target")
        State.IsTeleporting = false
        return
    end
    
    -- Default height offset if not provided
    heightOffset = heightOffset or 3
    
    -- Safe Teleport Sequence
    task.spawn(function()
        -- 1. Freeze
        if root.Anchored == false then
            root.Anchored = true
        end
        
        -- 2. Request Stream (Critical for large maps)
        pcall(function()
            player:RequestStreamAroundAsync(targetPos)
        end)
        
        -- 3. Teleport (With custom height offset)
        root.CFrame = CFrame.new(targetPos + Vector3.new(0, heightOffset, 0))
        
        -- 4. Wait for ground/geometry
        task.wait(0.5)
        
        -- 5. Unfreeze
        root.Anchored = false
        State.IsTeleporting = false
    end)
end

function Teleport.TeleportToCampfire()
    local campfire = getInstance(CONFIG.CampfirePath)
    if campfire then
        -- Teleport with +5 studs height offset
        Teleport.TeleportTo(campfire, 5)
        return true
    else
        warn("[Teleport] Campfire not found at: " .. CONFIG.CampfirePath)
        return false
    end
end

function Teleport.Init()
    print("[Teleport] Initialized")
end

-- ============================================
-- PLAYER TELEPORT
-- ============================================

-- Get list of other players (excluding LocalPlayer)
function Teleport.GetOtherPlayers()
    local list = {}
    local localPlayer = Players.LocalPlayer
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            table.insert(list, player.Name)
        end
    end
    
    table.sort(list)
    return list
end

-- Teleport to another player by name
function Teleport.TeleportToPlayer(playerName)
    if not playerName or playerName == "" then
        warn("[Teleport] No player name provided")
        return false
    end
    
    local targetPlayer = Players:FindFirstChild(playerName)
    if not targetPlayer then
        warn("[Teleport] Player not found: " .. playerName)
        return false
    end
    
    local targetChar = targetPlayer.Character
    local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    
    if not targetHRP then
        warn("[Teleport] Target player has no character: " .. playerName)
        return false
    end
    
    Teleport.TeleportTo(targetHRP.Position, 3)
    return true
end

-- Get safe position near a Part/Model (anti-stuck)
local function getSafeTeleportPosition(targetInstance)
    if not targetInstance then return nil end
    
    local targetPos
    
    -- 1. Get target position
    if targetInstance:IsA("Model") then
        local success, cf, size = pcall(function()
            return targetInstance:GetBoundingBox()
        end)
        if success and cf then
            targetPos = cf.Position
        else
            -- Fallback for models without bounding box
            local primary = targetInstance.PrimaryPart or targetInstance:FindFirstChildWhichIsA("BasePart")
            if primary then
                targetPos = primary.Position
            end
        end
    elseif targetInstance:IsA("BasePart") then
        targetPos = targetInstance.Position
    end
    
    if not targetPos then return nil end
    
    -- 2. For indoor landmarks, teleport directly to target
    return targetPos
end

-- Get list of landmarks for UI
function Teleport.GetLandmarks()
    return CONFIG.LANDMARKS
end

-- Teleport to a landmark by name
function Teleport.TeleportToLandmark(landmarkName)
    for _, landmark in ipairs(CONFIG.LANDMARKS) do
        if landmark.Name == landmarkName then
            -- 1. Try configured path first
            local target = getInstance(landmark.Path)
            
            -- 2. If path fails, try fallback search by name
            if not target then
                target = findLandmarkByName(landmark.Name)
            end
            
            -- 3. If still not found, try searching parent folder name
            if not target then
                local pathParts = string.split(landmark.Path, ".")
                if #pathParts >= 3 then
                    local parentName = pathParts[3]
                    target = findLandmarkByName(parentName)
                end
            end
            
            if target then
                -- Wrap in pcall to catch any errors
                local success, err = pcall(function()
                    -- Get position for streaming
                    local targetPos
                    if target:IsA("BasePart") then
                        targetPos = target.Position
                    elseif target:IsA("Model") then
                        local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
                        if primary then
                            targetPos = primary.Position
                        end
                    end
                    
                    -- Request stream (like Lost Child teleport)
                    if targetPos then
                        pcall(function()
                            Players.LocalPlayer:RequestStreamAroundAsync(targetPos)
                        end)
                        task.wait(0.2)
                    end
                    
                    -- Use safe position calculation
                    local safePos = getSafeTeleportPosition(target)
                    if safePos then
                        Teleport.TeleportTo(safePos, 0)
                    else
                        Teleport.TeleportTo(target, 8)
                    end
                end)
                
                if not success then
                    -- Emergency fallback - teleport directly to target position
                    pcall(function()
                        local pos
                        if target:IsA("BasePart") then
                            pos = target.Position
                        elseif target:IsA("Model") then
                            local part = target:FindFirstChildWhichIsA("BasePart")
                            if part then pos = part.Position end
                        end
                        if pos then
                            Teleport.TeleportTo(pos + Vector3.new(0, 5, 0), 0)
                        end
                    end)
                end
                
                return true, nil
            else
                return false, "Location not found"
            end
        end
    end
    return false, "Landmark not in config"
end

return Teleport
