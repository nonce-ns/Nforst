--[[
    Features/SoundManager.lua
    Utilities for managing game audio (Mute All)
]]

local SoundManager = {}

-- Dependencies
local Utils = nil
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

-- State
local State = {
    Muted = false,
    Connections = {},     -- Event connections for new sounds
}

-- Delete all existing sounds
local function deleteRecursive(parent)
    for _, obj in ipairs(parent:GetDescendants()) do
        if obj:IsA("Sound") then
            -- Destroy immediately
            obj:Destroy()
        end
    end
end

function SoundManager.Init(deps)
    Utils = deps.Utils
    print("[OP] SoundManager: Initialized (DELETE MODE)")
end

function SoundManager.MuteAll()
    if State.Muted then return end
    State.Muted = true
    
    print("[OP] SoundManager: DELETING ALL SOUNDS (ANTI-LAG)...")
    
    -- 1. Delete everything now
    deleteRecursive(game)
    
    -- 2. Watch for new sounds 
    local function onDescendantAdded(descendant)
        if descendant:IsA("Sound") then
            -- Kill on sight
            if State.Muted then 
                descendant:Destroy()
            end
        end
    end
    
    State.Connections.Workspace = game:GetService("Workspace").DescendantAdded:Connect(onDescendantAdded)
    State.Connections.SoundService = game:GetService("SoundService").DescendantAdded:Connect(onDescendantAdded)
    State.Connections.ReplicatedStorage = game:GetService("ReplicatedStorage").DescendantAdded:Connect(onDescendantAdded)
    State.Connections.Players = game:GetService("Players").DescendantAdded:Connect(onDescendantAdded)
    
    print("[OP] SoundManager: SOUND DELETION ACTIVE")
end

function SoundManager.UnmuteAll()
    if not State.Muted then return end
    State.Muted = false
    
    print("[OP] SoundManager: STOPPING DELETION (Sounds cannot be restored)")
    
    -- Disconnect events
    for _, conn in pairs(State.Connections) do
        conn:Disconnect()
    end
    table.clear(State.Connections)
end

function SoundManager.IsMuted()
    return State.Muted
end

function SoundManager.Cleanup()
    -- Stop sound deletion
    SoundManager.UnmuteAll()
    print("[OP] SoundManager: Cleanup complete")
end

return SoundManager
