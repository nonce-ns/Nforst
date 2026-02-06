--[[
    UI/Tabs/FarmingTab.lua
    Farming tab UI - Tree Farm, Mining, Gathering, etc.
]]

local FarmingTab = {}

function FarmingTab.Create(Window, Features, CONFIG)
    local Tab = Window:Tab({
        Title = "Farming",
        Icon = "lucide:tree-pine",
        IconColor = CONFIG.COLORS.Green,
    })
    
    -- ========================================
    -- TREE FARM SECTION
    -- ========================================
    local TreeSection = Tab:Section({
        Title = "Tree Farm",
        Icon = "solar:leaf-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    -- Enable Toggle
    TreeSection:Toggle({
        Flag = "TreeFarm.Enabled",
        Title = "Enable Tree Farm",
        Desc = "Auto chop trees nearby (75 studs, requires axe)",
        Value = false,
        Callback = function(state)
            if Features.TreeFarm then
                if state then
                    Features.TreeFarm.Start()
                else
                    Features.TreeFarm.Stop()
                end
            end
        end,
    })
    
    -- Get tree list from catalog
    local treeList = {}
    if Features.TreeFarm and Features.TreeFarm.GetTreeCatalog then
        local catalog = Features.TreeFarm.GetTreeCatalog()
        for name, tier in pairs(catalog) do
            local tierLabel = tier == 2 and " (Strong Axe)" or ""
            table.insert(treeList, name)
        end
        table.sort(treeList)
    end
    
    -- Tree Type Selection (Multi-select)
    TreeSection:Dropdown({
        Flag = "TreeFarm.AllowedTrees",
        Title = "Tree Types",
        Desc = "Select which trees to chop (empty = all)",
        Multi = true,
        AllowNone = true,
        Value = {},
        Values = #treeList > 0 and treeList or {"Small Tree", "TreeBig2", "TreeBig3"},
        Callback = function(selectedTrees)
            if Features.TreeFarm then
                Features.TreeFarm.UpdateSetting("AllowedTrees", selectedTrees)
            end
        end,
    })
    
    -- Info text
    TreeSection:Paragraph({
        Title = "ℹ️ Note",
        Desc = "TreeBig2 & TreeBig3 require Strong Axe or Ice Axe",
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- AUTO PLANT SECTION
    -- ========================================
    local PlantSection = Tab:Section({
        Title = "Auto Plant",
        Icon = "solar:plant-bold",
        Box = true,
        BoxBorder = true,
        Opened = false,
    })
    
    -- Start/Stop Button
    PlantSection:Button({
        Title = "🌱 Start Planting",
        Desc = "Plant saplings in selected pattern (requires Sapling in Items)",
        Callback = function()
            if Features.AutoPlant then
                if Features.AutoPlant.IsEnabled() then
                    Features.AutoPlant.Stop()
                else
                    Features.AutoPlant.Start()
                end
            end
        end,
    })

    -- Pattern Selection Dropdown
    PlantSection:Dropdown({
        Flag = "AutoPlant.Pattern",
        Title = "Planting Pattern",
        Desc = "Select the shape to plant",
        Multi = false,
        AllowNone = false,
        Value = "Circle",
        Values = {"Circle", "Square", "Triangle", "Star", "Heart", "Spiral"},
        Callback = function(value)
            if Features.AutoPlant then
                Features.AutoPlant.UpdateSetting("Pattern", value)
            end
        end,
    })
    -- Force Sync Initial Value
    if Features.AutoPlant then Features.AutoPlant.UpdateSetting("Pattern", "Circle") end
    
    -- Radius Slider
    PlantSection:Slider({
        Flag = "AutoPlant.Radius",
        Title = "Radius",
        Desc = "Circle radius (studs)",
        Value = { Default = 20, Min = 5, Max = 1000 },
        Step = 5,
        Callback = function(value)
            if Features.AutoPlant then
                Features.AutoPlant.UpdateSetting("Radius", value)
            end
        end,
    })
    
    -- Spacing Slider
    PlantSection:Slider({
        Flag = "AutoPlant.Spacing",
        Title = "Spacing",
        Desc = "Distance between plants (studs)",
        Value = { Default = 1, Min = 0.1, Max = 10 },
        Step = 0.1,
        Callback = function(value)
            if Features.AutoPlant then
                Features.AutoPlant.UpdateSetting("Spacing", value)
            end
        end,
    })
    
    -- Plant Delay Slider
    PlantSection:Slider({
        Flag = "AutoPlant.PlantDelay",
        Title = "Plant Delay",
        Desc = "Delay between each plant (seconds)",
        Value = { Default = 0.05, Min = 0.01, Max = 0.2 },
        Step = 0.01,
        Callback = function(value)
            if Features.AutoPlant then
                Features.AutoPlant.UpdateSetting("PlantDelay", value)
            end
        end,
    })
    
    -- Height Slider
    PlantSection:Slider({
        Flag = "AutoPlant.Height",
        Title = "Plant Height",
        Desc = "Y position for planting",
        Value = { Default = 2, Min = -5, Max = 50 },
        Step = 1,
        Callback = function(value)
            if Features.AutoPlant then
                Features.AutoPlant.UpdateSetting("Height", value)
            end
        end,
    })
    
    -- Center Mode Dropdown
    PlantSection:Dropdown({
        Flag = "AutoPlant.CenterMode",
        Title = "Center Position",
        Desc = "Where to center the planting pattern",
        Multi = false,
        AllowNone = false,
        Value = "Player",
        Values = {"Player", "Campfire", "Custom"},
        Callback = function(value)
            if Features.AutoPlant then
                -- Reset all first
                Features.AutoPlant.UpdateSetting("UsePlayerCenter", false)
                Features.AutoPlant.UpdateSetting("UseCampfireCenter", false)
                
                -- Set based on selection
                if value == "Player" then
                    Features.AutoPlant.UpdateSetting("UsePlayerCenter", true)
                elseif value == "Campfire" then
                    Features.AutoPlant.UpdateSetting("UseCampfireCenter", true)
                end
                -- "Custom" is default fallback when both are false
            end
        end,
    })
    -- Force Sync Initial Value (Player)
    if Features.AutoPlant then
        Features.AutoPlant.UpdateSetting("UsePlayerCenter", true)
        Features.AutoPlant.UpdateSetting("UseCampfireCenter", false)
    end
    
    -- Show Preview Toggle
    PlantSection:Toggle({
        Flag = "AutoPlant.ShowPreview",
        Title = "Show Preview",
        Desc = "Visualize planting area (yellow = boundary, green = plant spots)",
        Value = false,
        Callback = function(state)
            if Features.AutoPlant then
                Features.AutoPlant.UpdateSetting("ShowPreview", state)
            end
        end,
    })

    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- FISH FARM SECTION
    -- ========================================
    local FishSection = Tab:Section({
        Title = "Fish Farm",
        Icon = "solar:water-bold",
        Box = true,
        BoxBorder = true,
        Opened = false,
    })
    
    -- Enable Toggle
    FishSection:Toggle({
        Flag = "FishFarm.Enabled",
        Title = "Enable Fish Farm",
        Desc = "Auto fishing when rod equipped near water",
        Value = false,
        Callback = function(state)
            if Features.FishFarm then
                if state then
                    Features.FishFarm.Start()
                else
                    Features.FishFarm.Stop()
                end
            end
        end,
    })
    
    -- Auto Hotspot Toggle
    FishSection:Toggle({
        Flag = "FishFarm.AutoHotspot",
        Title = "Auto Hotspot Hunt 🚀",
        Desc = "Teleport to active bubbles globally (High catch rate)",
        Value = false,
        Callback = function(state)
            if Features.FishFarm then
                 Features.FishFarm.UpdateSetting("AutoHotspot", state)
            end
        end,
    })
    
    -- Fish Delay Slider
    FishSection:Slider({
        Flag = "FishFarm.FishDelay",
        Title = "Fish Delay",
        Desc = "Max wait time before recast (seconds)",
        Step = 0.5,
        Value = { Min = 3, Max = 30, Default = 20 },
        Callback = function(value)
            if Features.FishFarm then
                Features.FishFarm.UpdateSetting("FishDelay", value)
            end
        end,
    })
    
    -- Info text
    FishSection:Paragraph({
        Title = "ℹ️ How to use",
        Desc = "Equip any Rod and stand near water. Auto-fish will cast and try to catch fish automatically.",
    })

    
    return Tab
end

return FarmingTab
