--[[
    Features/GodMode.lua
    God Mode feature module
]]

local GodMode = {}

-- Dependencies
local Remote = nil

-- State
local State = {
    Enabled = false,
    Thread = nil,
}

-- ============================================
-- PUBLIC API
-- ============================================
function GodMode.Init(deps)
    Remote = deps.Remote
end

function GodMode.Start()
    if State.Thread then
        print("[OP] GodMode: Already running!")
        return
    end
    
    State.Enabled = true
    
    State.Thread = task.spawn(function()
        while State.Enabled do
            pcall(function()
                Remote.DamagePlayer(-math.huge)
            end)
            task.wait(1)
        end
        State.Thread = nil
    end)
    
    print("[OP] GodMode: STARTED")
end

function GodMode.Stop()
    State.Enabled = false
    print("[OP] GodMode: STOPPED")
end

function GodMode.IsEnabled()
    return State.Enabled
end

return GodMode
