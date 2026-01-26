--[[
    Features/AutoScrap.lua
    Auto Scrap - Automatically scrap junk items
]]

local AutoScrap = {}

local Config = nil
local Utils = nil
local Remote = nil

-- State
local running = false

function AutoScrap.Init(config, utils, remote)
	Config = config
	Utils = utils
	Remote = remote
end

local function isJunk(name)
	local list = Config.Items and Config.Items.ScrapItems or {}
	return Utils.matchAny(name, list)
end

local function shouldScrap(name)
	local cfg = Config.AutoScrap

	-- Check never scrap list
	if Utils.matchAny(name, cfg.NeverScrap) then
		return false
	end

	-- Scrap junk if enabled
	if cfg.ScrapJunk and isJunk(name) then
		return true
	end

	return false
end

function AutoScrap.Start()
	if running then
		return
	end
	running = true

	Utils.log("AutoScrap: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.AutoScrap.Enabled then
				local temp = Utils.getTempStorage()
				local bench = Utils.getCraftingBench()

				if temp then
					local scrappedCount = 0
					local maxScrap = Config.AutoScrap.MaxScrapPerTick or 6

					for _, item in ipairs(temp:GetChildren()) do
						if scrappedCount >= maxScrap then
							break
						end
						if shouldScrap(item.Name) then
							Utils.log("AutoScrap: Scrapping " .. item.Name, "Info")
							Remote.RequestScrapItem(item, bench)
							scrappedCount = scrappedCount + 1
							task.wait(0.1)
						end
					end

					if scrappedCount > 0 then
						Utils.log("AutoScrap: Scrapped " .. scrappedCount .. " items", "Success")
					end
				end
			end
			task.wait(1)
		end
		Utils.log("AutoScrap: STOPPED", "Warning")
	end)
end

function AutoScrap.Stop()
	running = false
end

function AutoScrap.IsRunning()
	return running
end

return AutoScrap
