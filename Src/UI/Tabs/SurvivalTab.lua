--[[
    UI/Tabs/SurvivalTab.lua
    Survival tab UI components
]]

local SurvivalTab = {}

function SurvivalTab.Create(Window, Features, CONFIG)
    local Tab = Window:Tab({
        Title = "Survival",
        Icon = "solar:heart-bold",
        IconColor = CONFIG.COLORS.Red,
        Border = true,
    })
    
    -- ========================================
    -- GOD MODE SECTION
    -- ========================================
    local GodSection = Tab:Section({
        Title = "God Mode",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    GodSection:Toggle({
        Flag = "GodMode.Enabled",
        Title = "Enable God Mode",
        Desc = "Infinite health via DamagePlayer(-math.huge)",
        Value = false,
        Callback = function(state)
            if state then
                Features.GodMode.Start()
            else
                Features.GodMode.Stop()
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- AUTO EAT SECTION
    -- ========================================
    local EatSection = Tab:Section({
        Title = "Auto Eat",
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
            if state then
                Features.AutoEat.Start()
            else
                Features.AutoEat.Stop()
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
            Features.AutoEat.UpdateSetting("HungerThreshold", v)
        end,
    })
    
    -- Get food list from catalog
    local foodList = {}
    local catalog = Features.AutoEat.GetFoodCatalog()
    for name, _ in pairs(catalog) do
        table.insert(foodList, name)
    end
    table.sort(foodList)
    
    EatSection:Dropdown({
        Flag = "AutoEat.AllowedFoods",
        Title = "Allowed Foods",
        Desc = "Select which foods can be eaten (empty = all)",
        Multi = true,
        AllowNone = true,
        Value = {},
        Values = foodList,
        Callback = function(selectedFoods)
            Features.AutoEat.UpdateSetting("AllowedFoods", selectedFoods)
        end,
    })
    
    EatSection:Slider({
        Flag = "AutoEat.EatCooldown",
        Title = "Eat Cooldown",
        Desc = "Seconds between eating attempts",
        Step = 0.1,
        Value = { Min = 0.5, Max = 5, Default = 0.5 },
        Callback = function(v)
            Features.AutoEat.UpdateSetting("EatCooldown", v)
        end,
    })
    
    EatSection:Button({
        Title = "Scan Food",
        Desc = "Show all food available in the map",
        Icon = "solar:magnifer-bold",
        Callback = function()
            Features.AutoEat.Scan()
        end,
    })
    

    

    
    return Tab
end

return SurvivalTab
