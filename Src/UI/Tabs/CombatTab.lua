--[[
    UI/Tabs/CombatTab.lua
    Combat tab UI - SIMPLE (Just ON/OFF toggle)
]]

local CombatTab = {}

function CombatTab.Create(Window, Features, CONFIG)
    local Tab = Window:Tab({
        Title = "Combat",
        Icon = "lucide:sword",
        IconColor = CONFIG.COLORS.Red,
    })
    
    -- ========================================
    -- KILL AURA SECTION (SIMPLE)
    -- ========================================
    local AuraSection = Tab:Section({
        Title = "Kill Aura",
        Icon = "solar:danger-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    -- Enable Toggle (ONLY THIS!)
    AuraSection:Toggle({
        Flag = "KillAura.Enabled",
        Title = "Enable Kill Aura",
        Desc = "Auto attack enemies (75 studs, equipped melee weapon)",
        Value = false,
        Callback = function(state)
            if Features.KillAura then
                if state then
                    Features.KillAura.Start()
                else
                    Features.KillAura.Stop()
                end
            end
        end,
    })
    
    return Tab
end

return CombatTab
