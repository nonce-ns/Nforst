--[[
    Features/KillAura.lua
    Kill Aura - Auto attack enemies in range with filtering
]]

local KillAura = {}

local Config = nil
local Utils = nil
local Remote = nil
local Scanner = nil

-- State
local running = false

-- Enemy category mapping
local WOLF_NAMES = { "Wolf", "Alpha Wolf", "Mossy Wolf" }
local BEAR_NAMES = { "Bear" }
local SCORPION_NAMES = { "Scorpion" }
local CULTIST_NAMES = { "Cultist", "Crossbow Cultist" }
local PASSIVE_NAMES = { "Kiwi", "Bunny" }

function KillAura.Init(config, utils, remote, scanner)
	Config = config
	Utils = utils
	Remote = remote
	Scanner = scanner
end

local function shouldAttack(name)
	local cfg = Config.KillAura

	-- Check ignore list
	for _, ignore in ipairs(cfg.IgnoreTypes) do
		if string.find(name, ignore) then
			return false
		end
	end

	-- Check categories
	if Utils.matchAny(name, WOLF_NAMES) then
		return cfg.TargetWolves
	end
	if Utils.matchAny(name, BEAR_NAMES) then
		return cfg.TargetBears
	end
	if Utils.matchAny(name, SCORPION_NAMES) then
		return cfg.TargetScorpions
	end
	if Utils.matchAny(name, CULTIST_NAMES) then
		return cfg.TargetCultists
	end
	if Utils.matchAny(name, PASSIVE_NAMES) then
		return cfg.TargetPassive
	end

	-- Default: attack unknown enemies
	return true
end

function KillAura.Start()
	if running then
		return
	end
	running = true

	Utils.log("KillAura: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.KillAura.Enabled then
				local root = Utils.getRoot()
				local tool = Utils.equipTool()

				if root and tool then
					local chars = Utils.getCharactersFolder()
					if chars then
						local hitCount = 0
						local maxHits = Config.KillAura.MaxHitsPerTick

						for _, char in ipairs(chars:GetChildren()) do
							if hitCount >= maxHits then
								break
							end

							local isPlayer = Utils.isPlayerModel(char)
							local canAttackPlayer = Config.KillAura.AttackPlayers or not isPlayer
							if canAttackPlayer and shouldAttack(char.Name) then
								local dist = Utils.distanceTo(char)
								if dist <= Config.KillAura.Radius and Utils.isAlive(char) then
									Remote.ToolDamageObject(char, tool, Utils.hitId(), root.CFrame)
									hitCount = hitCount + 1
								end
							end
						end

						if hitCount > 0 then
							Utils.log("KillAura: Hit " .. hitCount .. " enemies", "Success")
						end
					end
				end
			end
			task.wait(0.15)
		end
		Utils.log("KillAura: STOPPED", "Warning")
	end)
end

function KillAura.Stop()
	running = false
end

function KillAura.IsRunning()
	return running
end

return KillAura
