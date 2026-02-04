--[[
    UI/Tabs/TeleportTab.lua
    Rescue Interface for Lost Children
]]

local TeleportTab = {}

function TeleportTab.Create(Window, Features, CONFIG, WindUI)
    local Tab = Window:Tab({
        Title = "Teleport",
        Icon = "solar:map-point-bold",
        IconColor = CONFIG.COLORS.Green,
    })
    
    -- 1. Main Locations Section (Top Priority)
    local MainSection = Tab:Section({
        Title = "Main Locations",
        Icon = "solar:shield-check-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    MainSection:Button({
        Title = "Teleport to Campfire",
        Desc = "Return to main spawn area",
        Callback = function()
            if Features.Teleport then
                local success = Features.Teleport.TeleportToCampfire()
                if not success then
                    WindUI:Notify({
                        Title = "Error",
                        Content = "Campfire not found!",
                        Icon = "alert-triangle",
                        Duration = 3,
                    })
                end
            end
        end,
    })

    Tab:Space({ Size = 10 })

    -- 2. Landmarks Section (Points of Interest)
    local LandmarkSection = Tab:Section({
        Title = "Landmarks",
        Icon = "solar:map-point-wave-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    -- Dynamic buttons from config
    if Features.Teleport and Features.Teleport.GetLandmarks then
        for _, landmark in ipairs(Features.Teleport.GetLandmarks()) do
            local desc = "Teleport to " .. landmark.Name
            if landmark.HardMode then
                desc = "⚠️ " .. desc .. " (Hard Mode)"
            end
            
            LandmarkSection:Button({
                Title = landmark.Name,
                Desc = desc,
                Callback = function()
                    local success, err = Features.Teleport.TeleportToLandmark(landmark.Name)
                    if success then
                        WindUI:Notify({
                            Title = "Teleporting",
                            Content = "Going to " .. landmark.Name .. "...",
                            Icon = "map",
                            Duration = 2,
                        })
                    else
                        WindUI:Notify({
                            Title = "Error",
                            Content = err or "Failed to teleport",
                            Icon = "alert-triangle",
                            Duration = 3,
                        })
                    end
                end,
            })
        end
    end

    Tab:Space({ Size = 10 })

    -- 3. Rescue Section
    local RescueSection = Tab:Section({
        Title = "Rescue Mission",
        Icon = "solar:user-hand-up-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })

    -- Dynamic Buttons (Scan for Children)
    local TargetChildren = {
        "Lost Child (SquidKid)",
        "Lost Child (DinoKid)",
        "Lost Child (KrakenKid)",
        "Lost Child (KoalaKid)"
    }
    
    for _, kidName in ipairs(TargetChildren) do
        -- Extract simplified name
        local displayName = kidName:match("%((.+)%)") or kidName
        
        RescueSection:Button({
            Title = "Find & Rescue " .. displayName,
            Desc = "Scan map and teleport to " .. displayName,
            Callback = function()
                if Features.Teleport then
                    -- 1. Scan for the specific child
                    local foundChildren = Features.Teleport.ScanChildren(false)
                    local targetChild = nil
                    
                    for _, child in ipairs(foundChildren) do
                        -- Match name pattern (e.g. check if found name contains "SquidKid")
                        if string.find(child.Name, displayName) or string.find(child.Name, kidName) then
                            targetChild = child
                            break
                        end
                    end
                    
                    -- 2. Teleport if found
                    if targetChild then
                        WindUI:Notify({
                            Title = "Found!",
                            Content = "Teleporting to " .. displayName .. "...",
                            Icon = "map",
                            Duration = 2,
                        })
                        Features.Teleport.TeleportTo(targetChild.Position)
                    else
                        WindUI:Notify({
                            Title = "Not Found",
                            Content = displayName .. " is not in the map currently.",
                            Icon = "alert-triangle",
                            Duration = 3,
                        })
                    end
                end
            end,
        })
    end
    
    Tab:Space({ Size = 10 })

    -- ========================================
    -- PLAYER TELEPORT
    -- ========================================
    local PlayerSection = Tab:Section({
        Title = "Teleport to Player",
        Icon = "solar:users-group-rounded-bold",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    local SelectedPlayer = nil
    
    -- Player Dropdown
    local PlayerDropdown = PlayerSection:Dropdown({
        Flag = "Teleport.TargetPlayer",
        Title = "Select Player",
        Desc = "Choose a player to teleport to",
        Multi = false,
        AllowNone = true,
        Value = nil,
        Values = {"(Click Refresh)"},
        Callback = function(selected)
            SelectedPlayer = selected
        end,
    })
    
    -- Refresh Players Button
    PlayerSection:Button({
        Title = "🔄 Refresh Players",
        Desc = "Update player list",
        Callback = function()
            if Features.Teleport then
                local players = Features.Teleport.GetOtherPlayers()
                if PlayerDropdown and PlayerDropdown.Refresh then
                    pcall(function()
                        PlayerDropdown:Refresh(#players > 0 and players or {"(No other players)"})
                    end)
                end
                if WindUI then
                    WindUI:Notify({
                        Title = "Teleport",
                        Content = "Found " .. #players .. " other players",
                        Duration = 2,
                    })
                end
            end
        end,
    })
    
    -- Teleport Button
    PlayerSection:Button({
        Title = "📍 Teleport to Player",
        Desc = "Teleport to selected player",
        Callback = function()
            if not SelectedPlayer or SelectedPlayer == "" or SelectedPlayer == "(No other players)" or SelectedPlayer == "(Click Refresh)" then
                if WindUI then
                    WindUI:Notify({
                        Title = "Error",
                        Content = "Please select a player first!",
                        Icon = "alert-triangle",
                        Duration = 3,
                    })
                end
                return
            end
            
            if Features.Teleport then
                local success = Features.Teleport.TeleportToPlayer(SelectedPlayer)
                if success then
                    if WindUI then
                        WindUI:Notify({
                            Title = "Teleporting",
                            Content = "Teleporting to " .. SelectedPlayer .. "...",
                            Icon = "map",
                            Duration = 2,
                        })
                    end
                else
                    if WindUI then
                        WindUI:Notify({
                            Title = "Error",
                            Content = "Failed to teleport to " .. SelectedPlayer,
                            Icon = "alert-triangle",
                            Duration = 3,
                        })
                    end
                end
            end
        end,
    })
    
    -- Auto-refresh on player join/leave
    local Players = game:GetService("Players")
    local function refreshPlayers()
        if Features.Teleport and PlayerDropdown and PlayerDropdown.Refresh then
            local players = Features.Teleport.GetOtherPlayers()
            pcall(function()
                PlayerDropdown:Refresh(#players > 0 and players or {"(No other players)"})
            end)
        end
    end
    
    Players.PlayerAdded:Connect(refreshPlayers)
    Players.PlayerRemoving:Connect(refreshPlayers)
    
    return Tab
end

return TeleportTab
