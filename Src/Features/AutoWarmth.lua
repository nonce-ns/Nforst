--[[
    Features/AutoWarmth.lua
    Auto Warmth - Stay warm by fire, auto feed fire
]]

local AutoWarmth = {}

local Config = nil
local Utils = nil
local Remote = nil

-- State
local running = false

function AutoWarmth.Init(config, utils, remote)
	Config = config
	Utils = utils
	Remote = remote
end

local function teleportToFire()
	local fire = Utils.getMainFire()
	if not fire then
		return false
	end

	local firePos = Utils.getModelPosition(fire)
	if not firePos then
		return false
	end

	local root = Utils.getRoot()
	if not root then
		return false
	end

	-- Teleport slightly above fire
	root.CFrame = CFrame.new(firePos + Vector3.new(2, 3, 0))
	Utils.log("AutoWarmth: Teleported to fire!", "Success")
	return true
end

local function getFuelPriority()
	local cfg = Config.AutoWarmth
	local fuelItems = (Config.Items and Config.Items.FuelItems) or { "Sapling", "Log", "Coal" }
	local ordered = {}
	if cfg.FuelPriority == "Log" then
		ordered = { "Log", "Sapling", "Coal" }
	elseif cfg.FuelPriority == "Coal" then
		ordered = { "Coal", "Log", "Sapling" }
	elseif cfg.FuelPriority == "Any" then
		ordered = fuelItems
	else
		ordered = { "Sapling", "Log", "Coal" }
	end
	return ordered
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

local function findFuel()
	local priority = getFuelPriority()
	local temp = Utils.getTempStorage()
	for _, name in ipairs(priority) do
		local fuel = temp and temp:FindFirstChild(name)
		if fuel then
			return fuel
		end
	end

	local bag = Utils.getItemBag()
	for _, name in ipairs(priority) do
		local fuel = bag and bag:FindFirstChild(name)
		if fuel then
			return fuel
		end
	end

	local inv = Utils.getInventory()
	for _, name in ipairs(priority) do
		local fuel = inv and inv:FindFirstChild(name)
		if fuel then
			return fuel
		end
	end

	if Config.AutoWarmth.PullFuelFromWorld then
		local items = Utils.getItemsFolder()
		for _, name in ipairs(priority) do
			local fuel = items and items:FindFirstChild(name)
			if fuel then
				return ensureTempItem(fuel)
			end
		end
	end

	return nil
end

function AutoWarmth.Start()
	if running then
		return
	end
	running = true

	Utils.log("AutoWarmth: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.AutoWarmth.Enabled then
				local warmth = Utils.getStat("Warmth") or 100
				local temp = Utils.getStat("Temperature") or 100
				local cfg = Config.AutoWarmth

				local needWarmth = warmth <= cfg.WarmthThreshold or temp <= cfg.TempThreshold

				if needWarmth then
					Utils.logThrottled(
						"AutoWarmth.Need",
						"AutoWarmth: Need warmth! (W=" .. warmth .. ", T=" .. temp .. ")",
						"Warning",
						cfg.WarnCooldown
					)

					local fire = Utils.getMainFire()
					if fire then
						local firePos = Utils.getModelPosition(fire)
						local root = Utils.getRoot()
						local hum = Utils.getHumanoid()

						if firePos and root then
							local dist = (firePos - root.Position).Magnitude

							-- Teleport if too far
							if cfg.TeleportToFire and dist > cfg.TeleportDistance then
								teleportToFire()
							elseif cfg.MoveToFire and dist > cfg.TeleportDistance and hum then
								hum:MoveTo(firePos)
							end
						end

						-- Auto feed fire
						if cfg.AutoFeedFire then
							local fuel = findFuel()
							if fuel then
								Utils.log("AutoWarmth: Burning " .. fuel.Name, "Info")
								Remote.RequestBurnItem(fuel, fire)
							else
								Utils.logThrottled("AutoWarmth.NoFuel", "AutoWarmth: No fuel found", "Warning", cfg.WarnCooldown)
							end
						end
					else
						Utils.logThrottled("AutoWarmth.NoFire", "AutoWarmth: MainFire not found", "Warning", cfg.WarnCooldown)
					end
				end
			end
			task.wait(0.5)
		end
		Utils.log("AutoWarmth: STOPPED", "Warning")
	end)
end

function AutoWarmth.Stop()
	running = false
end

function AutoWarmth.IsRunning()
	return running
end

return AutoWarmth
