--[[
    Features/AutoEat.lua
    Auto Eat - Automatically consume food when hungry
]]

local AutoEat = {}

local Config = nil
local Utils = nil
local Remote = nil

-- State
local running = false
local lastEat = 0

function AutoEat.Init(config, utils, remote)
	Config = config
	Utils = utils
	Remote = remote
end

local function getFoodValue(name)
	local map = Config.Items and Config.Items.FoodValues or {}
	return map[name] or 20
end

local SOURCE_PRIORITY = {
	Bag = 4,
	Inventory = 3,
	Temp = 2,
	World = 1,
}

local function selectFood(foods, priority)
	local pick = nil
	local pickValue = priority == "WorstFirst" and math.huge or -math.huge
	local pickSource = -1

	for _, entry in ipairs(foods) do
		local value = getFoodValue(entry.Name)
		local sourceScore = SOURCE_PRIORITY[entry.Source] or 0
		if priority == "WorstFirst" then
			if value < pickValue or (value == pickValue and sourceScore > pickSource) then
				pick = entry
				pickValue = value
				pickSource = sourceScore
			end
		else
			if value > pickValue or (value == pickValue and sourceScore > pickSource) then
				pick = entry
				pickValue = value
				pickSource = sourceScore
			end
		end
	end

	return pick
end

local function isFood(name)
	local map = Config.Items and Config.Items.FoodValues or {}
	if map[name] ~= nil then
		return true
	end
	local keywords = Config.Items and Config.Items.FoodKeywords or {}
	return Utils.matchAny(name, keywords)
end

local function shouldEat(name)
	local cfg = Config.AutoEat

	-- Check avoid list
	if Utils.matchAny(name, cfg.AvoidFoods) then
		return false
	end

	-- Check selected foods (if specified)
	if #cfg.SelectedFoods > 0 then
		return Utils.matchAny(name, cfg.SelectedFoods)
	end

	return isFood(name)
end

local function collectFoods()
	local foods = {}
	local function addFrom(container, source)
		if not container then
			return
		end
		for _, item in ipairs(container:GetChildren()) do
			if shouldEat(item.Name) then
				table.insert(foods, {
					Name = item.Name,
					Instance = item,
					Source = source,
				})
			end
		end
	end

	addFrom(Utils.getItemBag(), "Bag")
	addFrom(Utils.getInventory(), "Inventory")
	addFrom(Utils.getTempStorage(), "Temp")
	if Config.AutoEat.AllowWorldFood then
		addFrom(Utils.getItemsFolder(), "World")
	end

	return foods
end

local function ensureTempItem(item)
	local temp = Utils.getTempStorage()
	if temp then
		local existing = temp:FindFirstChild(item.Name)
		if existing then
			return existing
		end
	end
	Remote.RequestStartDraggingItem(item)
	task.wait(0.1)
	local updated = Utils.getTempStorage()
	return updated and updated:FindFirstChild(item.Name)
end

function AutoEat.Start()
	if running then
		return
	end
	running = true

	Utils.log("AutoEat: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.AutoEat.Enabled then
				local hunger = Utils.getStat("Hunger")

				if hunger and hunger <= Config.AutoEat.HungerThreshold then
					Utils.logThrottled(
						"AutoEat.Hungry",
						"AutoEat: Hungry! (" .. math.floor(hunger) .. "/" .. Config.AutoEat.HungerThreshold .. ")",
						"Warning",
						Config.AutoEat.WarnCooldown
					)

					local foods = collectFoods()
					if #foods > 0 then
						local foodToEat
						if Config.AutoEat.FoodPriority == "Any" then
							foodToEat = foods[1]
						else
							foodToEat = selectFood(foods, Config.AutoEat.FoodPriority)
						end

						if foodToEat then
							local now = os.clock()
							if now - lastEat >= (Config.AutoEat.EatCooldown or 1.0) then
								local item = foodToEat.Instance
								if foodToEat.Source == "World" then
									item = ensureTempItem(item)
								end
								if item then
									local bag = Utils.getBagTool()
									Utils.log("AutoEat: Eating " .. foodToEat.Name .. " (" .. foodToEat.Source .. ")", "Success")
									Remote.RequestConsumeItem(item, bag)
									lastEat = now
								else
									Utils.logThrottled("AutoEat.NoTemp", "AutoEat: Failed to move food to TempStorage", "Warning", 5)
								end
							end
						end
					else
						Utils.logThrottled("AutoEat.NoFood", "AutoEat: No food found!", "Warning", Config.AutoEat.WarnCooldown)
					end
				end
			end
			task.wait(0.5)
		end
		Utils.log("AutoEat: STOPPED", "Warning")
	end)
end

function AutoEat.Stop()
	running = false
end

function AutoEat.IsRunning()
	return running
end

return AutoEat
