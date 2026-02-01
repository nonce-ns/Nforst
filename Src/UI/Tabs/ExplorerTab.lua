--[[
    UI/Tabs/ExplorerTab.lua
    Explorer tab - Map Revealer with Spiral Fly
    
    Features:
    - Spiral fly from Campfire to MaxRadius
    - Configurable radius & satellite camera
    - Stop/Cancel functionality
]]

local ExplorerTab = {}

function ExplorerTab.Create(Window, Features, CONFIG, WindUI)
    local Tab = Window:Tab({
        Title = "Explorer",
        Icon = "lucide:compass",
        IconColor = CONFIG.COLORS.Purple,
    })
    
    local MapRevealer = Features and Features.MapRevealer
    
    -- ========================================
    -- STATE
    -- ========================================
    local State = {
        SpiralRadius = 500,
    }
    
    -- ========================================
    -- UI ELEMENTS
    -- ========================================
    Tab:Space({ Size = 8 })
    
    -- Satellite Camera Toggle
    Tab:Toggle({
        Flag = "MapRevealer.SatelliteCamera",
        Title = "🛰️ Satellite Camera",
        Desc = "Top-down view to prevent motion sickness",
        Value = false,
        Callback = function(val)
            if MapRevealer and MapRevealer.SetUseSatelliteCamera then
                MapRevealer.SetUseSatelliteCamera(val)
            end
        end,
    })
    
    Tab:Space({ Size = 4 })

    -- Radius Slider
    Tab:Slider({
        Flag = "MapRevealer.SpiralRadius",
        Title = "Spiral Radius",
        Desc = "Max distance from campfire (studs)",
        Icon = "solar:ruler-bold",
        Value = {
            Min = 200,
            Max = 1500,
            Default = 500,
        },
        Callback = function(value)
            State.SpiralRadius = value or 500
            if MapRevealer and MapRevealer.SetSpiralRadius then
                MapRevealer.SetSpiralRadius(value or 500)
            end
        end,
    })
    
    Tab:Space({ Size = 12 })
    
    -- ========================================
    -- MAIN ACTIONS
    -- ========================================
    
    -- Start Button
    Tab:Button({
        Title = "🚀 Start Spiral Reveal",
        Desc = "Fly spiral from campfire to reveal fog",
        Icon = "solar:rocket-bold",
        Color = CONFIG.COLORS.Green,
        Callback = function()
            if not MapRevealer then
                WindUI:Notify({
                    Title = "Error",
                    Content = "MapRevealer not available",
                    Icon = "solar:close-circle-bold",
                    Duration = 3,
                })
                return
            end
            
            if MapRevealer.IsScanning and MapRevealer.IsScanning() then
                WindUI:Notify({
                    Title = "Map Revealer",
                    Content = "Already running...",
                    Icon = "solar:info-circle-bold",
                    Duration = 2,
                })
                return
            end
            
            -- Set radius before starting
            if MapRevealer.SetSpiralRadius then
                MapRevealer.SetSpiralRadius(State.SpiralRadius)
            end
            
            WindUI:Notify({
                Title = "Spiral Reveal",
                Content = "Radius: " .. State.SpiralRadius .. " studs",
                Icon = "solar:rocket-bold",
                Duration = 3,
            })
            
            MapRevealer.RevealSpiral(
                nil,
                function(totalRevealed)
                    WindUI:Notify({
                        Title = "Spiral Complete!",
                        Content = totalRevealed .. " blocks revealed",
                        Icon = "solar:check-circle-bold",
                        Duration = 5,
                    })
                end
            )
        end,
    })
    
    Tab:Space({ Size = 4 })
    
    -- Stop Button
    Tab:Button({
        Title = "⏹ Stop",
        Icon = "solar:stop-bold",
        Color = CONFIG.COLORS.Red,
        Callback = function()
            if MapRevealer and MapRevealer.Stop then
                MapRevealer.Stop()
                WindUI:Notify({
                    Title = "Map Revealer",
                    Content = "Stopped",
                    Icon = "solar:stop-bold",
                    Duration = 2,
                })
            end
        end,
    })
    
    Tab:Space({ Size = 8 })
    
    -- ========================================
    -- INFO
    -- ========================================
    Tab:Paragraph({
        Title = "How It Works",
        Desc = "1. Finds Campfire & starts flying\n2. Spirals outward to clear fog\n3. Use Satellite Cam 🛰️ to avoid dizziness\n4. Auto-teleports safely when done 🛡️",
        Image = "solar:info-circle-bold",
        ImageColor = CONFIG.COLORS.Grey,
    })
    
    return Tab
end

return ExplorerTab
