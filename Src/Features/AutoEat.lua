--[[
    Features/AutoEat.lua
    Auto Eat feature module
]]

local AutoEat = {}

-- ============================================
-- DEPENDENCIES
-- ============================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Will be set by Init()
local Utils = nil
local Remote = nil
local WindUI = nil

-- ============================================
-- FOOD CATALOG
-- ============================================
local FoodCatalog = {
    ["Cooked Steak"] = 100,
    ["Cake"] = 80,
    ["Cooked Morsel"] = 60,
    ["Apple"] = 40,
    ["Carrot"] = 35,
    ["Berry"] = 30,
    ["Morsel"] = 20,
}

-- ============================================
-- SETTINGS & STATE
-- ============================================
local Settings = {
    HungerThreshold = 80,
    AllowedFoods = {},
    EatCooldown = 0.5,
}

local Stats = {
    TotalEaten = 0,
    HungerGained = 0,
}

local State = {
    Enabled = false,
    Thread = nil,
}

local LOW_FOOD_THRESHOLD = 3

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function isFood(itemName)
    if FoodCatalog[itemName] then
        return true
    end
    local keywords = {"Steak", "Cake", "Morsel", "Apple", "Berry", "Fish", "Meat", "Cooked", "Kiwi", "Carrot"}
    for _, keyword in ipairs(keywords) do
        if string.find(itemName, keyword) then
            return true
        end
    end
    return false
end

local function isFoodAllowed(itemName)
    local allowed = Settings.AllowedFoods
    if allowed == nil or type(allowed) ~= "table" then
        return true
    end
    if #allowed == 0 then
        return true
    end
    for _, foodName in ipairs(allowed) do
        if foodName == itemName then
            return true
        end
    end
    return false
end

local function getFoodValue(itemName)
    return FoodCatalog[itemName] or 20
end

local function getPlayerPosition()
    if Utils and Utils.getRoot then
        local root = Utils.getRoot()
        if root then return root.Position end
    end
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then return root.Position end
    end
    return nil
end

local function getHunger()
    if Utils and Utils.getStat then
        return Utils.getStat("Hunger") or 200
    end
    return LocalPlayer:GetAttribute("Hunger") or 200
end

-- ============================================
-- FOOD COLLECTION
-- ============================================
local function collectAvailableFood()
    local foods = {}
    local playerPos = getPlayerPosition()
    
    -- Source 1: ItemBag
    local itemBag = LocalPlayer:FindFirstChild("ItemBag")
    if itemBag then
        for _, item in ipairs(itemBag:GetChildren()) do
            if isFood(item.Name) and isFoodAllowed(item.Name) then
                table.insert(foods, {
                    Item = item,
                    Name = item.Name,
                    Value = getFoodValue(item.Name),
                    Source = "Bag",
                    Distance = 0,
                })
            end
        end
    end
    
    -- Source 2: Inventory bags
    local inventory = LocalPlayer:FindFirstChild("Inventory")
    if inventory then
        for _, bag in ipairs(inventory:GetChildren()) do
            if bag:IsA("Model") or bag:IsA("Folder") then
                for _, item in ipairs(bag:GetChildren()) do
                    if isFood(item.Name) and isFoodAllowed(item.Name) then
                        table.insert(foods, {
                            Item = item,
                            Name = item.Name,
                            Value = getFoodValue(item.Name),
                            Source = "Bag",
                            Distance = 0,
                        })
                    end
                end
            end
        end
    end
    
    -- Source 3: TempStorage (hand)
    local tempStorage = ReplicatedStorage:FindFirstChild("TempStorage")
    if tempStorage then
        for _, item in ipairs(tempStorage:GetChildren()) do
            if isFood(item.Name) and isFoodAllowed(item.Name) then
                table.insert(foods, {
                    Item = item,
                    Name = item.Name,
                    Value = getFoodValue(item.Name),
                    Source = "Hand",
                    Distance = 0,
                })
            end
        end
    end
    
    -- Source 4: World Items
    local worldItems = workspace:FindFirstChild("Items")
    if worldItems and playerPos then
        for _, item in ipairs(worldItems:GetChildren()) do
            if isFood(item.Name) and isFoodAllowed(item.Name) then
                -- Safe position getter with fallback
                local itemPos
                local success = pcall(function()
                    itemPos = item:GetPivot().Position
                end)
                if not success then
                    local part = item:FindFirstChildWhichIsA("BasePart")
                    if part then
                        itemPos = part.Position
                    end
                end
                
                if itemPos then
                    local dist = (itemPos - playerPos).Magnitude
                    table.insert(foods, {
                        Item = item,
                        Name = item.Name,
                        Value = getFoodValue(item.Name),
                        Source = "World",
                        Distance = dist,
                    })
                end
            end
        end
    end
    
    -- Sort: closest first, then by value
    table.sort(foods, function(a, b)
        if a.Distance ~= b.Distance then
            return a.Distance < b.Distance
        end
        return a.Value > b.Value
    end)
    
    return foods
end

