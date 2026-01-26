--[[
    Features/AutoLoot.lua
    Auto Loot - Automatically collect items with category filtering
]]

local AutoLoot = {}

local Config = nil
local Utils = nil
local Remote = nil

-- State
local running = false

function AutoLoot.Init(config, utils, remote)
	Config = config
	Utils = utils
	Remote = remote
end

local function getCategory(name)
	local categories = Config.Items and Config.Items.LootCategories or {}
	if Utils.matchAny(name, categories.Valuables or {}) then
		return "Valuable"
	end
	if Utils.matchAny(name, categories.Containers or {}) then
		return "Container"
	end
	if Utils.matchAny(name, categories.Resources or {}) then
		return "Resource"
	end
	if Utils.matchAny(name, categories.Scrap or {}) then
		return "Scrap"
	end
	return "Other"
end

local function shouldLoot(name)
	local cfg = Config.AutoLoot

	-- Check ignore list
	if Utils.matchAny(name, cfg.IgnoreItems) then
		return false
	end

	-- Check priority items (always loot)
	if Utils.matchAny(name, cfg.PriorityItems) then
		return true
	end

	-- Check category
	local category = getCategory(name)

	if category == "Valuable" then
		return cfg.LootValuables
	end
	if category == "Resource" then
		return cfg.LootResources
	end
	if category == "Scrap" then
		return cfg.LootScrap
	end
	if category == "Container" then
		return cfg.LootContainers
	end

	return true -- Default to loot
end

function AutoLoot.Start()
	if running then
		return
	end
	running = true

	Utils.log("AutoLoot: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.AutoLoot.Enabled then
				local root = Utils.getRoot()
				local items = Utils.getItemsFolder()

				if root and items then
					local lootCount = 0
					local bag = Utils.getBagTool()
					local maxLoot = Config.AutoLoot.MaxLootPerTick or 6

					for _, item in ipairs(items:GetChildren()) do
						if lootCount >= maxLoot then
							break
						end
						local pos = Utils.getModelPosition(item)
						if pos then
							local dist = (pos - root.Position).Magnitude

							if dist <= Config.AutoLoot.Radius then
								if shouldLoot(item.Name) then
									local category = getCategory(item.Name)
									if category == "Container" and Config.AutoLoot.OpenContainers then
										Remote.RequestOpenItemChest(item)
										lootCount = lootCount + 1
									else
										-- Pick up item
										Remote.RequestStartDraggingItem(item)
										task.wait(0.05)

										-- Store in bag
										local temp = Utils.getTempStorage()
										if temp and bag then
											local tempItem = temp:FindFirstChild(item.Name)
											if tempItem then
												Remote.RequestBagStoreItem(bag, tempItem)
												Remote.StopDraggingItem(tempItem)
												lootCount = lootCount + 1
											end
										elseif temp then
											local tempItem = temp:FindFirstChild(item.Name)
											if tempItem then
												Remote.StopDraggingItem(tempItem)
												lootCount = lootCount + 1
											end
										end
									end
								end
							end
						end
					end

					if lootCount > 0 then
						Utils.log("AutoLoot: Collected " .. lootCount .. " items", "Success")
					end
				end
			end
			task.wait(0.3)
		end
		Utils.log("AutoLoot: STOPPED", "Warning")
	end)
end

function AutoLoot.Stop()
	running = false
end

function AutoLoot.IsRunning()
	return running
end

return AutoLoot
