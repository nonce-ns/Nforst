--[[
    UI/Tabs/CombatTab.lua
    Combat tab UI - Kill Aura + Kill Target (Teleport)
]]

local CombatTab = {}

function CombatTab.Create(Window, Features, CONFIG, WindUI)
    local Tab = Window:Tab({
        Title = "Combat",
        Icon = "lucide:sword",
        IconColor = CONFIG.COLORS.Red,
    })
    
    -- ========================================
    -- KILL AURA SECTION
    -- ========================================
    local AuraSection = Tab:Section({
        Title = "Kill Aura (75 Studs)",
        Icon = "solar:danger-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    AuraSection:Toggle({
        Flag = "KillAura.Enabled",
        Title = "⚔️ Enable Kill Aura",
        Desc = "Auto attack all enemies within 75 studs",
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
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- KILL TARGET SECTION (TELEPORT)
    -- ========================================
    local TargetSection = Tab:Section({
        Title = "Kill Target (Teleport)",
        Icon = "lucide:target",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    -- Check if KillTarget exists
    if not Features.KillTarget then
        TargetSection:Paragraph({
            Title = "⚠️ Not Available",
            Desc = "KillTarget module not loaded",
        })
        return Tab
    end
    
    local KillTarget = Features.KillTarget
    
    -- State for dropdown
    local TargetDropdown = nil
    local previousSelected = {}
    local isRefreshing = false
    
    -- Scan button
    TargetSection:Button({
        Title = "🔍 Scan NPCs",
        Desc = "Refresh NPC type list",
        Callback = function()
            local types = KillTarget.ScanNPCTypes()
            if TargetDropdown and TargetDropdown.Refresh then
                isRefreshing = true
                pcall(function()
                    local items = #types > 0 and types or {"(No NPCs found)"}
                    TargetDropdown:Refresh(items)
                end)
                isRefreshing = false
            end
            if WindUI then
                WindUI:Notify({
                    Title = "Kill Target",
                    Content = "Found " .. #types .. " NPC types",
                    Duration = 2,
                })
            end
        end,
    })
    
    -- Selected paragraph
    local SelectedParagraph = TargetSection:Paragraph({
        Title = "📋 Selected Targets",
        Desc = "(none)",
    })
    
    -- Multi-select dropdown
    TargetDropdown = TargetSection:Dropdown({
        Flag = "KillTarget.SelectedTypes",
        Title = "Target Types",
        Desc = "Select NPC types to hunt",
        Multi = true,
        AllowNone = true,
        Value = {},
        Values = {"(Click Scan NPCs)"},
        Callback = function(selected)
            if isRefreshing then return end
            
            -- Normalize selection format
            local normalized = {}
            for key, value in pairs(selected) do
                if type(key) == "string" and value == true then
                    normalized[key] = true
                elseif type(key) == "number" and type(value) == "string" then
                    normalized[value] = true
                end
            end
            
            -- Update module
            KillTarget.SetSelectedTypes(normalized)
            previousSelected = normalized
            
            -- Update paragraph
            local list = KillTarget.GetSelectedTypes()
            local text = #list > 0 and ("• " .. table.concat(list, "\n• ")) or "(none)"
            if SelectedParagraph and SelectedParagraph.SetDesc then
                SelectedParagraph:SetDesc(text)
            end
        end,
    })
    
    -- Clear button
    TargetSection:Button({
        Title = "❌ Clear Selection",
        Callback = function()
            KillTarget.ClearSelection()
            if TargetDropdown and TargetDropdown.Select then
                pcall(function() TargetDropdown:Select({}) end)
            end
            if SelectedParagraph and SelectedParagraph.SetDesc then
                SelectedParagraph:SetDesc("(none)")
            end
        end,
    })
    
    Tab:Space({ Size = 5 })
    
    -- Status paragraph
    local StatusParagraph = TargetSection:Paragraph({
        Title = "📊 Status",
        Desc = "Idle",
    })
    
    -- Set status callback
    KillTarget.SetOnStatusChange(function(stats)
        if StatusParagraph and StatusParagraph.SetDesc then
            local text = stats.current or "Idle"
            if stats.total > 0 then
                text = text .. " (Killed: " .. stats.killed .. "/" .. stats.total .. ")"
            end
            StatusParagraph:SetDesc(text)
        end
    end)
    
    -- Main toggle
    local KillTargetToggle = nil
    KillTargetToggle = TargetSection:Toggle({
        Flag = "KillTarget.Enabled",
        Title = "🎯 Enable Kill Target",
        Desc = "Teleport to targets and kill them",
        Value = false,
        Callback = function(state)
            if state then
                KillTarget.Start()
            else
                KillTarget.Stop()
            end
        end,
    })
    
    -- Set auto-stop callback to sync toggle UI
    KillTarget.SetOnAutoStop(function()
        if KillTargetToggle and KillTargetToggle.SetValue then
            pcall(function() KillTargetToggle:SetValue(false) end)
        end
    end)
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- SETTINGS
    -- ========================================
    local SettingsSection = Tab:Section({
        Title = "Kill Target Settings",
        Icon = "lucide:settings",
        Box = true,
        BoxBorder = true,
        Opened = false,
    })
    
    SettingsSection:Slider({
        Flag = "KillTarget.AttackTimeout",
        Title = "Attack Timeout",
        Desc = "Max seconds to attack per target",
        Value = {Min = 3, Max = 20, Default = 8},
        Step = 1,
        Callback = function(v)
            KillTarget.SetAttackTimeout(v)
        end,
    })
    
    SettingsSection:Slider({
        Flag = "KillTarget.TeleportDelay",
        Title = "Teleport Delay",
        Desc = "Delay between teleports (seconds)",
        Value = {Min = 0.1, Max = 2, Default = 0.5},
        Step = 0.1,
        Callback = function(v)
            KillTarget.SetTeleportDelay(v)
        end,
    })
    
    SettingsSection:Toggle({
        Flag = "KillTarget.ReturnAfter",
        Title = "Return to Start",
        Desc = "Teleport back to start position when done",
        Value = true,
        Callback = function(v)
            KillTarget.SetReturnAfter(v)
        end,
    })
    
    return Tab
end

return CombatTab
