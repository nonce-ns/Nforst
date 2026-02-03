--[[
    UI/Tabs/AutoCollectTab.lua
    Auto Collect tab UI - Collect items from workspace.Items
]]

local AutoCollectTab = {}

function AutoCollectTab.Create(Window, Features, CONFIG, WindUI)
    local Tab = Window:Tab({
        Title = "Auto Collect",
        Icon = "lucide:package",
        IconColor = CONFIG.COLORS.Purple or Color3.fromRGB(147, 112, 219),
    })
    
    local ItemCollector = Features.ItemCollector
    
    -- ========================================
    -- CONTROL SECTION (TOP)
    -- ========================================
    local ControlSection = Tab:Section({
        Title = "Control",
        Icon = "lucide:play",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    ControlSection:Button({
        Title = "▶️ Start Collect",
        Desc = "Begin collecting selected items",
        Callback = function()
            if ItemCollector then
                ItemCollector.Start()
                if WindUI then
                    WindUI:Notify({
                        Title = "Auto Collect",
                        Content = "Collection started!",
                        Duration = 2,
                    })
                end
            end
        end,
    })
    
    ControlSection:Button({
        Title = "⏹️ Stop",
        Desc = "Stop collecting",
        Callback = function()
            if ItemCollector then
                ItemCollector.Stop()
                if WindUI then
                    local stats = ItemCollector.GetStats()
                    WindUI:Notify({
                        Title = "Auto Collect",
                        Content = "Stopped! Collected " .. (stats.collected or 0) .. " items",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- DESTINATION SECTION
    -- ========================================
    local DestSection = Tab:Section({
        Title = "Destination",
        Icon = "lucide:map-pin",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    DestSection:Dropdown({
        Flag = "AutoCollect.Destination",
        Title = "Destination",
        Desc = "Where to drag collected items",
        Value = "Player",
        Values = {"Player", "Campfire", "Scrapper", "OtherPlayer"},
        Callback = function(value)
            if ItemCollector then
                ItemCollector.SetDestination(value)
            end
        end,
    })
    
    -- Get list of other players
    local function getOtherPlayers()
        local players = {}
        local localPlayer = game:GetService("Players").LocalPlayer
        for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
            if player ~= localPlayer then
                table.insert(players, player.Name)
            end
        end
        return #players > 0 and players or {"(No other players)"}
    end
    
    local TargetPlayerDropdown = nil
    
    TargetPlayerDropdown = DestSection:Dropdown({
        Flag = "AutoCollect.TargetPlayer",
        Title = "Target Player",
        Desc = "Select player (for OtherPlayer destination)",
        Value = "",
        Values = getOtherPlayers(),
        Callback = function(value)
            if ItemCollector and value ~= "(No other players)" then
                ItemCollector.SetTargetPlayer(value)
            end
        end,
    })
    
    DestSection:Button({
        Title = "🔄 Refresh Players",
        Callback = function()
            if TargetPlayerDropdown and TargetPlayerDropdown.Refresh then
                pcall(function() TargetPlayerDropdown:Refresh(getOtherPlayers()) end)
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- Forward declarations for elements used by category callbacks
    local SelectedParagraph = nil -- Will be assigned later
    
    -- ========================================
    -- QUICK SELECT CATEGORY SECTION
    -- ========================================
    local CategorySection = Tab:Section({
        Title = "Quick Select by Category",
        Icon = "lucide:folder",
        Box = true,
        BoxBorder = true,
        Opened = false, -- Start collapsed
    })
    
    -- Store category dropdowns for refresh
    local CategoryDropdowns = {}
    
    -- Scan button in category section
    CategorySection:Button({
        Title = "Scan Items",
        Icon = "lucide:refresh-cw",
        Desc = "Refresh item list",
        Callback = function()
            if ItemCollector then
                local cache = ItemCollector.ScanItems()
                
                -- Update category dropdowns
                if ItemCollector.GetItemsByCategory then
                    for catName, dropdown in pairs(CategoryDropdowns) do
                        local catItems = ItemCollector.GetItemsByCategory(catName)
                        if dropdown and dropdown.Refresh then
                            local items = #catItems > 0 and catItems or {"(No items)"}
                            pcall(function() dropdown:Refresh(items) end)
                        end
                    end
                end
                
                if WindUI then
                    local totalItems = 0
                    local totalTypes = 0
                    for _, data in pairs(cache) do
                        totalItems = totalItems + data.count
                        totalTypes = totalTypes + 1
                    end
                    WindUI:Notify({
                        Title = "Auto Collect",
                        Content = "Scanned " .. totalItems .. " items (" .. totalTypes .. " types)",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    -- Auto Rescan toggle for category section
    CategorySection:Toggle({
        Title = "Auto Rescan",
        Icon = "lucide:refresh-cw",
        Desc = "Update counts after each collection",
        Value = false,
        Callback = function(v)
            if ItemCollector and ItemCollector.SetAutoRescan then
                ItemCollector.SetAutoRescan(v)
            end
        end,
    })
    
    -- Selected items display in category section
    local CategorySelectedParagraph = CategorySection:Paragraph({
        Title = "📋 Selected Items",
        Desc = "(none)",
    })
    
    -- Clear All button for all selections
    CategorySection:Button({
        Title = "❌ Clear All",
        Icon = "lucide:x-square",
        Desc = "Clear all selected items",
        Callback = function()
            if ItemCollector and ItemCollector.ClearSelection then
                ItemCollector.ClearSelection()
                
                -- Update both paragraphs
                if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc then
                    CategorySelectedParagraph:SetDesc("(none)")
                end
                if SelectedParagraph and SelectedParagraph.SetDesc then
                    SelectedParagraph:SetDesc("(none)")
                end
                
                if WindUI then
                    WindUI:Notify({
                        Title = "Auto Collect",
                        Content = "All selections cleared",
                        Duration = 2,
                    })
                end
            end
        end,
    })
    
    -- Helper function to create category dropdown with icon
    local function createCategoryDropdown(categoryName, categoryIcon)
        -- Track previous selection for this dropdown
        local previousSelected = {}
        local isInitializing = true -- Flag to skip callback during creation
        
        local dropdown = CategorySection:Dropdown({
            Title = categoryName,
            Icon = categoryIcon,
            Desc = "Select items from this category",
            Multi = true,
            AllowNone = true,
            Value = {},
            Values = {"(Click Scan first)"},
            Callback = function(selected)
                -- Skip callback during initialization
                if isInitializing then return end
                if not ItemCollector then return end
                
                -- Convert selected to normalized format {["Item Name"] = true}
                local normalizedSelected = {}
                for key, value in pairs(selected) do
                    local itemKey = nil
                    if type(key) == "number" and type(value) == "string" then
                        itemKey = value
                    elseif type(key) == "string" and value == true then
                        itemKey = key
                    end
                    if itemKey then
                        normalizedSelected[itemKey] = true
                    end
                end
                
                -- Find newly added items
                for itemKey, _ in pairs(normalizedSelected) do
                    if not previousSelected[itemKey] then
                        local itemName = ItemCollector.ParseItemName(itemKey)
                        if itemName then
                            ItemCollector.AddToSelection(itemName)
                        end
                    end
                end
                
                -- Find removed items
                for itemKey, _ in pairs(previousSelected) do
                    if not normalizedSelected[itemKey] then
                        local itemName = ItemCollector.ParseItemName(itemKey)
                        if itemName then
                            ItemCollector.RemoveFromSelection(itemName)
                        end
                    end
                end
                
                -- Update previous selection tracking
                previousSelected = normalizedSelected
                
                -- Update both SelectedParagraph displays
                local items = ItemCollector.GetSelectedItems()
                local displayText = "(none)"
                if items and #items > 0 then
                    local displayList = {}
                    local cache = ItemCollector.GetCache()
                    for _, name in ipairs(items) do
                        local count = cache[name] and cache[name].count or 0
                        table.insert(displayList, name .. " (" .. count .. ")")
                    end
                    displayText = "• " .. table.concat(displayList, "\n• ")
                end
                
                -- Update Category section paragraph
                if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc then
                    CategorySelectedParagraph:SetDesc(displayText)
                end
                
                -- Update Item section paragraph
                if SelectedParagraph and SelectedParagraph.SetDesc then
                    SelectedParagraph:SetDesc(displayText)
                end
            end,
        })
        CategoryDropdowns[categoryName] = dropdown
        isInitializing = false -- Now safe for callbacks
        
        -- Add Select All button for this category
        CategorySection:Button({
            Title = "Select All " .. categoryName,
            Icon = "lucide:check-square",
            Desc = "Select all items in " .. categoryName,
            Callback = function()
                if ItemCollector and ItemCollector.GetItemsByCategory then
                    local categoryItems = ItemCollector.GetItemsByCategory(categoryName)
                    local added = 0
                    for _, formattedName in ipairs(categoryItems) do
                        local itemName = ItemCollector.ParseItemName(formattedName)
                        if itemName then
                            if ItemCollector.AddToSelection(itemName) then
                                added = added + 1
                            end
                        end
                    end
                    
                    -- Update both SelectedParagraphs
                    local items = ItemCollector.GetSelectedItems()
                    if items and #items > 0 then
                        local displayList = {}
                        local cache = ItemCollector.GetCache()
                        for _, name in ipairs(items) do
                            local count = cache[name] and cache[name].count or 0
                            table.insert(displayList, name .. " (" .. count .. ")")
                        end
                        local displayText = "• " .. table.concat(displayList, "\n• ")
                        if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc then
                            CategorySelectedParagraph:SetDesc(displayText)
                        end
                        if SelectedParagraph and SelectedParagraph.SetDesc then
                            SelectedParagraph:SetDesc(displayText)
                        end
                    end
                    
                    if WindUI and added > 0 then
                        WindUI:Notify({
                            Title = categoryName,
                            Content = "Added " .. added .. " items",
                            Duration = 2,
                        })
                    end
                end
            end,
        })
        
        -- Add Clear button for this category
        CategorySection:Button({
            Title = "Clear " .. categoryName,
            Icon = "lucide:x-square",
            Desc = "Deselect all " .. categoryName .. " items",
            Callback = function()
                if ItemCollector and ItemCollector.GetItemsByCategory then
                    local categoryItems = ItemCollector.GetItemsByCategory(categoryName)
                    local removed = 0
                    for _, formattedName in ipairs(categoryItems) do
                        local itemName = ItemCollector.ParseItemName(formattedName)
                        if itemName then
                            if ItemCollector.RemoveFromSelection(itemName) then
                                removed = removed + 1
                            end
                        end
                    end
                    
                    -- Update both SelectedParagraphs
                    local items = ItemCollector.GetSelectedItems()
                    local displayText = "(none)"
                    if items and #items > 0 then
                        local displayList = {}
                        local cache = ItemCollector.GetCache()
                        for _, name in ipairs(items) do
                            local count = cache[name] and cache[name].count or 0
                            table.insert(displayList, name .. " (" .. count .. ")")
                        end
                        displayText = "• " .. table.concat(displayList, "\n• ")
                    end
                    if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc then
                        CategorySelectedParagraph:SetDesc(displayText)
                    end
                    if SelectedParagraph and SelectedParagraph.SetDesc then
                        SelectedParagraph:SetDesc(displayText)
                    end
                    
                    if WindUI and removed > 0 then
                        WindUI:Notify({
                            Title = categoryName,
                            Content = "Removed " .. removed .. " items",
                            Duration = 2,
                        })
                    end
                end
            end,
        })
        
        return dropdown
    end
    
    -- Create dropdown for each category (except Blacklist)
    if ItemCollector and ItemCollector.GetCategories then
        local categories = ItemCollector.GetCategories()
        for _, cat in ipairs(categories) do
            if cat.name ~= "Blacklist" then -- Skip blacklist
                createCategoryDropdown(cat.name, cat.icon)
            end
        end
    else
        -- Fallback if GetCategories not available yet
        createCategoryDropdown("Campfire", "lucide:flame")
        createCategoryDropdown("Scrapper", "lucide:recycle")
        createCategoryDropdown("Anvil", "lucide:hammer")
        createCategoryDropdown("Armor", "lucide:shield")
        createCategoryDropdown("Weapons", "lucide:sword")
        createCategoryDropdown("Tools", "lucide:wrench")
        createCategoryDropdown("Food", "lucide:drumstick")
        createCategoryDropdown("Animal Parts", "lucide:paw-print")
        createCategoryDropdown("Containers", "lucide:package")
    end
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- ITEM SELECTION SECTION
    -- ========================================
    local ItemSection = Tab:Section({
        Title = "Item Selection",
        Icon = "lucide:box",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    -- Stats paragraph
    local StatsParagraph = ItemSection:Paragraph({
        Title = "📊 Scan Status",
        Desc = "Click 'Scan Items' to refresh",
    })
    
    -- Store dropdown reference
    local ItemsDropdown = nil
    local AvailableItems = {"(Click Scan Items)"}
    local isAutoRefreshing = false -- Flag to prevent callback loop during auto-refresh
    
    -- Scan button
    ItemSection:Button({
        Title = "🔄 Scan Items",
        Desc = "Refresh item list from workspace",
        Callback = function()
            if ItemCollector then
                local cache = ItemCollector.ScanItems()
                local list = ItemCollector.GetItemList()
                AvailableItems = #list > 0 and list or {"No items found"}
                
                -- Update main dropdown
                if ItemsDropdown and ItemsDropdown.Refresh then
                    pcall(function() ItemsDropdown:Refresh(AvailableItems) end)
                end
                
                -- Update category dropdowns
                if ItemCollector.GetItemsByCategory then
                    for catName, dropdown in pairs(CategoryDropdowns) do
                        local catItems = ItemCollector.GetItemsByCategory(catName)
                        if dropdown and dropdown.Refresh then
                            local items = #catItems > 0 and catItems or {"(No items)"}
                            pcall(function() dropdown:Refresh(items) end)
                        end
                    end
                end
                
                -- Update stats
                local totalItems = 0
                local totalTypes = 0
                for name, data in pairs(cache) do
                    totalItems = totalItems + data.count
                    totalTypes = totalTypes + 1
                end
                
                if StatsParagraph and StatsParagraph.SetDesc then
                    StatsParagraph:SetDesc("Found " .. totalItems .. " items (" .. totalTypes .. " types)")
                end
                
                if WindUI then
                    WindUI:Notify({
                        Title = "Auto Collect",
                        Content = "Scanned " .. totalItems .. " items (" .. totalTypes .. " types)",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    -- Auto Rescan toggle
    ItemSection:Toggle({
        Title = "🔁 Auto Rescan",
        Desc = "Update counts after each collection",
        Value = false,
        Callback = function(v)
            if ItemCollector and ItemCollector.SetAutoRescan then
                ItemCollector.SetAutoRescan(v)
            end
        end,
    })
    
    -- Select All button for Item Section
    ItemSection:Button({
        Title = "✅ Select All",
        Desc = "Select all available items",
        Callback = function()
            if ItemCollector then
                local allItems = ItemCollector.GetItemNames()
                for _, name in ipairs(allItems) do
                    ItemCollector.AddToSelection(name)
                end
                
                -- Update SelectedParagraph
                if SelectedParagraph and SelectedParagraph.SetDesc then
                    local items = ItemCollector.GetSelectedItems()
                    if items and #items > 0 then
                        local displayList = {}
                        local cache = ItemCollector.GetCache()
                        for _, name in ipairs(items) do
                            local count = cache[name] and cache[name].count or 0
                            table.insert(displayList, name .. " (" .. count .. ")")
                        end
                        SelectedParagraph:SetDesc("• " .. table.concat(displayList, "\n• "))
                    end
                end
                
                if WindUI then
                    WindUI:Notify({
                        Title = "Auto Collect",
                        Content = "Selected all " .. #allItems .. " items",
                        Duration = 2,
                    })
                end
            end
        end,
    })
    
    -- Clear All button for Item Section
    ItemSection:Button({
        Title = "❌ Clear All",
        Desc = "Deselect all items",
        Callback = function()
            if ItemCollector and ItemCollector.ClearSelection then
                ItemCollector.ClearSelection()
                
                -- Update SelectedParagraph
                if SelectedParagraph and SelectedParagraph.SetDesc then
                    SelectedParagraph:SetDesc("(none)")
                end
                
                if WindUI then
                    WindUI:Notify({
                        Title = "Auto Collect",
                        Content = "Selection cleared",
                        Duration = 2,
                    })
                end
            end
        end,
    })
    
    -- Selected items paragraph (assign to forward-declared variable)
    SelectedParagraph = ItemSection:Paragraph({
        Title = "📋 Selected Items",
        Desc = "(none)",
    })
    
    -- Items dropdown (multi-select)
    ItemsDropdown = ItemSection:Dropdown({
        Flag = "AutoCollect.SelectedItems",
        Title = "Select Items",
        Desc = "Choose item types to collect",
        Multi = true,
        AllowNone = true,
        Value = {},
        Values = AvailableItems,
        Callback = function(selected)
            -- Skip callback during auto-refresh to prevent loop
            if isAutoRefreshing then return end
            
            if ItemCollector then
                ItemCollector.SetSelectedItems(selected)
                
                -- Update selected paragraph
                local list = {}
                for k, v in pairs(selected) do
                    if v == true then
                        table.insert(list, k)
                    elseif type(k) == "number" and type(v) == "string" then
                        table.insert(list, v)
                    end
                end
                
                local text = #list > 0 and ("• " .. table.concat(list, "\n• ")) or "(none)"
                if SelectedParagraph and SelectedParagraph.SetDesc then
                    SelectedParagraph:SetDesc(text)
                end
            end
        end,
    })
    
    -- Clear selection button
    ItemSection:Button({
        Title = "❌ Clear Selection",
        Callback = function()
            if ItemsDropdown and ItemsDropdown.Select then
                pcall(function() ItemsDropdown:Select() end)
            end
            if ItemCollector then
                ItemCollector.SetSelectedItems({})
            end
            if SelectedParagraph and SelectedParagraph.SetDesc then
                SelectedParagraph:SetDesc("(none)")
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- QUANTITY SETTINGS
    -- ========================================
    local QuantitySection = Tab:Section({
        Title = "Quantity",
        Icon = "lucide:hash",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    QuantitySection:Slider({
        Flag = "AutoCollect.GlobalLimit",
        Title = "Max Per Type",
        Desc = "Maximum items to collect per type",
        Value = { Min = 25, Max = 2000, Default = 50 },
        Step = 25,
        Callback = function(value)
            if ItemCollector then
                ItemCollector.SetGlobalLimit(value)
            end
        end,
    })
    
    QuantitySection:Slider({
        Flag = "AutoCollect.DropHeight",
        Title = "Drop Height",
        Desc = "Height offset for dropping items (studs)",
        Value = { Min = 0, Max = 20, Default = 0 },
        Step = 1,
        Callback = function(value)
            if ItemCollector then
                ItemCollector.SetDropHeight(value)
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- ORGANIZATION SECTION
    -- ========================================
    local OrgSection = Tab:Section({
        Title = "Organization",
        Icon = "lucide:layout-grid",
        Box = true,
        BoxBorder = true,
        Opened = false,
    })
    
    OrgSection:Toggle({
        Flag = "AutoCollect.OrganizeEnabled",
        Title = "Enable Organization",
        Desc = "Arrange items in grid/line pattern instead of stacking",
        Value = false,
        Callback = function(state)
            if ItemCollector then
                ItemCollector.SetOrganizeEnabled(state)
            end
        end,
    })
    
    OrgSection:Dropdown({
        Flag = "AutoCollect.OrganizeMode",
        Title = "Organization Mode",
        Desc = "Pattern for arranging items",
        Value = "Grid",
        Values = {"Grid", "Line"},
        Callback = function(value)
            if ItemCollector then
                ItemCollector.SetOrganizeMode(value)
            end
        end,
    })
    
    OrgSection:Slider({
        Flag = "AutoCollect.GridSpacing",
        Title = "Spacing",
        Desc = "Gap between items (studs)",
        Value = { Min = 0, Max = 10, Default = 1 },
        Step = 0.5,
        Callback = function(value)
            if ItemCollector then
                ItemCollector.SetGridSpacing(value)
            end
        end,
    })
    
    OrgSection:Slider({
        Flag = "AutoCollect.MaxLayers",
        Title = "Stack Layers",
        Desc = "Vertical layers (1-2) for 3D stacking",
        Value = { Min = 1, Max = 2, Default = 1 },
        Step = 1,
        Callback = function(value)
            if ItemCollector then
                ItemCollector.SetMaxLayers(value)
            end
        end,
    })
    
    OrgSection:Toggle({
        Flag = "AutoCollect.ShowPreview",
        Title = "Show Preview",
        Desc = "Display where items will be placed",
        Value = false,
        Callback = function(state)
            if ItemCollector then
                ItemCollector.TogglePreview(state)
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- SPEED SETTINGS
    -- ========================================
    local SpeedSection = Tab:Section({
        Title = "Speed",
        Icon = "lucide:zap",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    
    SpeedSection:Dropdown({
        Flag = "AutoCollect.Speed",
        Title = "Collection Speed",
        Desc = "Delay between item drags",
        Value = "Fast",
        Values = {"Instant", "Fast", "Normal", "Slow"},
        Callback = function(value)
            if ItemCollector then
                ItemCollector.SetSpeed(value)
            end
        end,
    })
    
    SpeedSection:Paragraph({
        Title = "ℹ️ Speed Info",
        Desc = "Instant: ~60/sec | Fast: ~33/sec | Normal: 10/sec | Slow: ~3/sec",
    })
    
    -- Register callback for auto-refresh
    if ItemCollector and ItemCollector.SetOnScanCallback then
        ItemCollector.SetOnScanCallback(function(cache, itemsWereRemoved)
            -- This runs when ItemCollector.ScanItems() or ScanSelectedOnly() finishes
            
            -- Update stats (only count selected items in lightweight mode)
            local totalItems = 0
            local totalTypes = 0
            for name, data in pairs(cache) do
                totalItems = totalItems + data.count
                totalTypes = totalTypes + 1
            end
            
            if StatsParagraph and StatsParagraph.SetDesc then
                StatsParagraph:SetDesc("Found " .. totalItems .. " items (" .. totalTypes .. " types)")
            end
            
            -- Update SelectedParagraph with CURRENT counts from cache
            if SelectedParagraph and SelectedParagraph.SetDesc and ItemCollector.GetSelectedItems then
                local selectedItems = ItemCollector.GetSelectedItems()
                if #selectedItems > 0 then
                    local displayList = {}
                    for _, itemName in ipairs(selectedItems) do
                        local cacheEntry = cache[itemName]
                        local count = cacheEntry and cacheEntry.count or 0
                        table.insert(displayList, itemName .. " (" .. count .. ")")
                    end
                    SelectedParagraph:SetDesc("• " .. table.concat(displayList, "\n• "))
                else
                    SelectedParagraph:SetDesc("(none)")
                end
            end
            
            -- Refresh Category Dropdowns
            if ItemCollector.GetItemsByCategory then
                for catName, dropdown in pairs(CategoryDropdowns) do
                    local catItems = ItemCollector.GetItemsByCategory(catName)
                    -- Only refresh if we have a refresh method
                    if dropdown and dropdown.Refresh then
                        local items = #catItems > 0 and catItems or {"(No items)"}
                        pcall(function() dropdown:Refresh(items) end)
                    end
                end
            end
            
            -- Update CategorySelectedParagraph with CURRENT counts
            if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc and ItemCollector.GetSelectedItems then
                local selectedItems = ItemCollector.GetSelectedItems()
                local displayText = "(none)"
                if #selectedItems > 0 then
                    local displayList = {}
                    for _, itemName in ipairs(selectedItems) do
                        local cacheEntry = cache[itemName]
                        local count = cacheEntry and cacheEntry.count or 0
                        table.insert(displayList, itemName .. " (" .. count .. ")")
                    end
                    displayText = "• " .. table.concat(displayList, "\n• ")
                end
                CategorySelectedParagraph:SetDesc(displayText)
            end
            
            -- Refresh dropdown ONLY when items were removed (to clear 0-count items)
            if itemsWereRemoved then
                local list = ItemCollector.GetItemList()
                AvailableItems = #list > 0 and list or {"No items found"}
                if ItemsDropdown then
                    isAutoRefreshing = true  -- Prevent callback loop
                    
                    -- Refresh the list
                    if ItemsDropdown.Refresh then
                        pcall(function() ItemsDropdown:Refresh(AvailableItems) end)
                    end
                    
                    -- Update display text (clear selection since items were removed)
                    if ItemsDropdown.Select then
                        pcall(function() ItemsDropdown:Select({}) end)
                    end
                    
                    isAutoRefreshing = false
                end
            end
        end)
    end
    
    return Tab
end

return AutoCollectTab
