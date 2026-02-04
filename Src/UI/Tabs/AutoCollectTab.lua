--[[
    UI/Tabs/AutoCollectTab.lua
    Auto Collect tab UI - Collect items from workspace.Items
    REWRITTEN: Fix UI Sync (Clear All), Smart Refresh
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
        Values = {"Player", "Campfire", "Scrapper", "OtherPlayer", "StorageBox"},
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
    
    -- Exclude Nearby Section
    DestSection:Toggle({
        Flag = "AutoCollect.ExcludeNearby",
        Title = "⭕ Exclude Nearby Items",
        Icon = "lucide:circle-off",
        Desc = "Skip items within radius of player (Player/OtherPlayer only)",
        Value = false,
        Callback = function(v)
            if ItemCollector and ItemCollector.SetExcludeNearbyEnabled then
                ItemCollector.SetExcludeNearbyEnabled(v)
            end
        end,
    })
    
    DestSection:Slider({
        Flag = "AutoCollect.ExcludeRadius",
        Title = "Exclude Radius",
        Desc = "Items within this distance are skipped (studs)",
        Value = {Min = 5, Max = 100, Default = 20},
        Step = 5,
        Callback = function(v)
            if ItemCollector and ItemCollector.SetExcludeRadius then
                ItemCollector.SetExcludeRadius(v)
            end
        end,
    })
    
    DestSection:Toggle({
        Flag = "AutoCollect.FixedPosition",
        Title = "📍 Fixed Position",
        Icon = "lucide:pin",
        Desc = "Lock drop position at start (Player/OtherPlayer only)",
        Value = false,
        Callback = function(v)
            if ItemCollector and ItemCollector.SetFixedPosition then
                ItemCollector.SetFixedPosition(v)
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- Forward declarations
    local SelectedParagraph = nil 
    local CategorySelectedParagraph = nil -- Declare here to be safe
    local CategoryDropdowns = {} -- Store references
    
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
    
    -- Scan button in category section
    CategorySection:Button({
        Title = "Scan Items",
        Icon = "lucide:refresh-cw",
        Desc = "Refresh item list",
        Callback = function()
            if ItemCollector then
                local cache = ItemCollector.ScanItems()
                -- (Note: Auto-refresh logic runs in SetOnScanCallback below)
                
                if WindUI then
                    local totalTypes = 0
                    for _ in pairs(cache) do
                        totalTypes = totalTypes + 1
                    end
                    WindUI:Notify({
                        Title = "Auto Collect",
                        Content = "Found " .. totalTypes .. " item types",
                        Duration = 3,
                    })
                end
            end
        end,
    })
    
    
    CategorySelectedParagraph = CategorySection:Paragraph({
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
                
                -- 1. Visually clear ALL Category Dropdowns (FIXED)
                for catName, dropdown in pairs(CategoryDropdowns) do
                    if dropdown and dropdown.Select then
                        pcall(function() dropdown:Select({}) end)
                    end
                end
                
                -- 2. Update both paragraphs
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
    
    local function createCategoryDropdown(categoryName, categoryIcon)
        local previousSelected = {}
        local isInitializing = true
        
        local dropdown = CategorySection:Dropdown({
            Title = categoryName,
            Icon = categoryIcon,
            Desc = "Select items from this category",
            Multi = true,
            AllowNone = true,
            Value = {},
            Values = {"(Click Scan first)"},
            Callback = function(selected)
                if isInitializing then return end
                if not ItemCollector then return end
                
                local normalizedSelected = {}
                for key, value in pairs(selected) do
                    local itemKey = nil
                    if type(key) == "number" and type(value) == "string" then
                        itemKey = value
                    elseif type(key) == "string" and value == true then
                        itemKey = key
                    end
                    if itemKey then normalizedSelected[itemKey] = true end
                end
                
                -- Add newly selected
                for itemKey, _ in pairs(normalizedSelected) do
                    if not previousSelected[itemKey] then
                        local itemName = ItemCollector.ParseItemName(itemKey)
                        if itemName then ItemCollector.AddToSelection(itemName) end
                    end
                end
                
                -- Remove deselected
                for itemKey, _ in pairs(previousSelected) do
                    if not normalizedSelected[itemKey] then
                         -- CHECK: Is this item actually deselected, or did the name just change?
                         -- For now, explicit deselect removes it.
                        local itemName = ItemCollector.ParseItemName(itemKey)
                        if itemName then ItemCollector.RemoveFromSelection(itemName) end
                    end
                end
                
                -- Create a COPY of normalizedSelected to avoid reference issues (Bug #9 fix)
                local previousCopy = {}
                for k, v in pairs(normalizedSelected) do previousCopy[k] = v end
                previousSelected = previousCopy
                
                -- Update Paragraphs (names only, no counts)
                local items = ItemCollector.GetSelectedItems()
                local displayText = "(none)"
                if items and #items > 0 then
                    displayText = "• " .. table.concat(items, "\n• ")
                end
                
                if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc then
                    CategorySelectedParagraph:SetDesc(displayText)
                end
                if SelectedParagraph and SelectedParagraph.SetDesc then
                    SelectedParagraph:SetDesc(displayText)
                end
            end,
        })
        CategoryDropdowns[categoryName] = dropdown
        isInitializing = false
        
        -- Add Select All button
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
                        if itemName and ItemCollector.AddToSelection(itemName) then
                             added = added + 1
                        end
                    end
                    
                    -- UPDATE PARAGRAPHS (names only, no counts)
                    local items = ItemCollector.GetSelectedItems()
                    local displayText = "(none)"
                    if items and #items > 0 then
                        displayText = "• " .. table.concat(items, "\n• ")
                    end
                    if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc then
                        CategorySelectedParagraph:SetDesc(displayText)
                    end
                    if SelectedParagraph and SelectedParagraph.SetDesc then
                        SelectedParagraph:SetDesc(displayText)
                    end
                    
                    -- Trigger visual refresh via main callback loop later
                    if WindUI then WindUI:Notify({Title=categoryName, Content="Added "..added.." items", Duration=2}) end
                end
            end,
        })
        
        -- Add Start Collect button (quick access)
        CategorySection:Button({
            Title = "▶️ Start Collect",
            Icon = "lucide:play",
            Desc = "Start collecting selected items",
            Callback = function()
                if ItemCollector then
                    ItemCollector.Start()
                    if WindUI then WindUI:Notify({Title="Auto Collect", Content="Collection started!", Duration=2}) end
                end
            end,
        })
        
        return dropdown
    end
    
    if ItemCollector and ItemCollector.GetCategories then
        for _, cat in ipairs(ItemCollector.GetCategories()) do
            if cat.name ~= "Blacklist" then createCategoryDropdown(cat.name, cat.icon) end
        end
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
    
    local StatsParagraph = ItemSection:Paragraph({
        Title = "📊 Scan Status",
        Desc = "Click 'Scan Items' to refresh",
    })
    
    local ItemsDropdown = nil
    local AvailableItems = {"(Click Scan Items)"}
    local isAutoRefreshing = false
    
    ItemSection:Button({
        Title = "🔄 Scan Items",
        Desc = "Refresh item list from workspace",
        Callback = function()
            if ItemCollector then ItemCollector.ScanItems() end
        end,
    })
    
    -- Select All (Global)
    ItemSection:Button({
        Title = "✅ Select All",
        Desc = "Select all available items",
        Callback = function()
            if ItemCollector then
                local allItems = ItemCollector.GetItemNames()
                local count = 0
                for _, name in ipairs(allItems) do 
                    if ItemCollector.AddToSelection(name) then
                        count = count + 1
                    end
                end
                
                if WindUI then WindUI:Notify({Title="Auto Collect", Content="Selected " .. count .. " items", Duration=2}) end
            end
        end,
    })

    -- Clear All (Global)
    ItemSection:Button({
        Title = "❌ Clear All",
        Desc = "Deselect all items",
        Callback = function()
            if ItemCollector and ItemCollector.ClearSelection then
                ItemCollector.ClearSelection()
                 -- Visually clear ALL dropdowns
                for _, dropdown in pairs(CategoryDropdowns) do
                    if dropdown and dropdown.Select then pcall(function() dropdown:Select({}) end) end
                end
                if ItemsDropdown and ItemsDropdown.Select then pcall(function() ItemsDropdown:Select({}) end) end
                
                -- Update Paragraphs
                if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc then CategorySelectedParagraph:SetDesc("(none)") end
                if SelectedParagraph and SelectedParagraph.SetDesc then SelectedParagraph:SetDesc("(none)") end
                
                print("[ItemCollector UI] Cleared ALL selections via UI.")
                if WindUI then WindUI:Notify({Title="Auto Collect", Content="Selection cleared", Duration=2}) end
            end
        end,
    })
    
    SelectedParagraph = ItemSection:Paragraph({
        Title = "📋 Selected Items",
        Desc = "(none)",
    })
    
    ItemsDropdown = ItemSection:Dropdown({
        Flag = "AutoCollect.SelectedItems",
        Title = "Select Items",
        Desc = "Choose item types to collect",
        Multi = true,
        AllowNone = true,
        Value = {},
        Values = AvailableItems,
        Callback = function(selected)
            if isAutoRefreshing then return end
            if ItemCollector then
                -- Debug: Track manual selection changes
                local count = 0
                for k, v in pairs(selected) do if v == true then count = count + 1 end end
                print("[ItemCollector UI] Selection updated manually. Count: " .. count)

                ItemCollector.SetSelectedItems(selected)
                -- Update paragraph
                local list = {}
                 for k, v in pairs(selected) do
                    if v == true then table.insert(list, k)
                    elseif type(k) == "number" and type(v) == "string" then table.insert(list, v) end
                end
                local text = #list > 0 and ("• " .. table.concat(list, "\n• ")) or "(none)"
                if SelectedParagraph and SelectedParagraph.SetDesc then SelectedParagraph:SetDesc(text) end
            end
        end,
    })
    
    Tab:Space({ Size = 10 })
    
    -- ========================================
    -- QUANTITY & ORG SECTIONS (Kept compact)
    -- ========================================
    local QuantitySection = Tab:Section({Title = "Quantity", Icon = "lucide:hash", Box = true, BoxBorder = true, Opened = true})
    QuantitySection:Slider({Flag = "AutoCollect.GlobalLimit", Title = "Max Per Type", Desc = "Maximum items to collect per type", Value = {Min=25, Max=2000, Default=50}, Step=25, Callback = function(v) if ItemCollector then ItemCollector.SetGlobalLimit(v) end end})
    QuantitySection:Slider({Flag = "AutoCollect.DropHeight", Title = "Drop Height", Desc = "Height offset (studs)", Value = {Min=0, Max=20, Default=0}, Step=1, Callback = function(v) if ItemCollector then ItemCollector.SetDropHeight(v) end end})
    
    Tab:Space({ Size = 10 })
    
    local SpeedSection = Tab:Section({Title = "Speed", Icon = "lucide:zap", Box = true, BoxBorder = true, Opened = true})
    SpeedSection:Dropdown({Flag = "AutoCollect.Speed", Title = "Collection Speed", Desc = "Delay between item drags", Value = "Fast", Values = {"Instant", "Fast", "Normal", "Slow"}, Callback = function(v) if ItemCollector then ItemCollector.SetSpeed(v) end end})
    SpeedSection:Paragraph({Title = "ℹ️ Speed Info", Desc = "Instant: ~60/sec | Fast: ~33/sec | Normal: 10/sec | Slow: ~3/sec"})

    -- ========================================
    -- SCAN CALLBACK (SIMPLIFIED - NO COUNTS)
    -- ========================================
    if ItemCollector and ItemCollector.SetOnScanCallback then
        ItemCollector.SetOnScanCallback(function(cache)
            -- Count unique item types (cache is now just {name = true, ...})
            local totalTypes = 0
            for _ in pairs(cache) do
                totalTypes = totalTypes + 1
            end
            if StatsParagraph and StatsParagraph.SetDesc then 
                StatsParagraph:SetDesc("Found " .. totalTypes .. " item types") 
            end
            
            -- Get currently selected names
            local selectedItems = ItemCollector.GetSelectedItems()
            local selectedLookup = {}
            for _, name in ipairs(selectedItems) do selectedLookup[name] = true end
            
            -- Update paragraphs (names only)
            local displayText = #selectedItems > 0 and ("• " .. table.concat(selectedItems, "\n• ")) or "(none)"
            if SelectedParagraph and SelectedParagraph.SetDesc then SelectedParagraph:SetDesc(displayText) end
            if CategorySelectedParagraph and CategorySelectedParagraph.SetDesc then CategorySelectedParagraph:SetDesc(displayText) end
            
            -- REFRESH CATEGORY DROPDOWNS
            if ItemCollector.GetItemsByCategory then
                for catName, dropdown in pairs(CategoryDropdowns) do
                    local catItems = ItemCollector.GetItemsByCategory(catName)
                    if dropdown and dropdown.Refresh then
                        local items = #catItems > 0 and catItems or {"(No items)"}
                        
                        -- Re-select items that are currently selected
                        local newVisualSelection = {}
                        for _, itemName in ipairs(items) do
                            if selectedLookup[itemName] then
                                table.insert(newVisualSelection, itemName)
                            end
                        end
                        
                        pcall(function() 
                            dropdown:Refresh(items)
                            if #newVisualSelection > 0 then
                                dropdown:Select(newVisualSelection)
                            end
                        end)
                    end
                end
            end
            
            -- REFRESH MAIN ITEM DROPDOWN
            if ItemsDropdown then
                local list = ItemCollector.GetItemList()
                AvailableItems = #list > 0 and list or {"No items found"}
                
                local newVisualSelection = {}
                for _, itemName in ipairs(list) do
                    if selectedLookup[itemName] then
                        table.insert(newVisualSelection, itemName)
                    end
                end
                
                isAutoRefreshing = true 
                pcall(function()
                    ItemsDropdown:Refresh(AvailableItems)
                    if #newVisualSelection > 0 then
                        ItemsDropdown:Select(newVisualSelection)
                    end
                end)
                isAutoRefreshing = false
            end
        end)
    end
    
    return Tab
end

return AutoCollectTab
