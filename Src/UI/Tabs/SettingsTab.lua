--[[
    UI/Tabs/SettingsTab.lua
    Settings tab - Theme & Config management (WindUI compliant)
]]

local SettingsTab = {}

function SettingsTab.Create(Window, Utils, Remote, CONFIG, WindUI)
    local Tab = Window:Tab({
        Title = "Settings",
        Icon = "lucide:settings",
        IconColor = CONFIG.COLORS.Grey,
    })

    -- ========================================
    -- THEME
    -- ========================================
    
    -- Get all available themes sorted
    local themes = {}
    for name, _ in pairs(WindUI:GetThemes() or {}) do
        table.insert(themes, name)
    end
    table.sort(themes)
    
    Tab:Dropdown({
        Flag = "System.Theme",  -- This enables save/load with config
        Title = "Theme",
        Desc = "Change UI appearance",
        Values = themes,
        Value = WindUI:GetCurrentTheme() or "Dark",
        Callback = function(theme)
            WindUI:SetTheme(theme)
        end,
    })



    Tab:Space({ Size = 12 })

    -- ========================================
    -- CONFIG MANAGEMENT
    -- ========================================
    local ConfigManager = Window.ConfigManager
    local ConfigName = "default"
    
    -- Config name input
    local configInput = Tab:Input({
        Title = "Config Name",
        Value = ConfigName,
        Placeholder = "Enter config name...",
        Callback = function(text)
            ConfigName = text
        end,
    })

    Tab:Space({ Size = 8 })

    -- Existing configs dropdown
    local allConfigs = ConfigManager and ConfigManager:AllConfigs() or {}
    local configDropdown = Tab:Dropdown({
        Title = "Saved Configs",
        Desc = "Select existing config",
        Values = #allConfigs > 0 and allConfigs or {"(none)"},
        Callback = function(name)
            if name ~= "(none)" then
                ConfigName = name
                configInput:Set(name)
            end
        end,
    })

    Tab:Space({ Size = 8 })

    -- Save button
    Tab:Button({
        Title = "Save Config",
        Icon = "solar:diskette-bold",
        Color = CONFIG.COLORS.Blue,
        Callback = function()
            if not ConfigManager then
                WindUI:Notify({
                    Title = "Error",
                    Content = "Config system not available",
                    Icon = "solar:close-circle-bold",
                    Duration = 3,
                })
                return
            end
            
            Window.CurrentConfig = ConfigManager:Config(ConfigName)
            local result = Window.CurrentConfig:Save()
            
            if result then
                WindUI:Notify({
                    Title = "Config Saved",
                    Content = "Saved: " .. ConfigName,
                    Icon = "solar:check-circle-bold",
                    Duration = 3,
                })
                -- Refresh dropdown
                local updated = ConfigManager:AllConfigs()
                configDropdown:Refresh(#updated > 0 and updated or {"(none)"})
            end
        end,
    })

    -- Load button
    Tab:Button({
        Title = "Load Config",
        Icon = "solar:file-download-bold",
        Color = CONFIG.COLORS.Green,
        Callback = function()
            if not ConfigManager then
                WindUI:Notify({
                    Title = "Error",
                    Content = "Config system not available",
                    Icon = "solar:close-circle-bold",
                    Duration = 3,
                })
                return
            end
            
            Window.CurrentConfig = ConfigManager:CreateConfig(ConfigName)
            local result = Window.CurrentConfig:Load()
            
            if result then
                WindUI:Notify({
                    Title = "Config Loaded",
                    Content = "Loaded: " .. ConfigName,
                    Icon = "solar:check-circle-bold",
                    Duration = 3,
                })
            else
                WindUI:Notify({
                    Title = "Load Failed",
                    Content = "Config not found: " .. ConfigName,
                    Icon = "solar:close-circle-bold",
                    Duration = 3,
                })
            end
        end,
    })

    -- Delete button
    Tab:Button({
        Title = "Delete Config",
        Icon = "solar:trash-bin-trash-bold",
        Color = CONFIG.COLORS.Red,
        Callback = function()
            if not ConfigManager then return end
            
            local success, err = ConfigManager:DeleteConfig(ConfigName)
            
            if success then
                WindUI:Notify({
                    Title = "Config Deleted",
                    Content = "Deleted: " .. ConfigName,
                    Icon = "solar:check-circle-bold",
                    Duration = 3,
                })
                -- Refresh dropdown
                local updated = ConfigManager:AllConfigs()
                configDropdown:Refresh(#updated > 0 and updated or {"(none)"})
                configInput:Set("default")
                ConfigName = "default"
            else
                WindUI:Notify({
                    Title = "Delete Failed",
                    Content = err or "Unknown error",
                    Icon = "solar:close-circle-bold",
                    Duration = 3,
                })
            end
        end,
    })


    return Tab
end

return SettingsTab
