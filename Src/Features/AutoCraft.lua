--[[
    Features/AutoCraft.lua
    Auto Craft - Automatically craft items at workshop
]]

local AutoCraft = {}

local Config = nil
local Utils = nil
local Remote = nil

-- State
local running = false

function AutoCraft.Init(config, utils, remote)
	Config = config
	Utils = utils
	Remote = remote
end

function AutoCraft.Start()
	if running then
		return
	end
	running = true

	Utils.log("AutoCraft: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.AutoCraft.Enabled then
				local cfg = Config.AutoCraft

				-- Try workshop
				if cfg.CraftAtWorkshop then
					local workshop = Utils.getToolWorkshop()
					if workshop then
						for _, recipe in ipairs(cfg.RecipePriority) do
							Utils.log("AutoCraft: Selecting recipe " .. recipe, "Info")
							Remote.RequestSelectRecipe(workshop, recipe)
							task.wait(0.1)
						end
					else
						Utils.logThrottled("AutoCraft.NoWorkshop", "AutoCraft: ToolWorkshop not found", "Warning", 10)
					end
				end

				-- Try campfire bench
				if cfg.CraftAtCampfire then
					local bench = Utils.getCraftingBench()
					if bench then
						for _, recipe in ipairs(cfg.RecipePriority) do
							Remote.RequestSelectRecipe(bench, recipe)
							task.wait(0.1)
						end
					end
				end
			end
			task.wait(2)
		end
		Utils.log("AutoCraft: STOPPED", "Warning")
	end)
end

function AutoCraft.Stop()
	running = false
end

function AutoCraft.IsRunning()
	return running
end

return AutoCraft
