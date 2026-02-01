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

    return Tab
end

return MiscTab
