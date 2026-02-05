--[[
    UI/Tabs/MiscTab.lua
    Miscellaneous utilities - Mute All, Notification settings, etc.
]]

local MiscTab = {}

function MiscTab.Create(Window, Utils, Remote, CONFIG, Features, WindUI)
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

    Tab:Space({ Size = 10 })

    -- ========================================
    -- LIGHTING / VISUAL (Persistent)
    -- ========================================
    local LightingSection = Tab:Section({
        Title = "💡 Lighting",
        Icon = "lucide:sun",
        Box = true,
        BoxBorder = true,
        Opened = false,
    })
    
    -- Store original lighting values
    local Lighting = game:GetService("Lighting")
    local OriginalLighting = {
        Ambient = Lighting.Ambient,
        Brightness = Lighting.Brightness,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
    }
    
    -- Connection storage for persistent enforcement
    local LightingConnections = {
        Fullbright = {},
        NoShadows = nil,
        NoFog = {},
    }
    
    -- Helper to disconnect all connections in a table
    local function disconnectLightingConns(connTable)
        if type(connTable) == "table" then
            for _, conn in pairs(connTable) do
                pcall(function() conn:Disconnect() end)
            end
        elseif connTable then
            pcall(function() connTable:Disconnect() end)
        end
    end
    
    local FULLBRIGHT = {
        Ambient = Color3.new(1, 1, 1), -- pure white
        Brightness = 3,
        OutdoorAmbient = Color3.new(1, 1, 1),
        ClockTime = 12, -- noon = brightest
        EnvironmentDiffuseScale = 1,
        EnvironmentSpecularScale = 1,
    }
    
    -- Store original ClockTime
    OriginalLighting.ClockTime = Lighting.ClockTime
    OriginalLighting.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale
    OriginalLighting.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    
    -- Fullbright Toggle (Persistent)
    LightingSection:Toggle({
        Flag = "Lighting.Fullbright",
        Title = "☀️ Fullbright (Persistent)",
        Desc = "Max brightness + lock time to noon",
        Value = false,
        Callback = function(enabled)
            -- Disconnect existing connections
            disconnectLightingConns(LightingConnections.Fullbright)
            LightingConnections.Fullbright = {}
            
            if enabled then
                -- Apply immediately
                Lighting.Ambient = FULLBRIGHT.Ambient
                Lighting.Brightness = FULLBRIGHT.Brightness
                Lighting.OutdoorAmbient = FULLBRIGHT.OutdoorAmbient
                Lighting.ClockTime = FULLBRIGHT.ClockTime
                Lighting.EnvironmentDiffuseScale = FULLBRIGHT.EnvironmentDiffuseScale
                Lighting.EnvironmentSpecularScale = FULLBRIGHT.EnvironmentSpecularScale
                
                -- Connect PropertyChanged to enforce values
                LightingConnections.Fullbright.Ambient = Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
                    Lighting.Ambient = FULLBRIGHT.Ambient
                end)
                LightingConnections.Fullbright.Brightness = Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
                    Lighting.Brightness = FULLBRIGHT.Brightness
                end)
                LightingConnections.Fullbright.OutdoorAmbient = Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(function()
                    Lighting.OutdoorAmbient = FULLBRIGHT.OutdoorAmbient
                end)
                LightingConnections.Fullbright.ClockTime = Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
                    Lighting.ClockTime = FULLBRIGHT.ClockTime
                end)
            else
                -- Restore original values
                Lighting.Ambient = OriginalLighting.Ambient
                Lighting.Brightness = OriginalLighting.Brightness
                Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
                Lighting.ClockTime = OriginalLighting.ClockTime
                Lighting.EnvironmentDiffuseScale = OriginalLighting.EnvironmentDiffuseScale
                Lighting.EnvironmentSpecularScale = OriginalLighting.EnvironmentSpecularScale
            end
        end,
    })
    
    -- Remove Shadows Toggle (Persistent)
    LightingSection:Toggle({
        Flag = "Lighting.NoShadows",
        Title = "🌫️ Remove Shadows (Persistent)",
        Desc = "Disable global shadows - stays disabled",
        Value = false,
        Callback = function(enabled)
            -- Disconnect existing
            if LightingConnections.NoShadows then
                pcall(function() LightingConnections.NoShadows:Disconnect() end)
                LightingConnections.NoShadows = nil
            end
            
            if enabled then
                Lighting.GlobalShadows = false
                LightingConnections.NoShadows = Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
                    Lighting.GlobalShadows = false
                end)
            else
                Lighting.GlobalShadows = OriginalLighting.GlobalShadows
            end
        end,
    })
    
    -- Remove Fog Toggle (Persistent)
    LightingSection:Toggle({
        Flag = "Lighting.NoFog",
        Title = "🌁 Remove Fog (Persistent)",
        Desc = "Remove fog effects - stays removed",
        Value = false,
        Callback = function(enabled)
            -- Disconnect existing
            disconnectLightingConns(LightingConnections.NoFog)
            LightingConnections.NoFog = {}
            
            if enabled then
                Lighting.FogEnd = 1000000
                Lighting.FogStart = 1000000
                
                -- Enforce fog values
                LightingConnections.NoFog.FogEnd = Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
                    Lighting.FogEnd = 1000000
                end)
                LightingConnections.NoFog.FogStart = Lighting:GetPropertyChangedSignal("FogStart"):Connect(function()
                    Lighting.FogStart = 1000000
                end)
                
                -- Remove Atmosphere
                for _, child in ipairs(Lighting:GetChildren()) do
                    if child:IsA("Atmosphere") then
                        child.Density = 0
                    end
                end
                
                -- Watch for new Atmosphere added
                LightingConnections.NoFog.ChildAdded = Lighting.ChildAdded:Connect(function(child)
                    if child:IsA("Atmosphere") then
                        child.Density = 0
                    end
                end)
            else
                Lighting.FogEnd = OriginalLighting.FogEnd
                Lighting.FogStart = OriginalLighting.FogStart
                -- Restore Atmosphere
                for _, child in ipairs(Lighting:GetChildren()) do
                    if child:IsA("Atmosphere") then
                        child.Density = 0.3
                    end
                end
            end
        end,
    })

    Tab:Space({ Size = 10 })

    -- ========================================
    -- PHYSICS OPTIMIZER
    -- ========================================
    local PhysicsSection = Tab:Section({
        Title = "📦 Physics Optimizer",
        Icon = "lucide:cpu",
        Box = true,
        BoxBorder = true,
        Opened = false,
    })
    
    local PhysicsOptimizer = Features.PhysicsOptimizer
    local SelectedPhysicsTypes = {}
    
    -- Item Type Multi-Dropdown
    local PhysicsTypeDropdown = PhysicsSection:Dropdown({
        Flag = "Physics.SelectedTypes",
        Title = "Select Item Types",
        Desc = "Choose which items to optimize",
        Multi = true,
        AllowNone = true,
        Value = {},
        Values = {"(Click Scan first)"},
        Callback = function(selected)
            SelectedPhysicsTypes = {}
            for k, v in pairs(selected) do
                if type(k) == "string" and v == true then
                    table.insert(SelectedPhysicsTypes, k)
                elseif type(v) == "string" then
                    table.insert(SelectedPhysicsTypes, v)
                end
            end
            if PhysicsOptimizer then
                PhysicsOptimizer.SetSelectedTypes(SelectedPhysicsTypes)
            end
        end,
    })
    
    -- Scan Types Button
    PhysicsSection:Button({
        Title = "🔄 Scan Item Types",
        Desc = "Find all item types in map",
        Callback = function()
            if PhysicsOptimizer then
                local types = PhysicsOptimizer.ScanItemTypes()
                if PhysicsTypeDropdown and PhysicsTypeDropdown.Refresh then
                    pcall(function()
                        PhysicsTypeDropdown:Refresh(#types > 0 and types or {"(No items)"})
                    end)
                end
            end
        end,
    })
    
    Tab:Space({ Size = 5 })
    
    -- Toggle 1: Anchor
    PhysicsSection:Toggle({
        Flag = "Physics.Anchor",
        Title = "🔒 Anchor Items",
        Desc = "Disable gravity & physics (items can't move)",
        Value = false,
        Callback = function(v)
            if PhysicsOptimizer then
                if v then
                    if PhysicsOptimizer.SetAnchor then
                        PhysicsOptimizer.SetAnchor(true)
                    end
                else
                    if PhysicsOptimizer.Revert then
                        PhysicsOptimizer.Revert("Anchored")
                    end
                end
            end
        end,
    })
    
    -- Apply Button
    PhysicsSection:Button({
        Title = "✅ Apply to All",
        Desc = "Apply current settings to all selected items",
        Callback = function()
            if PhysicsOptimizer and PhysicsOptimizer.Apply then
                local count = PhysicsOptimizer.Apply()
                if WindUI then
                    WindUI:Notify({
                        Title = "Physics Optimizer",
                        Content = "Applied to " .. count .. " items",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    -- Yeet Button
    PhysicsSection:Button({
        Title = "🗑️ Yeet Items (Far Away)",
        Desc = "Move selected items to (99999, 99999, 99999) - out of view",
        Callback = function()
            if PhysicsOptimizer then
                local count = PhysicsOptimizer.YeetItems()
                if WindUI then
                    WindUI:Notify({
                        Title = "Physics Optimizer",
                        Content = "Yeeted " .. count .. " items far away!",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    Tab:Space({ Size = 5 })
    
    -- Storage Position Paragraph
    local StorageParagraph = PhysicsSection:Paragraph({
        Title = "📍 Storage Location",
        Desc = "(Platform not created)",
    })
    
    -- Create Storage Box Button (AUTO)
    PhysicsSection:Button({
        Title = "🏗️ Create Storage Box",
        Desc = "Create 300x300x100 box HIGH above your position (+1500 Y)",
        Callback = function()
            if PhysicsOptimizer then
                local pos = PhysicsOptimizer.CreatePlatform()
                if pos and StorageParagraph then
                    StorageParagraph:SetDesc(string.format("Box at (%.0f, %.0f, %.0f)", pos.X, pos.Y, pos.Z))
                end
                if WindUI and pos then
                    WindUI:Notify({
                        Title = "Physics Optimizer",
                        Content = "Storage box created in the sky!",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    -- Move to Storage Slider
    local MoveLimit = 50 -- Default
    PhysicsSection:Slider({
        Flag = "Physics.MoveLimit",
        Title = "Move Quantity (Batch)",
        Desc = "How many items to move per click (Prevent lag)",
        Value = {
            Min = 5,
            Max = 2000,
            Default = 50,
        },
        Step = 5,
        Callback = function(val)
            MoveLimit = val
        end,
    })

    -- Move to Storage Button
    PhysicsSection:Button({
        Title = "📦 Move to Storage",
        Desc = "Move selected items to storage box (Smart Teleport)",
        Callback = function()
            if PhysicsOptimizer then
                local count = PhysicsOptimizer.MoveToStorage(MoveLimit)
                if WindUI then
                    WindUI:Notify({
                        Title = "Physics Optimizer",
                        Content = "Moved " .. count .. " items to storage!",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    -- Teleport to Storage Button
    PhysicsSection:Button({
        Title = "🚀 Teleport to Storage",
        Desc = "Teleport yourself into the storage box",
        Callback = function()
            if PhysicsOptimizer then
                local success = PhysicsOptimizer.TeleportToStorage()
                if success then
                    if WindUI then
                        WindUI:Notify({
                            Title = "Physics Optimizer",
                            Content = "Teleported to storage box!",
                            Duration = 2,
                        })
                    end
                else
                    if WindUI then
                        WindUI:Notify({
                            Title = "Error",
                            Content = "Create storage box first!",
                            Icon = "alert-triangle",
                            Duration = 3,
                        })
                    end
                end
            end
        end,
    })

    return Tab
end

return MiscTab
