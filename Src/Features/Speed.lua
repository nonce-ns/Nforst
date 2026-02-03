--[[
    Features/Speed.lua
    Persistent WalkSpeed Controller
    - Enforces WalkSpeed every frame (Anti-Slow/Anti-Reset)
    - Persistent across respawns
    - Seat/Vehicle safe
]]

local Speed = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Configuration
local CONFIG = {
    Speed = 40,
    DefaultSpeed = 16,
    RestoredSpeed = 16, -- Speed to restore to on disable
}

-- State
local State = {
    Enabled = false,
    Connections = {},
}

function Speed.Start()
    if State.Enabled then return end
    State.Enabled = true
    
    local char = Players.LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        -- Capture current speed as baseline (if reasonable)
        if hum.WalkSpeed > 0 and hum.WalkSpeed < 200 then
            CONFIG.RestoredSpeed = hum.WalkSpeed
        else
            CONFIG.RestoredSpeed = CONFIG.DefaultSpeed
        end
    end
    
    local function enforceSpeed()
        if not State.Enabled then return end
        local currChar = Players.LocalPlayer.Character
        local currHum = currChar and currChar:FindFirstChild("Humanoid")
        
        if currHum then
            -- Vehicle Check: Disable speed hack if sitting
            if currHum.Sit then return end
            
            -- Anti-Slow: Enforce target speed
            if math.abs(currHum.WalkSpeed - CONFIG.Speed) > 1 then
                currHum.WalkSpeed = CONFIG.Speed
            end
        end
    end
    
    -- Enforce on Heartbeat (Overrides game scripts setting it back)
    local conn = RunService.Heartbeat:Connect(enforceSpeed)
    table.insert(State.Connections, conn)
    
    print("[Speed] Enabled: " .. CONFIG.Speed .. " (Restore: " .. CONFIG.RestoredSpeed .. ")")
end

function Speed.Stop()
    if not State.Enabled then return end
    State.Enabled = false
    
    -- Disconnect loops
    for _, conn in ipairs(State.Connections) do conn:Disconnect() end
    State.Connections = {}
    
    -- Reset to restored value
    local char = Players.LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum then
        hum.WalkSpeed = CONFIG.RestoredSpeed
    end
    
    print("[Speed] Disabled")
end

function Speed.Toggle(val)
    if val then Speed.Start() else Speed.Stop() end
end

function Speed.SetSpeed(val)
    CONFIG.Speed = tonumber(val) or 40
end

function Speed.Init()
    print("[Speed] Initialized")
end

function Speed.Cleanup()
    Speed.Stop()
end

return Speed
