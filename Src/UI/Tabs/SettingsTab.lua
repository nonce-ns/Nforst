--[[
    UI/Tabs/SettingsTab.lua
    Settings tab UI components
]]

local SettingsTab = {}

function SettingsTab.Create(Window, Utils, Remote, CONFIG, WindUI)
    local SettingsSection = Window:Section({ Title = "System" })
    
    local Tab = SettingsSection:Tab({
        Title = "Settings",
        Icon = "settings",
        IconColor = CONFIG.COLORS.Grey,
        Border = true,
    })
    
    -- ========================================
    -- THEME SECTION
    -- ========================================
    local ThemeSection = Tab:Section({
        Title = "🎨 Theme",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    ThemeSection:Dropdown({
        Flag = "System.Theme",
        Title = "Theme",
        Values = Window.Themes or {"Dark", "Light", "Rose", "Aqua"},
        Value = "Dark",
        Callback = function(newTheme)
            if Window.SetTheme then
                Window:SetTheme(newTheme)
            end
        end,
    })
    
    Tab:Space()
    
    -- ========================================
    -- CONFIG SECTION
    -- ========================================
    local ConfigSection = Tab:Section({
        Title = "💾 Config",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    local ConfigManager = Window.ConfigManager
    local ConfigName = "default"
    
    ConfigSection:Input({
        Title = "Config Name",
        Value = ConfigName,
        Placeholder = "Enter config name...",
        Callback = function(text)
            ConfigName = text
        end,
    })
    
    ConfigSection:Button({
        Title = "💾 Save Config",
        Desc = "Save current settings",
        Callback = function()
            if ConfigManager then
                local success = ConfigManager:SaveConfig(ConfigName)
                if success and WindUI then
                    WindUI:Notify({
                        Title = "Config Saved",
                        Content = "Saved config: " .. ConfigName,
                        Icon = "check",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    ConfigSection:Button({
        Title = "📂 Load Config",
        Desc = "Load saved settings",
        Callback = function()
            if ConfigManager then
                local success = ConfigManager:LoadConfig(ConfigName)
                if success and WindUI then
                    WindUI:Notify({
                        Title = "Config Loaded",
                        Content = "Loaded config: " .. ConfigName,
                        Icon = "check",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    Tab:Space()
    
    -- ========================================
    -- DEBUG SECTION
    -- ========================================
    local DebugSection = Tab:Section({
        Title = "🐛 Debug",
        Box = true,
        BoxBorder = true,
        Opened = false,
    })
    
    DebugSection:Toggle({
        Flag = "System.DebugMode",
        Title = "Debug Mode",
        Desc = "Show detailed logs",
        Value = false,
        Callback = function(v) end,
    })
    
    DebugSection:Button({
        Title = "Print Stats",
        Justify = "Center",
        Icon = "",
        Callback = function()
            if Utils then
                local hunger = Utils.getStat("Hunger")
                local health = Utils.getStat("Health")
                local warmth = Utils.getStat("Warmth")
                print("[OP] Stats: Hunger=" .. tostring(hunger) .. ", Health=" .. tostring(health) .. ", Warmth=" .. tostring(warmth))
            end
        end,
    })
    
    DebugSection:Button({
        Title = "List Remotes",
        Justify = "Center",
        Icon = "",
        Callback = function()
            if Remote then
                local list = Remote.getAllRemotes()
                print("[OP] Found " .. #list .. " remotes:")
                for _, r in ipairs(list) do
                    print("  - " .. r.Name .. " (" .. r.Class .. ")")
                end
            end
        end,
    })
    
    return Tab
end

return SettingsTab
