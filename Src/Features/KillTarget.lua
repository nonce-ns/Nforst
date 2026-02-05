--[[
    Features/KillTarget.lua
    Teleport Kill System - Multi-select NPC types
    
    - Teleport to closest target of selected types
    - Attack until dead or timeout
    - Move to next target
    - Auto-stop when all done
]]

local KillTarget = {}

-- Dependencies
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Utils = nil
local Remote = nil

-- Config
local CONFIG = {
    AttackTimeout = 8,      -- seconds per target
    TeleportDelay = 0.5,    -- delay between teleports
    AttackDelay = 0.1,      -- delay between attacks
    TeleportOffset = 4,     -- studs behind target
    ScanRadius = 5000,      -- max scan radius
}

-- Melee weapon keywords (same as KillAura)
local MELEE_KEYWORDS = {
    "chainsaw", "axe", "sword", "morningstar", "spear", "scythe",
}

-- State
local State = {
    Enabled = false,
    Thread = nil,
    SelectedTypes = {},     -- {["Bunny"] = true, ["Wolf"] = true}
    StartPosition = nil,    -- CFrame for return
    ReturnAfter = true,     -- return to start position
    HitCounter = 0,
    Stats = {
        killed = 0,
        total = 0,
        current = "",
    },
    OnStatusChange = nil,   -- callback for UI update
    OnAutoStop = nil,       -- callback when auto-stopped (UI sync)
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
    
    local toolHandle = char:FindFirstChild("ToolHandle")
    if not toolHandle then return nil end
    
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
    return tostring(State.HitCounter) .. "_" .. tostring(LocalPlayer.UserId) .. "_KT"
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getCharactersFolder()
    return Workspace:FindFirstChild("Characters") or Workspace:FindFirstChild("NPCs")
end

-- Scan for unique NPC type names
local function scanNPCTypes()
    local types = {}
    local typeLookup = {}
    
    local charsFolder = getCharactersFolder()
    if not charsFolder then return types end
    
    for _, npc in ipairs(charsFolder:GetChildren()) do
        -- Skip players
        if Players:GetPlayerFromCharacter(npc) then continue end
        
        local isPlayer = false
        for _, player in ipairs(Players:GetPlayers()) do
            if npc.Name == player.Name or npc.Name == player.DisplayName then
                isPlayer = true
                break
            end
        end
        if isPlayer then continue end
        
        -- Must have living Humanoid
        local hum = npc:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and not typeLookup[npc.Name] then
            typeLookup[npc.Name] = true
            table.insert(types, npc.Name)
        end
    end
    
    -- Sort alphabetically
    table.sort(types)
    return types
end

-- Find all targets matching selected types, sorted by distance
local function findTargetsByTypes()
    local targets = {}
    local root = getRoot()
    if not root then return targets end
    
    local playerPos = root.Position
    local charsFolder = getCharactersFolder()
    if not charsFolder then return targets end
    
    for _, npc in ipairs(charsFolder:GetChildren()) do
        -- Skip if not selected type
        if not State.SelectedTypes[npc.Name] then continue end
        
        -- Skip players
        if Players:GetPlayerFromCharacter(npc) then continue end
        
        -- Must have living Humanoid
        local hum = npc:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        
        -- Get position
        local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
        if not npcRoot then continue end
        
        local dist = (npcRoot.Position - playerPos).Magnitude
        if dist <= CONFIG.ScanRadius then
            table.insert(targets, {
                Model = npc,
                Name = npc.Name,
                Distance = dist,
                Root = npcRoot,
                Humanoid = hum,
            })
        end
    end
    
    -- Sort by distance (closest first) ← IMPORTANT!
    table.sort(targets, function(a, b) return a.Distance < b.Distance end)
    
    return targets
end

-- Teleport behind target
local function teleportToTarget(target)
    local root = getRoot()
    if not root or not target.Root then return false end
    
    pcall(function()
        -- Teleport behind target
        local behindCFrame = target.Root.CFrame * CFrame.new(0, 0, CONFIG.TeleportOffset)
        root.CFrame = behindCFrame
        
        -- Face target
        task.wait(0.05)
        root.CFrame = CFrame.lookAt(root.Position, target.Root.Position)
    end)
    
    return true
end

-- Attack until dead or timeout
local function attackUntilDead(target, timeout)
    local startTime = tick()
    local weapon = getEquippedMelee()
    if not weapon then return false, "No weapon" end
    
    local root = getRoot()
    if not root then return false, "No root" end
    
    while State.Enabled do
        -- Check timeout
        if tick() - startTime > timeout then
            return false, "Timeout"
        end
        
        -- Check if target dead
        if not target.Humanoid or not target.Humanoid.Parent then
            return true, "Dead"
        end
        if target.Humanoid.Health <= 0 then
            return true, "Dead"
        end
        
        -- Attack
        pcall(function()
            Remote.ToolDamageObject(target.Model, weapon, generateHitId(), root.CFrame)
        end)
        
        task.wait(CONFIG.AttackDelay)
    end
    
    return false, "Stopped"
end

-- Update status and call callback
local function updateStatus(current, killed, total)
    State.Stats.current = current
    State.Stats.killed = killed
    State.Stats.total = total
    
    if State.OnStatusChange then
        pcall(function()
            State.OnStatusChange(State.Stats)
        end)
    end
end

-- Cleanup
local function cleanup()
    if State.Thread then
        pcall(function() task.cancel(State.Thread) end)
        State.Thread = nil
    end
    State.Enabled = false
    State.HitCounter = 0
    updateStatus("Idle", 0, 0)
end

-- ============================================
-- PUBLIC API
-- ============================================
function KillTarget.Init(deps)
    Utils = deps.Utils
    Remote = deps.Remote
    print("[OP] KillTarget: Initialized")
end

function KillTarget.Start()
    if State.Enabled then return end
    
    -- Check if any types selected
    local hasSelection = false
    for _ in pairs(State.SelectedTypes) do
        hasSelection = true
        break
    end
    if not hasSelection then
        print("[OP] KillTarget: No targets selected!")
        return
    end
    
    cleanup()
    State.Enabled = true
    
    -- Reset stats for new run
    State.Stats.killed = 0
    State.Stats.total = 0
    State.Stats.current = ""
    
    -- Save start position
    local root = getRoot()
    if root then
        State.StartPosition = root.CFrame
    end
    
    print("[OP] KillTarget: ON")
    
    State.Thread = task.spawn(function()
        while State.Enabled do
            -- Find all matching targets
            local targets = findTargetsByTypes()
            
            if #targets == 0 then
                -- No more targets
                updateStatus("Done! All targets killed.", State.Stats.killed, State.Stats.killed)
                print("[OP] KillTarget: All targets killed! Total: " .. State.Stats.killed)
                
                -- Return to start position if enabled
                if State.ReturnAfter and State.StartPosition then
                    local root = getRoot()
                    if root then
                        root.CFrame = State.StartPosition
                    end
                end
                
                -- Auto stop
                State.Enabled = false
                
                -- Notify UI to sync toggle
                if State.OnAutoStop then
                    pcall(function() State.OnAutoStop() end)
                end
                
                break
            end
            
            -- Update total count
            State.Stats.total = #targets
            
            -- Get closest target
            local target = targets[1]
            updateStatus("Killing " .. target.Name .. "...", State.Stats.killed, #targets)
            
            -- Teleport to target
            if teleportToTarget(target) then
                task.wait(CONFIG.TeleportDelay)
                
                -- Attack until dead
                local success, reason = attackUntilDead(target, CONFIG.AttackTimeout)
                
                if success then
                    State.Stats.killed = State.Stats.killed + 1
                    print("[OP] KillTarget: Killed " .. target.Name .. " (" .. State.Stats.killed .. ")")
                else
                    print("[OP] KillTarget: Skipped " .. target.Name .. " (" .. reason .. ")")
                end
            end
            
            -- Small delay before next target
            task.wait(0.1)
        end
        
        cleanup()
    end)
end

function KillTarget.Stop()
    if not State.Enabled then return end
    
    -- Return to start position if enabled
    if State.ReturnAfter and State.StartPosition then
        local root = getRoot()
        if root then
            pcall(function() root.CFrame = State.StartPosition end)
        end
    end
    
    cleanup()
    print("[OP] KillTarget: OFF (Killed: " .. State.Stats.killed .. ")")
end

function KillTarget.IsEnabled()
    return State.Enabled
end

function KillTarget.SetSelectedTypes(types)
    -- types = {["Bunny"] = true, ["Wolf"] = true} or {"Bunny", "Wolf"}
    State.SelectedTypes = {}
    
    if type(types) == "table" then
        for key, value in pairs(types) do
            if type(key) == "string" and value == true then
                State.SelectedTypes[key] = true
            elseif type(key) == "number" and type(value) == "string" then
                State.SelectedTypes[value] = true
            end
        end
    end
end

function KillTarget.GetSelectedTypes()
    local list = {}
    for name in pairs(State.SelectedTypes) do
        table.insert(list, name)
    end
    return list
end

function KillTarget.ClearSelection()
    State.SelectedTypes = {}
end

function KillTarget.ScanNPCTypes()
    return scanNPCTypes()
end

function KillTarget.GetStats()
    return State.Stats
end

function KillTarget.SetOnStatusChange(callback)
    State.OnStatusChange = callback
end

function KillTarget.SetOnAutoStop(callback)
    State.OnAutoStop = callback
end

-- Settings
function KillTarget.SetAttackTimeout(value)
    CONFIG.AttackTimeout = math.clamp(value, 3, 30)
end

function KillTarget.SetTeleportDelay(value)
    CONFIG.TeleportDelay = math.clamp(value, 0.1, 3)
end

function KillTarget.SetReturnAfter(value)
    State.ReturnAfter = value
end

function KillTarget.Cleanup()
    cleanup()
end

return KillTarget
