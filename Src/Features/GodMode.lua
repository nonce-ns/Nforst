--[[
    Features/GodMode.lua
    God Mode - Infinite health via DamagePlayer remote
]]

local GodMode = {}

local Config = nil
local Utils = nil
local Remote = nil

-- State
local running = false
local fireCount = 0

function GodMode.Init(config, utils, remote)
	Config = config
	Utils = utils
	Remote = remote
end

function GodMode.Start()
	if running then
		return
	end
	running = true
	fireCount = 0

	Utils.log("GodMode: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.GodMode.Enabled then
				Remote.DamagePlayer(-math.huge)
				fireCount = fireCount + 1

				-- Log periodically
				if fireCount % Config.GodMode.LogFrequency == 0 then
					Utils.log("GodMode: Active (" .. fireCount .. " fires)", "Info")
				end
			end
			task.wait(Config.GodMode.FireRate)
		end
		Utils.log("GodMode: STOPPED", "Warning")
	end)
end

function GodMode.Stop()
	running = false
end

function GodMode.IsRunning()
	return running
end

function GodMode.GetFireCount()
	return fireCount
end

return GodMode