-- ============================================
-- FOOD SCANNING
-- ============================================
local function scanFoodInMap()
    local counts = {}
    local total = 0
    
    local worldItems = workspace:FindFirstChild("Items")
    if worldItems then
        for _, item in ipairs(worldItems:GetChildren()) do
            if isFood(item.Name) then
                counts[item.Name] = (counts[item.Name] or 0) + 1
                total = total + 1
            end
        end
    end
    
    local itemBag = LocalPlayer:FindFirstChild("ItemBag")
    if itemBag then
        for _, item in ipairs(itemBag:GetChildren()) do
            if isFood(item.Name) then
                counts[item.Name] = (counts[item.Name] or 0) + 1
                total = total + 1
            end
        end
    end
    
    return counts, total
end

local function formatScanResults()
    local counts, total = scanFoodInMap()
    
    local lines = {"🍖 Food Scan Results:"}
    
    -- Build list from FoodCatalog with counts
    local sorted = {}
    for name, _ in pairs(FoodCatalog) do
        local count = counts[name] or 0
        table.insert(sorted, {name = name, count = count})
    end
    
    -- Sort by count (highest first), then by name
    table.sort(sorted, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.name < b.name
    end)
    
    -- Format each item with status
    for _, item in ipairs(sorted) do
        local status = ""
        if item.count == 0 then
            status = " ❌ Not found"
        elseif item.count <= LOW_FOOD_THRESHOLD then
            status = " ⚠️ LOW!"
        else
            status = " ✅"
        end
        table.insert(lines, "  - " .. item.name .. ": " .. item.count .. status)
    end
    
    table.insert(lines, "Total: " .. total .. " food items")
    
    return table.concat(lines, "\n")
end

-- ============================================
-- FOOD CONSUMPTION
-- ============================================
local function dragItemToPlayer(item)
    if not item or not item.Parent then
        return false
    end
    
    local success = pcall(function()
        Remote.RequestStartDraggingItem(item)
    end)
    
    if success then
        task.wait(0.2)
        return true
    end
    return false
end

local function consumeFood(foodData)
    local item = foodData.Item
    if not item or not item.Parent then
        return false, 0
    end
    
    local hungerBefore = getHunger()
    
    if foodData.Source == "World" then
        local dragged = dragItemToPlayer(item)
        if not dragged then
            return false, 0
        end
    end
    
    local success = pcall(function()
        Remote.RequestConsumeItem(item)
    end)
    
    if success then
        task.wait(0.1)
        local hungerAfter = getHunger()
        local increase = math.floor(hungerAfter - hungerBefore)
        
        Stats.TotalEaten = Stats.TotalEaten + 1
        Stats.HungerGained = Stats.HungerGained + increase
        
        print("[OP] AutoEat: Ate " .. foodData.Name .. " (+" .. increase .. " hunger)")
        return true, increase
    end
    return false, 0
end

-- ============================================
-- PUBLIC API
-- ============================================
function AutoEat.Init(deps)
    Utils = deps.Utils
    Remote = deps.Remote
    WindUI = deps.WindUI
end

function AutoEat.Start()
    if State.Thread then
        print("[OP] AutoEat: Already running!")
        return
    end
    
    State.Enabled = true
    print("[OP] AutoEat: STARTED (Threshold: " .. Settings.HungerThreshold .. ")")
    
    State.Thread = task.spawn(function()
        local lastEatTime = 0
        
        while State.Enabled do
            local hunger = getHunger()
            
            if hunger < Settings.HungerThreshold then
                local now = os.clock()
                
                if now - lastEatTime >= Settings.EatCooldown then
                    local foods = collectAvailableFood()
                    
                    if #foods > 0 then
                        local ate = consumeFood(foods[1])
                        if ate then
                            lastEatTime = now
                        end
                    else
                        if now - lastEatTime >= 10 then
                            warn("[OP] AutoEat: No food available! Hunger: " .. math.floor(hunger))
                            lastEatTime = now
                        end
                    end
                end
            end
            
            task.wait(0.5)
        end
        
        State.Thread = nil
    end)
end

function AutoEat.Stop()
    State.Enabled = false
    if State.Thread then
        pcall(function() task.cancel(State.Thread) end)
        State.Thread = nil
    end
    print("[OP] AutoEat: STOPPED")
end

function AutoEat.UpdateSetting(key, value)
    if Settings[key] ~= nil then
        Settings[key] = value
    end
end

function AutoEat.Scan()
    local message = formatScanResults()
    print("[OP] " .. message:gsub("\n", " | "))
    
    -- WindUI:Notify must use colon syntax
    if WindUI then
        pcall(function()
            WindUI:Notify({
                Title = "Food Scanner",
                Content = message,
                Duration = 8,
            })
        end)
    end
    
    return message
end

function AutoEat.GetStats()
    return Stats
end

function AutoEat.ResetStats()
    Stats.TotalEaten = 0
    Stats.HungerGained = 0
    print("[OP] AutoEat: Stats reset!")
end

function AutoEat.GetFoodCatalog()
    return FoodCatalog
end

function AutoEat.IsEnabled()
    return State.Enabled
end

function AutoEat.Cleanup()
    AutoEat.Stop()
end

return AutoEat
