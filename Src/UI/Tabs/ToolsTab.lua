--[[
    UI/Tabs/ToolsTab.lua
    Tools tab - Free Camera & Spectator Mode controls
    
    v1.0 Features:
    - Free Camera toggle with speed slider
    - Spectator Mode with player dropdown and zoom
    - Mobile-friendly (on-screen buttons auto-created)
]]

local ToolsTab = {}

function ToolsTab.Create(Window, Features, CONFIG, WindUI)
    local Tab = Window:Tab({
        Title = "Tools",
        Icon = "lucide:camera",
        IconColor = CONFIG.COLORS.Purple,
    })
    
    local Tools = Features and Features.Tools
    
    -- ========================================
    -- FREE CAMERA SECTION
    -- ========================================
    local FreeCamSection = Tab:Section({
        Title = "🎥 Free Camera",
        Icon = "lucide:video",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    -- Instruction
    FreeCamSection:Paragraph({
        Title = "Controls",
        Desc = "PC: WASD + Q/E (up/down) + Right-click to rotate + Shift for speed\nMobile: Joystick + Buttons auto-appear",
    })
    
    Tab:Space({ Size = 5 })
    
    -- Free Camera Toggle
    FreeCamSection:Toggle({
        Flag = "Tools.FreeCameraEnabled",
        Title = "Enable Free Camera",
        Desc = "Detach camera from character and move freely",
        Value = false,
        Callback = function(enabled)
            if Tools then
                Tools.ToggleFreeCamera(enabled)
                if WindUI then
                    WindUI:Notify({
                        Title = "Free Camera",
                        Content = enabled and "Enabled - Use WASD/QE to move" or "Disabled",
                        Duration = 2,
                    })
                end
            end
        end,
    })
    
    -- Camera Speed Slider
    FreeCamSection:Slider({
        Flag = "Tools.CameraSpeed",
        Title = "Camera Speed",
        Desc = "Movement speed (10-200)",
        Value = {
            Min = 10,
            Max = 200,
            Default = 50,
        },
        Step = 5,
        Callback = function(val)
            if Tools then
                Tools.SetCameraSpeed(val)
            end
        end,
    })
    
    Tab:Space({ Size = 15 })
    
    -- ========================================
    -- SPECTATOR MODE SECTION
    -- ========================================
    local SpectatorSection = Tab:Section({
        Title = "👁️ Spectator Mode",
        Icon = "lucide:eye",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    -- Instruction
    SpectatorSection:Paragraph({
        Title = "Controls",
        Desc = "PC: Right-click drag to orbit, Scroll to zoom\nMobile: Swipe to orbit + Zoom buttons",
    })
    
    Tab:Space({ Size = 5 })
    
    -- State
    local SelectedTargetType = "Players"
    local SelectedPlayerName = nil
    local SelectedNPCName = nil
    local PlayerDropdown = nil
    local NPCDropdown = nil
    local SpectatorToggle = nil
    
    -- Get player list
    local function getPlayerList()
        local names = {}
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            if player ~= game:GetService("Players").LocalPlayer then
                table.insert(names, player.Name)
            end
        end
        if #names == 0 then
            return {"(No other players)"}
        end
        return names
    end
    
    -- Target Type Dropdown
    SpectatorSection:Dropdown({
        Flag = "Tools.SpectatorTargetType",
        Title = "Target Type",
        Desc = "What to spectate",
        Multi = false,
        AllowNone = false,
        Value = "Players",
        Values = {"Self", "Players", "NPCs"},
        Callback = function(selected)
            SelectedTargetType = selected
        end,
    })
    
    Tab:Space({ Size = 5 })
    
    -- Player Selection Dropdown
    PlayerDropdown = SpectatorSection:Dropdown({
        Flag = "Tools.SpectatorPlayer",
        Title = "Select Player",
        Desc = "Choose player to spectate (for Players mode)",
        Multi = false,
        AllowNone = true,
        Value = nil,
        Values = getPlayerList(),
        Callback = function(selected)
            SelectedPlayerName = selected
        end,
    })
    
    -- NPC Selection (Refresh-based)
    NPCDropdown = SpectatorSection:Dropdown({
        Flag = "Tools.SpectatorNPC",
        Title = "Select NPC",
        Desc = "Choose NPC to spectate (for NPCs mode)",
        Multi = false,
        AllowNone = true,
        Value = nil,
        Values = {"(Click Refresh NPCs)"},
        Callback = function(selected)
            SelectedNPCName = selected
        end,
    })
    
    -- Refresh Button
    SpectatorSection:Button({
        Title = "🔄 Refresh Lists",
        Desc = "Update players and nearby NPCs (200 studs)",
        Callback = function()
            if PlayerDropdown and PlayerDropdown.Refresh then
                PlayerDropdown:Refresh(getPlayerList())
            end
            if NPCDropdown and NPCDropdown.Refresh and Tools then
                local npcNames = Tools.GetNPCNames and Tools.GetNPCNames() or {"(No NPCs nearby)"}
                NPCDropdown:Refresh(npcNames)
            end
            if WindUI then
                WindUI:Notify({
                    Title = "Spectator",
                    Content = "Lists refreshed",
                    Duration = 1,
                })
            end
        end,
    })
    
    Tab:Space({ Size = 5 })
    
    -- Spectator Toggle
    SpectatorToggle = SpectatorSection:Toggle({
        Flag = "Tools.SpectatorEnabled",
        Title = "Start Spectating",
        Desc = "Follow selected target",
        Value = false,
        Callback = function(enabled)
            if not Tools then return end
            
            if enabled then
                local success = false
                
                if SelectedTargetType == "Self" then
                    Tools.StartSpectatorSelf()
                    success = true
                    if WindUI then
                        WindUI:Notify({
                            Title = "Spectator",
                            Content = "Viewing yourself in 3rd person",
                            Duration = 2,
                        })
                    end
                    
                elseif SelectedTargetType == "Players" then
                    if not SelectedPlayerName or SelectedPlayerName == "(No other players)" then
                        if WindUI then
                            WindUI:Notify({
                                Title = "Spectator",
                                Content = "Please select a player first!",
                                Icon = "alert-triangle",
                                Duration = 2,
                            })
                        end
                    else
                        local targetPlayer = Tools.GetPlayerByName(SelectedPlayerName)
                        if targetPlayer then
                            Tools.StartSpectatorPlayer(targetPlayer)
                            success = true
                            if WindUI then
                                WindUI:Notify({
                                    Title = "Spectator",
                                    Content = "Following " .. targetPlayer.Name,
                                    Duration = 2,
                                })
                            end
                        end
                    end
                    
                elseif SelectedTargetType == "NPCs" then
                    if not SelectedNPCName or SelectedNPCName == "(Click Refresh NPCs)" or SelectedNPCName == "(No NPCs nearby)" then
                        if WindUI then
                            WindUI:Notify({
                                Title = "Spectator",
                                Content = "Please refresh and select an NPC!",
                                Icon = "alert-triangle",
                                Duration = 2,
                            })
                        end
                    else
                        local npc = Tools.GetNPCByName(SelectedNPCName)
                        if npc then
                            Tools.StartSpectatorNPC(npc)
                            success = true
                            if WindUI then
                                WindUI:Notify({
                                    Title = "Spectator",
                                    Content = "Following " .. npc.Name,
                                    Duration = 2,
                                })
                            end
                        end
                    end
                end
                
                -- Reset toggle if failed
                if not success then
                    if SpectatorToggle and SpectatorToggle.Set then
                        pcall(function() SpectatorToggle:Set(false) end)
                    end
                end
            else
                Tools.StopSpectator()
                if WindUI then
                    WindUI:Notify({
                        Title = "Spectator",
                        Content = "Stopped",
                        Duration = 1,
                    })
                end
            end
        end,
    })
    
    Tab:Space({ Size = 5 })
    
    -- Zoom/Distance Slider
    SpectatorSection:Slider({
        Flag = "Tools.SpectatorDistance",
        Title = "Camera Distance",
        Desc = "How far the camera is from target (5-100 studs)",
        Value = {
            Min = 5,
            Max = 100,
            Default = 20,
        },
        Step = 5,
        Callback = function(val)
            if Tools then
                Tools.SetSpectatorDistance(val)
            end
        end,
    })
    
    Tab:Space({ Size = 5 })
    
    -- Next/Prev Buttons
    SpectatorSection:Button({
        Title = "⏮️ Previous Target",
        Callback = function()
            if Tools and Tools.GetActiveMode() == "Spectator" then
                local prev = Tools.PrevSpectatorTarget()
                if prev then
                    if WindUI then
                        WindUI:Notify({
                            Title = "Spectator",
                            Content = "Now following: " .. prev.Name,
                            Duration = 1.5,
                        })
                    end
                end
            else
                if WindUI then
                    WindUI:Notify({
                        Title = "Spectator",
                        Content = "Enable spectator mode first",
                        Duration = 1,
                    })
                end
            end
        end,
    })
    
    SpectatorSection:Button({
        Title = "⏭️ Next Target",
        Callback = function()
            if Tools and Tools.GetActiveMode() == "Spectator" then
                local nextT = Tools.NextSpectatorTarget()
                if nextT then
                    if WindUI then
                        WindUI:Notify({
                            Title = "Spectator",
                            Content = "Now following: " .. nextT.Name,
                            Duration = 1.5,
                        })
                    end
                end
            else
                if WindUI then
                    WindUI:Notify({
                        Title = "Spectator",
                        Content = "Enable spectator mode first",
                        Duration = 1,
                    })
                end
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- CAMERA SHAKE SECTION
    -- ========================================
    local CameraSection = Tab:Section({
        Title = "📷 Camera Settings",
        Icon = "lucide:camera-off",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    local cameraShakeDisabled = false
    
    CameraSection:Toggle({
        Flag = "Tools.DisableCameraShake",
        Title = "Disable Camera Shake",
        Desc = "Stop all camera shake effects (explosions, bumps, etc)",
        Value = false,
        Callback = function(enabled)
            local RunService = game:GetService("RunService")
            
            if enabled then
                pcall(function()
                    RunService:UnbindFromRenderStep("CameraShaker")
                end)
                cameraShakeDisabled = true
                
                if WindUI then
                    WindUI:Notify({
                        Title = "Camera Shake",
                        Content = "Disabled - no more screen shake!",
                        Duration = 2,
                    })
                end
            else
                if cameraShakeDisabled then
                    if WindUI then
                        WindUI:Notify({
                            Title = "Camera Shake",
                            Content = "Re-enable requires rejoin (game limitation)",
                            Icon = "alert-triangle",
                            Duration = 3,
                        })
                    end
                end
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- INFO SECTION
    -- ========================================
    Tab:Paragraph({
        Title = "💡 Tips",
        Desc = "• Self: View your character from orbit camera\n• Players: Spectate other players\n• NPCs: Follow wolves, deer, etc (200 stud radius)\n• Camera Shake: Once disabled, rejoin to re-enable",
    })
    
    return Tab
end

return ToolsTab
