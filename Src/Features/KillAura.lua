--[[
    Features/KillAura.lua
    Auto Attack / Kill Aura (MELEE ONLY - SIMPLE)
    
    - Auto-detects equipped melee weapon
    - Fixed 75 studs range
    - Just ON/OFF, no config needed
]]

local KillAura = {}

-- Dependencies
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Utils = nil
local Remote = nil

-- Constants (hardcoded, no config)
local RANGE = 75
local CYCLE_DELAY = 0.1

-- Melee weapon keywords
local MELEE_KEYWORDS = {
    "chainsaw", "axe", "sword", "morningstar", "spear",
}

-- State
local State = {
    Enabled = false,
    Thread = nil,
    HitCounter = 0,
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function isMelee(name)
    if not name then return false end
    local lower = string.lower(name)
    for _, kw in ipairs(MELEE_KEYWORDS) do
        if string.find(lower, kw) then
            return true
        end
    end
    return false
end

-- Get equipped melee via ToolHandle system
local function getEquippedMelee()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    -- Check ToolHandle (weapon sedang dipegang)
    local toolHandle = char:FindFirstChild("ToolHandle")
    if not toolHandle then return nil end
    
    -- Get actual weapon reference from OriginalItem
    local originalItem = toolHandle:FindFirstChild("OriginalItem")
    if not originalItem or not originalItem.Value then return nil end
    
    local weapon = originalItem.Value
    if isMelee(weapon.Name) then
        return weapon
    end
    return nil
end

local function generateHitId()
    State.HitCounter = State.HitCounter + 1
    return tostring(State.HitCounter) .. "_" .. tostring(LocalPlayer.UserId)
end

local function getTargets()
    local targets = {}
    
    local root = Utils and Utils.getRoot()
    if not root then return targets end
    
    -- Scan both Characters and Items folders
    local foldersToScan = {
        Workspace:FindFirstChild("Characters"),
        Workspace:FindFirstChild("Items")
    }
    
    for _, folder in ipairs(foldersToScan) do
        if not folder then continue end
        
        for _, entity in ipairs(folder:GetChildren()) do
            -- Skip if it's any player's character (multiplayer safe)
            if Players:GetPlayerFromCharacter(entity) then
                continue
            end
            
            -- Also skip by checking all player names (extra safety)
            local isPlayer = false
            for _, player in ipairs(Players:GetPlayers()) do
                if entity.Name == player.Name or entity.Name == player.DisplayName then
                    isPlayer = true
                    break
                end
            end
            if isPlayer then continue end
            
            -- Must have Humanoid with health > 0 (skip objects & dead)
            local hum = entity:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then
                continue
            end
            
            -- Get position with type validation
            local entityRoot = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChildWhichIsA("BasePart")
            if not entityRoot or not entityRoot:IsA("BasePart") then
                continue
            end
            
            -- Check range
            local dist = (entityRoot.Position - root.Position).Magnitude
            if dist <= RANGE then
                table.insert(targets, {
                    Model = entity,
                    Distance = dist,
                    HitPart = entityRoot,
                })
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(targets, function(a, b) return a.Distance < b.Distance end)
    
    return targets
end

local function attackTarget(target, weapon)
    if not target or not weapon then return false end
    if not State.Enabled then return false end
    
    local root = Utils and Utils.getRoot()
    if not root then return false end
    
    local hitId = generateHitId()
    local result = Remote.ToolDamageObject(target.Model, weapon, hitId, root.CFrame)
    
    return result and result.Success
end

-- ============================================
-- CLEANUP (Memory Leak Prevention)
-- ============================================
local function cleanup()
    if State.Thread then
        task.cancel(State.Thread)
        State.Thread = nil
    end
    State.Enabled = false
    State.HitCounter = 0  -- Reset counter to prevent overflow
end

-- ============================================
-- PUBLIC API
-- ============================================
function KillAura.Init(deps)
    Utils = deps.Utils
    Remote = deps.Remote
    print("[OP] KillAura: Initialized (Melee Only, 75 studs)")
end

function KillAura.Start()
    if State.Enabled then return end
    
    cleanup()
    State.Enabled = true
    
    print("[OP] KillAura: ON")
    
    State.Thread = task.spawn(function()
        while State.Enabled do
            -- Get equipped melee via ToolHandle
            local weapon = getEquippedMelee()
            
            if weapon then
                -- Scan and attack all targets (PARALLEL)
                local targets = getTargets()
                
                for _, target in ipairs(targets) do
                    if not State.Enabled then break end
                    task.spawn(function()
                        if State.Enabled then
                            attackTarget(target, weapon)
                        end
                    end)
                end
            end
            -- No weapon = idle (tidak scan, tidak attack)
            
            task.wait(CYCLE_DELAY)
        end
    end)
end

function KillAura.Stop()
    if not State.Enabled then return end
    
    cleanup()
    print("[OP] KillAura: OFF")
end

function KillAura.IsEnabled()
    return State.Enabled
end

-- Full cleanup (for unload)
function KillAura.Cleanup()
    cleanup()
end

return KillAura
