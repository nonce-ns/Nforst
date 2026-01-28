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

local function getEquippedMelee()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    -- Check currently equipped tool (in character)
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") and isMelee(item.Name) then
            return item
        end
    end
    return nil
end

local function getAnyMelee()
    -- Fallback: get from inventory if nothing equipped
    local inv = LocalPlayer:FindFirstChild("Inventory")
    if not inv then return nil end
    
    for _, item in ipairs(inv:GetChildren()) do
        if isMelee(item.Name) then
            return item
        end
    end
    return nil
end

local function generateHitId()
    State.HitCounter = State.HitCounter + 1
    return tostring(State.HitCounter) .. "_" .. tostring(LocalPlayer.UserId)
end

local function getTargets()
    local targets = {}
    local chars = Workspace:FindFirstChild("Characters")
    if not chars then return targets end
    
    local root = Utils and Utils.getRoot()
    if not root then return targets end
    
    for _, char in ipairs(chars:GetChildren()) do
        -- Skip players
        if Players:GetPlayerFromCharacter(char) then
            continue
        end
        
        -- Skip dead
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            continue
        end
        
        -- Get position
        local charRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
        if not charRoot then
            continue
        end
        
        -- Check range
        local dist = (charRoot.Position - root.Position).Magnitude
        if dist <= RANGE then
            table.insert(targets, {
                Model = char,
                Distance = dist,
                HitPart = charRoot,
            })
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
            -- Auto-detect equipped melee weapon
            local weapon = getEquippedMelee() or getAnyMelee()
            
            if weapon then
                local targets = getTargets()
                
                for _, target in ipairs(targets) do
                    if not State.Enabled then break end
                    task.spawn(function()
                        if not State.Enabled then return end  -- Double check before attack
                        attackTarget(target, weapon)
                    end)
                end
            end
            
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

return KillAura
