--[[
    UI/Tabs/MiscTab.lua
    Miscellaneous utilities - Mute All, Notification settings, etc.
]]

local MiscTab = {}

function MiscTab.Create(Window, Utils, Remote, CONFIG, Features)
    local Tab = Window:Tab({
        Title = "Misc",
        Icon = "solar:settings-bold", -- Or similar generic settings icon
        IconColor = CONFIG.COLORS.Orange,
    })
    
    local MainSection = Tab:Section({
        Title = "General Utilities",
        Icon = "solar:widget-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })

    -- ========================================
    -- SOUND SETTINGS
    -- ========================================
    
    -- Mute All Sounds (Moved from FarmingTab)
    MainSection:Toggle({
        Flag = "SoundManager.MuteAll",
        Title = "Mute All Game Sounds (Delete Mode)",
        Desc = "Permanently deletes all sounds for max anti-lag. Cannot restore.",
        Value = false,
        Callback = function(state)
            if Features.SoundManager then
                if state then
                    Features.SoundManager.MuteAll()
                else
                    Features.SoundManager.UnmuteAll()
                end
            end
        end,
    })
    
    Tab:Space({ Size = 10 })

    -- ========================================
    -- NOTIFICATION SETTINGS
    -- ========================================
    
    -- Disable Notifications (Moved from SettingsTab)
    MainSection:Toggle({
        Flag = "System.DisableNotifications",
        Title = "Disable Notifications",
        Desc = "Disable to hide all popup info results",
        Value = false,
        Callback = function(state)
            if getgenv then
                getgenv().OP_DISABLE_NOTIF = state
            end
        end,
    })

    Tab:Space({ Size = 10 })

    -- ========================================
    -- MOVEMENT SETTINGS
    -- ========================================
    
    local FlyToggle = MainSection:Toggle({
        Flag = "Fly.Enabled",
        Title = "Universal Fly (NoClip)",
        Desc = "Flight mode with NoClip. Supports PC (WASD+Space/Ctrl) and Mobile (Look+Joystick/Buttons)",
        Value = false,
        Callback = function(state)
            if Features.Fly then
                Features.Fly.Toggle(state)
            end
        end,
    })
    
    -- UI Sync: Listen for internal state changes (e.g. Death stop)
    if Features.Fly and Features.Fly.StateChanged then
        Features.Fly.StateChanged.Event:Connect(function(state)
            -- Prevent loop: Only set if value differs
            if FlyToggle and FlyToggle.Set then
                pcall(function() FlyToggle:Set(state) end)
            end
        end)
    end
    
    MainSection:Slider({
        Flag = "Fly.Speed",
        Title = "Fly Speed",
        Value = {
            Min = 10,
            Max = 200,
            Default = 60,
        },
        Step = 5,
        Callback = function(val)
            if Features.Fly then
                Features.Fly.SetSpeed(val)
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    MainSection:Toggle({
        Flag = "Speed.Enabled",
        Title = "Walk Speed (Persistent)",
        Desc = "Enforces WalkSpeed constantly (Anti-Slow). Default 40.",
        Value = false,
        Callback = function(state)
            if Features.Speed then
                Features.Speed.Toggle(state)
            end
        end,
    })
    
    MainSection:Slider({
        Flag = "Speed.Value",
        Title = "Speed Value",
        Value = {
            Min = 16,
            Max = 200,
            Default = 40,
        },
        Step = 5,
        Callback = function(val)
            if Features.Speed then
                Features.Speed.SetSpeed(val)
            end
        end,
    })

    return Tab
end

return MiscTab
