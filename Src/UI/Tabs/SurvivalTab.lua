--[[
    UI/Tabs/SurvivalTab.lua
    Survival tab UI components - with collapsible sections
]]

local SurvivalTab = {}

function SurvivalTab.Create(Window, Features, CONFIG)
    local Tab = Window:Tab({
        Title = "Survival",
        Icon = "solar:heart-bold",
        IconColor = CONFIG.COLORS.Red,
    })
    
    -- ========================================
    -- GOD MODE SECTION (Collapsible)
    -- ========================================
    local GodSection = Tab:Section({
        Title = "God Mode",
        Icon = "solar:shield-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    GodSection:Toggle({
        Flag = "GodMode.Enabled",
        Title = "Enable God Mode",
        Desc = "Infinite health",
        Value = false,
        Callback = function(state)
            if Features.GodMode then
                if state then
                    Features.GodMode.Start()
                else
                    Features.GodMode.Stop()
                end
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- AUTO EAT SECTION (Collapsible)
    -- ========================================
    local EatSection = Tab:Section({
        Title = "Auto Eat",
        Icon = "solar:donut-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    EatSection:Toggle({
        Flag = "AutoEat.Enabled",
        Title = "Enable Auto Eat",
        Desc = "Automatically consume food when hungry",
        Value = false,
        Callback = function(state)
            if Features.AutoEat then
                if state then
                    Features.AutoEat.Start()
                else
                    Features.AutoEat.Stop()
                end
            end
        end,
    })
    
    EatSection:Slider({
        Flag = "AutoEat.HungerThreshold",
        Title = "Hunger Threshold",
        Desc = "Eat when hunger falls below this value",
        Step = 5,
        Value = { Min = 0, Max = 200, Default = 80 },
        Callback = function(v)
            if Features.AutoEat then
                Features.AutoEat.UpdateSetting("HungerThreshold", v)
            end
        end,
    })
    
    -- Get food list from catalog
    local foodList = {}
    if Features.AutoEat and Features.AutoEat.GetFoodCatalog then
        local catalog = Features.AutoEat.GetFoodCatalog()
        for name, _ in pairs(catalog) do
            table.insert(foodList, name)
        end
        table.sort(foodList)
    end
    
    EatSection:Dropdown({
        Flag = "AutoEat.AllowedFoods",
        Title = "Allowed Foods",
        Desc = "Select which foods can be eaten (empty = all)",
        Multi = true,
        AllowNone = true,
        Value = {},
        Values = #foodList > 0 and foodList or {"(none available)"},
        Callback = function(selectedFoods)
            if Features.AutoEat then
                Features.AutoEat.UpdateSetting("AllowedFoods", selectedFoods)
            end
        end,
    })
    
    EatSection:Slider({
        Flag = "AutoEat.EatCooldown",
        Title = "Eat Cooldown",
        Desc = "Seconds between eating attempts",
        Step = 0.1,
        Value = { Min = 0.5, Max = 5, Default = 0.5 },
        Callback = function(v)
            if Features.AutoEat then
                Features.AutoEat.UpdateSetting("EatCooldown", v)
            end
        end,
    })
    
    EatSection:Button({
        Title = "Scan Food",
        Desc = "Show all food available in the map",
        Icon = "solar:magnifer-bold",
        Callback = function()
            if Features.AutoEat then
                Features.AutoEat.Scan()
            end
        end,
    })
    
    return Tab
end

return SurvivalTab
