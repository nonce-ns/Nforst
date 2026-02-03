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

    -- 2. Rescue Section
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
    
    return Tab
end

return TeleportTab
