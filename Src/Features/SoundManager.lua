--[[
    Features/SoundManager.lua
    Utilities for managing game audio (Mute All)
    
    Hybrid approach:
    - DELETE sounds in Workspace/SoundService (safe, environment sounds)
    - SKIP Players entirely (avoid breaking character functions)
    - BATCH processing to prevent lag spikes
]]

local SoundManager = {}

-- Dependencies
local Utils = nil
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Config
local CONFIG = {
    BatchSize = 30,        -- Process 30 sounds before yielding
    BatchDelay = 0.01,     -- Small delay between batches (10ms)
}

-- State
local State = {
    Muted = false,
    Connections = {},
    Processing = false,
}

-- Safe delete with pcall
local function safeDestroy(obj)
    pcall(function()
        if obj and obj.Parent then
            obj:Destroy()
        end
    end)
end

-- Batch delete sounds in a container (with yield to prevent lag)
local function deleteInContainer(container)
    if not container then return 0 end
    
    local count = 0
    local descendants = {}
    
    -- Collect all sounds first (faster than iterating and modifying)
    pcall(function()
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("Sound") then
                table.insert(descendants, obj)
            end
        end
    end)
    
    -- Delete in batches
    for i, sound in ipairs(descendants) do
        safeDestroy(sound)
        count = count + 1
        
        -- Yield every BatchSize to prevent freeze
        if count % CONFIG.BatchSize == 0 then
            task.wait(CONFIG.BatchDelay)
        end
    end
    
    return count
end

-- Watch for new sounds and delete them (deferred to prevent issues)
local function onSoundAdded(descendant)
    if State.Muted and descendant:IsA("Sound") then
        -- Use defer to avoid issues with sounds being used immediately
        task.defer(function()
            safeDestroy(descendant)
        end)
    end
end

function SoundManager.Init(deps)
    Utils = deps.Utils
    print("[OP] SoundManager: Initialized (Hybrid Mode)")
end

function SoundManager.MuteAll()
    if State.Muted then return end
    if State.Processing then return end -- Prevent double execution
    
    State.Muted = true
    State.Processing = true
    
    print("[OP] SoundManager: Starting sound deletion (Hybrid)...")
    
    -- Run in coroutine to prevent blocking
    task.spawn(function()
        local totalDeleted = 0
        
        -- 1. Delete in Workspace (most sounds are here)
        local wsCount = deleteInContainer(Workspace)
        totalDeleted = totalDeleted + wsCount
        print("[OP] SoundManager: Deleted " .. wsCount .. " sounds in Workspace")
        
        -- 2. Delete in SoundService
        local ssCount = deleteInContainer(SoundService)
        totalDeleted = totalDeleted + ssCount
        print("[OP] SoundManager: Deleted " .. ssCount .. " sounds in SoundService")
        
        -- 3. Delete in ReplicatedStorage (optional, usually not many)
        local rsCount = deleteInContainer(ReplicatedStorage)
        totalDeleted = totalDeleted + rsCount
        
        -- NOTE: We intentionally SKIP Players to avoid breaking character functions
        
        print("[OP] SoundManager: Total deleted: " .. totalDeleted .. " sounds")
        State.Processing = false
    end)
    
    -- 4. Watch for new sounds (only in safe containers)
    State.Connections.Workspace = Workspace.DescendantAdded:Connect(onSoundAdded)
    State.Connections.SoundService = SoundService.DescendantAdded:Connect(onSoundAdded)
    State.Connections.ReplicatedStorage = ReplicatedStorage.DescendantAdded:Connect(onSoundAdded)
    
    -- NOTE: NOT watching Players.DescendantAdded to preserve character sounds
    
    print("[OP] SoundManager: Sound deletion ACTIVE (Players excluded)")
end

function SoundManager.UnmuteAll()
    if not State.Muted then return end
    State.Muted = false
    
    print("[OP] SoundManager: Stopping deletion (sounds cannot be restored)")
    
    -- Disconnect all watchers
    for name, conn in pairs(State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(State.Connections)
end

function SoundManager.IsMuted()
    return State.Muted
end

function SoundManager.IsProcessing()
    return State.Processing
end

function SoundManager.Cleanup()
    SoundManager.UnmuteAll()
    State.Processing = false
    print("[OP] SoundManager: Cleanup complete")
end

return SoundManager
