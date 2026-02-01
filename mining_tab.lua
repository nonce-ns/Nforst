local MiningTab = {}

function MiningTab.Init(Section, WindUI, Mining, AttackOnMining)
    local BrownColor = Color3.fromHex("#8B4513")

    local Tab = Section:Tab({
        Title = "MINING",
        Icon = "pickaxe",
        IconColor = BrownColor,
    })

    -- =====================
    -- AUTO MINING SECTION
    -- =====================
    Tab:Section({ Title = "Auto Mining", TextSize = 16 })

    Tab:Toggle({
        Title = "Enable Auto Mining",
        Desc = "Automatically mine nearby rocks",
        Flag = "Mining_AutoMining", -- Explicit flag naming for Sync
        Value = false,
        Callback = function(state)
            if Mining then Mining:Toggle(state) end
        end
    })

    Tab:Space()

    -- =====================
    -- TARGET SELECTION
    -- =====================
    Tab:Section({ Title = "Target Selection", TextSize = 16 })

    -- Get initial lists
    local AvailableAreas = Mining and Mining:GetAreas() or {"Loading..."}
    local AvailableRocks = Mining and Mining:GetRocks() or {"Loading..."}
    local AvailableOres = Mining and Mining:GetOres() or {"Loading..."}

    -- Store dropdown references for dynamic refresh
    local AreasDropdown = Tab:Dropdown({
        Title = "Select Areas",
        Desc = "Choose mining areas (empty = all)",
        Flag = "Mining_SelectedAreas",
        Values = #AvailableAreas > 0 and AvailableAreas or {"No areas found"},
        Value = nil,
        Multi = true,
        Callback = function(selected)
            if Mining then
                Mining:SetSelectedAreas(selected)
            end
        end
    })

    Tab:Button({
        Title = "Refresh Areas",
        Icon = "refresh-cw",
        Callback = function()
            if Mining then
                AvailableAreas = Mining:GetAreas()
                if AreasDropdown and AreasDropdown.Refresh then
                    pcall(function() AreasDropdown:Refresh(AvailableAreas) end)
                end
                WindUI:Notify({ Title = "Mining", Content = #AvailableAreas .. " areas found", Duration = 2 })
            end
        end
    })

    Tab:Button({
        Title = "Clear Areas",
        Icon = "x",
        Callback = function()
            if AreasDropdown and AreasDropdown.Select then
                pcall(function() AreasDropdown:Select() end)
            end
            if Mining then Mining:SetSelectedAreas({}) end
            WindUI:Notify({ Title = "Mining", Content = "Areas cleared", Duration = 2 })
        end
    })

    Tab:Space()

    local RocksListParagraph = Tab:Paragraph({
        Title = "Selected Rocks",
        Desc = "(none)",
    })

    local RocksDropdown = Tab:Dropdown({
        Title = "Select Rocks",
        Desc = "Choose rock types to mine (empty = all)",
        Flag = "Mining_SelectedRocks",
        Values = #AvailableRocks > 0 and AvailableRocks or {"No rocks found"},
        Value = nil,
        Multi = true,
        Callback = function(selected)
            if Mining then
                Mining:SetSelectedRocks(selected)
            end
            -- Update selection list paragraph
            if RocksListParagraph then
                local list = {}
                for k, v in pairs(selected) do
                    if v == true then 
                        table.insert(list, k) 
                    elseif type(k) == "number" and type(v) == "string" then
                        table.insert(list, v)
                    end
                end
                local text = #list > 0 and ("• " .. table.concat(list, "\n• ")) or "(none)"
                if RocksListParagraph and RocksListParagraph.SetDesc then RocksListParagraph:SetDesc(text) end
            end
        end
    })

    Tab:Button({
        Title = "Refresh Rocks",
        Icon = "refresh-cw",
        Callback = function()
            if Mining then
                AvailableRocks = Mining:GetRocks()
                if RocksDropdown and RocksDropdown.Refresh then
                    pcall(function() RocksDropdown:Refresh(AvailableRocks) end)
                end
                WindUI:Notify({ Title = "Mining", Content = #AvailableRocks .. " rock types found", Duration = 2 })
            end
        end
    })

    Tab:Button({
        Title = "Clear Rocks",
        Icon = "x",
        Callback = function()
            if RocksDropdown and RocksDropdown.Select then
                pcall(function() RocksDropdown:Select() end)
            end
            if Mining then Mining:SetSelectedRocks({}) end
            WindUI:Notify({ Title = "Mining", Content = "Rocks cleared", Duration = 2 })
        end
    })

    Tab:Space()

    local OresListParagraph = Tab:Paragraph({
        Title = "Selected Ores",
        Desc = "(none)",
    })

    local OresDropdown = Tab:Dropdown({
        Title = "Select Ores (Filter)",
        Desc = "Only mine rocks containing these ores",
        Flag = "Mining_SelectedOres",
        Values = #AvailableOres > 0 and AvailableOres or {"No ores found"},
        Value = nil,
        Multi = true,
        Callback = function(selected)
            if Mining then
                Mining:SetSelectedOres(selected)
            end
            -- Update selection list paragraph
            if OresListParagraph then
                local list = {}
                for k, v in pairs(selected) do
                    if v == true then 
                        table.insert(list, k) 
                    elseif type(k) == "number" and type(v) == "string" then
                        table.insert(list, v)
                    end
                end
                local text = #list > 0 and ("• " .. table.concat(list, "\n• ")) or "(none)"
                if OresListParagraph and OresListParagraph.SetDesc then OresListParagraph:SetDesc(text) end
            end
        end
    })

    Tab:Button({
        Title = "Refresh Ores",
        Icon = "refresh-cw",
        Callback = function()
            if Mining then
                AvailableOres = Mining:GetOres()
                if OresDropdown and OresDropdown.Refresh then
                    pcall(function() OresDropdown:Refresh(AvailableOres) end)
                end
                WindUI:Notify({ Title = "Mining", Content = #AvailableOres .. " ore types found", Duration = 2 })
            end
        end
    })

    Tab:Button({
        Title = "Clear Ores",
        Icon = "x",
        Callback = function()
            if OresDropdown and OresDropdown.Select then
                pcall(function() OresDropdown:Select() end)
            end
            if Mining then Mining:SetSelectedOres({}) end
            WindUI:Notify({ Title = "Mining", Content = "Ores cleared", Duration = 2 })
        end
    })

    Tab:Space()

    -- =====================
    -- FLIGHT SETTINGS
    -- =====================
    Tab:Section({ Title = "Flight Settings", TextSize = 16 })

    Tab:Dropdown({
        Title = "Flight Mode",
        Desc = "Position relative to rock",
        Flag = "Mining_FlightMode",
        Values = {"Above", "Below"},
        Value = "Below",
        Callback = function(value)
            if Mining then Mining:SetFlightMode(value) end
        end
    })

    Tab:Slider({
        Title = "Mining Height",
        Desc = "Height above/below rock",
        Flag = "Mining_Height",
        Step = 0.1,
        Value = { Min = 3, Max = 20, Default = 7.4 },
        Callback = function(value)
            if Mining then Mining:SetHeight(value) end
        end
    })

    Tab:Slider({
        Title = "Ghost Speed",
        Desc = "Movement speed during mining",
        Flag = "Mining_GhostSpeed",
        Step = 1,
        Value = { Min = 10, Max = 100, Default = 25 },
        Callback = function(value)
            if Mining then Mining:SetSpeed(value) end
        end
    })

    Tab:Space()

    -- =====================
    -- MINING SETTINGS
    -- =====================
    Tab:Section({ Title = "Mining Settings", TextSize = 16 })

    Tab:Slider({
        Title = "Mining Range",
        Desc = "Max distance to search for rocks",
        Flag = "Mining_Range",
        Step = 50,
        Value = { Min = 100, Max = 5000, Default = 2000 },
        Callback = function(value)
            if Mining then Mining:SetRange(value) end
        end
    })

    Tab:Slider({
        Title = "Mining Distance",
        Desc = "Distance to trigger mining",
        Flag = "Mining_Distance",
        Step = 1,
        Value = { Min = 3, Max = 20, Default = 6 },
        Callback = function(value)
            if Mining then Mining:SetDistance(value) end
        end
    })

    Tab:Slider({
        Title = "Mining Delay",
        Desc = "Delay between mines (seconds)",
        Flag = "Mining_Delay",
        Step = 0.05,
        Value = { Min = 0, Max = 1, Default = 0.1 },
        Callback = function(value)
            if Mining then Mining:SetDelay(value) end
        end
    })

    Tab:Space()

    -- =====================
    -- CRITICAL HIT
    -- =====================
    Tab:Section({ Title = "Critical Hit", TextSize = 16 })

    Tab:Toggle({
        Title = "Auto Critical",
        Desc = "Move to RockCritical when it appears",
        Flag = "Mining_CriticalEnabled",
        Value = false,
        Callback = function(state)
            if Mining then Mining:SetCriticalEnabled(state) end
        end
    })

    Tab:Slider({
        Title = "Critical Offset",
        Desc = "Offset from rock surface (studs)",
        Flag = "Mining_CriticalOffset",
        Step = 0.1,
        Value = { Min = -2, Max = 2, Default = 0 },
        Callback = function(value)
            if Mining then Mining:SetCriticalOffset(value) end
        end
    })

    Tab:Slider({
        Title = "Critical Scan Interval",
        Desc = "Seconds between critical scans",
        Flag = "Mining_CriticalScanInterval",
        Step = 0.01,
        Value = { Min = 0.01, Max = 0.2, Default = 0.05 },
        Callback = function(value)
            if Mining then Mining:SetCriticalScanInterval(value) end
        end
    })

    Tab:Slider({
        Title = "Critical Snap Duration",
        Desc = "Force snap on new critical (seconds)",
        Flag = "Mining_CriticalSnapDuration",
        Step = 0.01,
        Value = { Min = 0, Max = 0.2, Default = 0.05 },
        Callback = function(value)
            if Mining then Mining:SetCriticalSnapDuration(value) end
        end
    })

    Tab:Slider({
        Title = "Critical Snap Max Distance",
        Desc = "Max distance to snap (studs)",
        Flag = "Mining_CriticalSnapMaxDistance",
        Step = 1,
        Value = { Min = 5, Max = 30, Default = 15 },
        Callback = function(value)
            if Mining then Mining:SetCriticalSnapMaxDistance(value) end
        end
    })

    Tab:Toggle({
        Title = "Wait For Next Critical",
        Desc = "Hold rock briefly after critical disappears",
        Flag = "Mining_CriticalWaitEnabled",
        Value = false,
        Callback = function(state)
            if Mining then Mining:SetCriticalWaitEnabled(state) end
        end
    })

    Tab:Slider({
        Title = "Critical Wait Duration",
        Desc = "Seconds to wait for next critical",
        Flag = "Mining_CriticalWaitDuration",
        Step = 0.1,
        Value = { Min = 0, Max = 5, Default = 1.5 },
        Callback = function(value)
            if Mining then Mining:SetCriticalWaitDuration(value) end
        end
    })

    Tab:Space()

    -- =====================
    -- DEFENSE SYSTEM
    -- =====================
    Tab:Section({ Title = "DEFENSE SYSTEM", TextSize = 16 })

    Tab:Toggle({
        Title = "Enable Defense",
        Desc = "Attack mobs while mining",
        Flag = "Defense_Enabled",
        Value = false,
        Callback = function(state)
            if AttackOnMining then AttackOnMining:Toggle(state) end
        end
    })

    Tab:Toggle({
        Title = "Only While Mining",
        Desc = "Active only when auto-mining runs",
        Flag = "Defense_OnlyMining",
        Value = true,
        Callback = function(state)
            if AttackOnMining then AttackOnMining:SetOnlyWhileMining(state) end
        end
    })

    Tab:Slider({
        Title = "Detection Range",
        Desc = "Attack radius (studs)",
        Flag = "Defense_Range",
        Step = 1,
        Value = { Min = 5, Max = 50, Default = 20 },
        Callback = function(value)
            if AttackOnMining then AttackOnMining:SetRange(value) end
        end
    })

    Tab:Slider({
        Title = "Attack Delay",
        Desc = "Seconds between attacks",
        Flag = "Defense_Delay",
        Step = 0.05,
        Value = { Min = 0.1, Max = 1.0, Default = 0.1 },
        Callback = function(value)
            if AttackOnMining then AttackOnMining:SetAttackDelay(value) end
        end
    })

    Tab:Space()

    -- =====================
    -- PER-ROCK ORE FILTERS
    -- =====================
    Tab:Section({ Title = "Per-Rock Ore Filters", TextSize = 16 })

    Tab:Paragraph({
        Title = "Filter Slots",
        Content = "Set specific ores per rock type. Rocks shown are based on selected area - click 'Refresh Rocks' above after changing area."
    })

    -- Slot 1
    local Slot1RockDropdown = Tab:Dropdown({
        Title = "Slot 1 - Rock",
        Desc = "Select rock type",
        Flag = "Mining_Slot1Rock",
        Values = AvailableRocks,
        Value = nil,
        Callback = function(value)
            if Mining then Mining:SetRockOreFilter(1, value, nil) end
        end
    })

    local Slot1OresListParagraph = Tab:Paragraph({
        Title = "Slot 1 Ores",
        Desc = "(none)",
    })

    local Slot1OreDropdown = Tab:Dropdown({
        Title = "Slot 1 - Ores",
        Desc = "Select ores for this rock",
        Flag = "Mining_Slot1Ores",
        Values = AvailableOres,
        Value = nil,
        Multi = true,
        Callback = function(selected)
            if Mining then Mining:SetRockOreFilter(1, nil, selected) end
            if Slot1OresListParagraph then
                local list = {}
                for k, v in pairs(selected) do
                    if v == true then table.insert(list, k) 
                    elseif type(k) == "number" and type(v) == "string" then table.insert(list, v) end
                end
                local text = #list > 0 and ("• " .. table.concat(list, "\n• ")) or "(none)"
                if Slot1OresListParagraph.SetDesc then Slot1OresListParagraph:SetDesc(text) end
            end
        end
    })

    Tab:Space()

    -- Slot 2
    local Slot2RockDropdown = Tab:Dropdown({
        Title = "Slot 2 - Rock",
        Desc = "Select rock type",
        Flag = "Mining_Slot2Rock",
        Values = AvailableRocks,
        Value = nil,
        Callback = function(value)
            if Mining then Mining:SetRockOreFilter(2, value, nil) end
        end
    })

    local Slot2OresListParagraph = Tab:Paragraph({
        Title = "Slot 2 Ores",
        Desc = "(none)",
    })

    local Slot2OreDropdown = Tab:Dropdown({
        Title = "Slot 2 - Ores",
        Desc = "Select ores for this rock",
        Flag = "Mining_Slot2Ores",
        Values = AvailableOres,
        Value = nil,
        Multi = true,
        Callback = function(selected)
            if Mining then Mining:SetRockOreFilter(2, nil, selected) end
            if Slot2OresListParagraph then
                local list = {}
                for k, v in pairs(selected) do
                    if v == true then table.insert(list, k) 
                    elseif type(k) == "number" and type(v) == "string" then table.insert(list, v) end
                end
                local text = #list > 0 and ("• " .. table.concat(list, "\n• ")) or "(none)"
                if Slot2OresListParagraph.SetDesc then Slot2OresListParagraph:SetDesc(text) end
            end
        end
    })

    Tab:Space()

    -- Slot 3
    local Slot3RockDropdown = Tab:Dropdown({
        Title = "Slot 3 - Rock",
        Desc = "Select rock type",
        Flag = "Mining_Slot3Rock",
        Values = AvailableRocks,
        Value = nil,
        Callback = function(value)
            if Mining then Mining:SetRockOreFilter(3, value, nil) end
        end
    })

    local Slot3OresListParagraph = Tab:Paragraph({
        Title = "Slot 3 Ores",
        Desc = "(none)",
    })

    local Slot3OreDropdown = Tab:Dropdown({
        Title = "Slot 3 - Ores",
        Desc = "Select ores for this rock",
        Flag = "Mining_Slot3Ores",
        Values = AvailableOres,
        Value = nil,
        Multi = true,
        Callback = function(selected)
            if Mining then Mining:SetRockOreFilter(3, nil, selected) end
            if Slot3OresListParagraph then
                local list = {}
                for k, v in pairs(selected) do
                    if v == true then table.insert(list, k) 
                    elseif type(k) == "number" and type(v) == "string" then table.insert(list, v) end
                end
                local text = #list > 0 and ("• " .. table.concat(list, "\n• ")) or "(none)"
                if Slot3OresListParagraph.SetDesc then Slot3OresListParagraph:SetDesc(text) end
            end
        end
    })

    Tab:Button({
        Title = "Refresh Slot Options",
        Icon = "refresh-cw",
        Callback = function()
            if Mining then
                AvailableRocks = Mining:GetRocks()
                AvailableOres = Mining:GetOres()
                -- Refresh all slot rock dropdowns
                local rockDDs = {Slot1RockDropdown, Slot2RockDropdown, Slot3RockDropdown}
                for _, dd in ipairs(rockDDs) do
                    if dd and dd.Refresh then
                        pcall(function() dd:Refresh(AvailableRocks) end)
                    end
                end
                -- Refresh all slot ore dropdowns
                local oreDDs = {Slot1OreDropdown, Slot2OreDropdown, Slot3OreDropdown}
                for _, dd in ipairs(oreDDs) do
                    if dd and dd.Refresh then
                        pcall(function() dd:Refresh(AvailableOres) end)
                    end
                end
                WindUI:Notify({ Title = "Slots", Content = "Options refreshed!", Duration = 2 })
            end
        end
    })

    Tab:Button({
        Title = "Clear All Slots",
        Icon = "x",
        Callback = function()
            -- Clear all rock dropdowns (single select)
            local rockDDs = {Slot1RockDropdown, Slot2RockDropdown, Slot3RockDropdown}
            for _, dd in ipairs(rockDDs) do
                if dd and dd.Select then
                    pcall(function() dd:Select() end)
                end
            end
            -- Clear all ore dropdowns (multi select)
            local oreDDs = {Slot1OreDropdown, Slot2OreDropdown, Slot3OreDropdown}
            for _, dd in ipairs(oreDDs) do
                if dd and dd.Select then
                    pcall(function() dd:Select() end)
                end
            end
            -- Clear module config
            if Mining then
                Mining:SetRockOreFilter(1, nil, {})
                Mining:SetRockOreFilter(2, nil, {})
                Mining:SetRockOreFilter(3, nil, {})
                Mining:ClearAllRockOreFilters()
            end
            WindUI:Notify({ Title = "Slots", Content = "All slots cleared!", Duration = 2 })
        end
    })

    Tab:Space()

    -- =====================
    -- CAMERA SETTINGS
    -- =====================
    Tab:Section({ Title = "Camera Settings", TextSize = 16 })

    Tab:Dropdown({
        Title = "Camera Mode",
        Desc = "Camera control during mining",
        Flag = "Mining_CameraMode",
        Values = {"None", "LockTarget", "FixedOffset"},
        Value = "LockTarget",
        Callback = function(value)
            if Mining then Mining:SetCameraMode(value) end
        end
    })

    Tab:Slider({
        Title = "Camera Distance",
        Desc = "Distance from character",
        Flag = "Mining_CameraDistance",
        Step = 1,
        Value = { Min = 5, Max = 50, Default = 10 },
        Callback = function(value)
            if Mining then Mining:SetCameraDistance(value) end
        end
    })

    Tab:Slider({
        Title = "Camera Height",
        Desc = "Camera height offset",
        Flag = "Mining_CameraHeight",
        Step = 1,
        Value = { Min = 5, Max = 100, Default = 36 },
        Callback = function(value)
            if Mining then Mining:SetCameraHeight(value) end
        end
    })

    Tab:Space()

    -- =====================
    -- PRIORITY & STUCK
    -- =====================
    Tab:Section({ Title = "Priority System", TextSize = 16 })

    Tab:Toggle({
        Title = "Enable Priority",
        Desc = "Prioritize rocks by selection order",
        Flag = "Mining_PriorityEnabled",
        Value = true,
        Callback = function(state)
            if Mining then Mining:SetPriorityEnabled(state) end
        end
    })

    Tab:Toggle({
        Title = "Stuck Detection",
        Desc = "Auto-recover when stuck",
        Flag = "Mining_StuckDetection",
        Value = true,
        Callback = function(state)
            if Mining then Mining:SetStuckDetection(state) end
        end
    })

    Tab:Toggle({
        Title = "Ore Check (40%)",
        Desc = "Skip rock if ore doesn't match filter",
        Flag = "Mining_OreCheckEnabled",
        Value = true,
        Callback = function(state)
            if Mining then Mining:SetOreCheckEnabled(state) end
        end
    })

    Tab:Space()

    -- =====================
    -- ZONE FARMING
    -- =====================
    Tab:Section({ Title = "Zone Farming", TextSize = 16 })

    Tab:Toggle({
        Title = "Enable Zone",
        Desc = "Only mine within zone boundary",
        Flag = "Mining_ZoneEnabled",
        Value = false,
        Callback = function(state)
            if Mining then Mining:SetZoneEnabled(state) end
        end
    })

    Tab:Button({
        Title = "Set Zone Center Here",
        Icon = "map-pin",
        Callback = function()
            if Mining then
                Mining:SetZoneCenterHere()
                WindUI:Notify({ Title = "Zone", Content = "Zone center set!", Duration = 2 })
            end
        end
    })

    Tab:Slider({
        Title = "Zone Size",
        Desc = "Zone radius in studs",
        Flag = "Mining_ZoneSize",
        Step = 5,
        Value = { Min = 10, Max = 200, Default = 25 },
        Callback = function(value)
            if Mining then Mining:SetZoneSize(value) end
        end
    })

    Tab:Space()

    -- =====================
    -- DEBUG
    -- =====================
    Tab:Section({ Title = "Debug", TextSize = 16 })

    Tab:Toggle({
        Title = "Debug Mode",
        Desc = "Show detailed logs",
        Flag = "Mining_DebugMode",
        Value = false,
        Callback = function(state)
            if Mining then Mining:SetDebugMode(state) end
        end
    })

    Tab:Toggle({
        Title = "Ore Filter Debug",
        Desc = "Log ore filter details at 40%",
        Flag = "Mining_OreFilterDebug",
        Value = false,
        Callback = function(state)
            if Mining then Mining:SetOreFilterDebug(state) end
        end
    })

    Tab:Button({
        Title = "Session Stats",
        Icon = "bar-chart-2",
        Callback = function()
            if Mining then
                local stats = Mining:GetStats()
                WindUI:Notify({
                    Title = "MINING Stats",
                    Content = string.format(
                        "Uptime: %s\nMined: %d\nMPM: %.1f\nStatus: %s",
                        stats.uptimeFormatted or "00:00:00",
                        stats.mined or 0,
                        stats.mpm or 0,
                        stats.isRunning and "Running" or "Stopped"
                    ),
                    Duration = 5,
                })
            end
        end
    })

    Tab:Button({
        Title = "Force Cleanup",
        Icon = "trash-2",
        Callback = function()
            if Mining then
                Mining:ForceCleanup()
                WindUI:Notify({ Title = "Mining", Content = "Maintenance performed!", Duration = 2 })
            end
        end
    })

    Tab:Space()

    -- =====================
    -- ADVANCED SETTINGS
    -- =====================
    Tab:Section({ Title = "Advanced Settings", TextSize = 16 })

    Tab:Slider({
        Title = "Priority Scan Interval",
        Desc = "Seconds between priority checks",
        Flag = "Mining_PriorityScanInterval",
        Step = 0.05,
        Value = { Min = 0.05, Max = 1, Default = 0.1 },
        Callback = function(value)
            if Mining then Mining:SetPriorityScanInterval(value) end
        end
    })

    Tab:Slider({
        Title = "Priority Switch Cooldown",
        Desc = "Min seconds between priority switches",
        Flag = "Mining_PrioritySwitchCooldown",
        Step = 0.5,
        Value = { Min = 0.5, Max = 10, Default = 0.5 },
        Callback = function(value)
            if Mining then Mining:SetPrioritySwitchCooldown(value) end
        end
    })

    Tab:Slider({
        Title = "Priority Dwell Time",
        Desc = "Min stay time on rock before switch",
        Flag = "Mining_PriorityDwellTime",
        Step = 0.1,
        Value = { Min = 0.1, Max = 10, Default = 0.2 },
        Callback = function(value)
            if Mining then Mining:SetPriorityDwellTime(value) end
        end
    })

    Tab:Slider({
        Title = "Priority Skip Cooldown",
        Desc = "Skip rock cooldown after switch",
        Flag = "Mining_PrioritySkipCooldown",
        Step = 1,
        Value = { Min = 3, Max = 30, Default = 3 },
        Callback = function(value)
            if Mining then Mining:SetPrioritySkipCooldown(value) end
        end
    })

    Tab:Toggle({
        Title = "Ore Skip Notify",
        Desc = "Show notification when skipping ore",
        Flag = "Mining_OreSkipNotify",
        Value = true,
        Callback = function(state)
            if Mining then Mining:SetOreSkipNotify(state) end
        end
    })

    Tab:Toggle({
        Title = "Ore Filter Bypass",
        Desc = "Bypass ore filter when no target",
        Flag = "Mining_OreFilterBypass",
        Value = false,
        Callback = function(state)
            if Mining then Mining:SetOreFilterBypass(state) end
        end
    })

    Tab:Slider({
        Title = "HP0 Skip Cooldown",
        Desc = "Skip cooldown for depleted rock (sec)",
        Flag = "Mining_HP0SkipCooldown",
        Step = 0.1,
        Value = { Min = 0.1, Max = 30, Default = 20 },
        Callback = function(value)
            if Mining then Mining:SetHP0SkipCooldown(value) end
        end
    })
end

return MiningTab
