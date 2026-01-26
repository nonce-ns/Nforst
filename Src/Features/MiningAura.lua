--[[
    Features/MiningAura.lua
    Mining Aura - Auto mine/chop nodes in range with type filtering
]]

local MiningAura = {}

local Config = nil
local Utils = nil
local Remote = nil
local Scanner = nil

-- State
local running = false

-- Type categories
local TREE_PATTERNS = { "Tree", "FairyTree", "Dead Tree" }
local STONE_PATTERNS = { "Stone", "Basalt", "Rock" }
local BUSH_PATTERNS = { "Bush", "Brush", "Fairy Bush" }

function MiningAura.Init(config, utils, remote, scanner)
	Config = config
	Utils = utils
	Remote = remote
	Scanner = scanner
end

local function getCategory(name)
	if Utils.matchAny(name, TREE_PATTERNS) then
		return "Tree"
	end
	if Utils.matchAny(name, STONE_PATTERNS) then
		return "Stone"
	end
	if Utils.matchAny(name, BUSH_PATTERNS) then
		return "Bush"
	end
	return "Unknown"
end

local function shouldMine(name)
	local cfg = Config.MiningAura
	local category = getCategory(name)

	if category == "Tree" then
		if not cfg.TargetTrees then
			return false
		end
		-- Check specific types
		if #cfg.TreeTypes > 0 then
			return Utils.matchAny(name, cfg.TreeTypes)
		end
		return true
	end

	if category == "Stone" then
		if not cfg.TargetStones then
			return false
		end
		if #cfg.StoneTypes > 0 then
			return Utils.matchAny(name, cfg.StoneTypes)
		end
		return true
	end

	if category == "Bush" then
		if not cfg.TargetBushes then
			return false
		end
		if #cfg.BushTypes > 0 then
			return Utils.matchAny(name, cfg.BushTypes)
		end
		return true
	end

	return false
end

function MiningAura.Start()
	if running then
		return
	end
	running = true

	Utils.log("MiningAura: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.MiningAura.Enabled then
				local root = Utils.getRoot()
				local tool = Utils.equipTool()

				if root and tool then
					local foliage = Utils.getFoliage()
					if foliage then
						local hitCount = 0
						local maxHits = Config.MiningAura.MaxHitsPerTick

						for _, node in ipairs(foliage:GetChildren()) do
							if hitCount >= maxHits then
								break
							end

							if shouldMine(node.Name) then
								local pos = Utils.getModelPosition(node)
								if pos then
									local dist = (pos - root.Position).Magnitude
									if dist <= Config.MiningAura.Radius then
										Remote.ToolDamageObject(node, tool, Utils.hitId(), root.CFrame)
										hitCount = hitCount + 1
									end
								end
							end
						end

						if hitCount > 0 then
							Utils.log("MiningAura: Hit " .. hitCount .. " nodes", "Success")
						end
					end
				end
			end
			task.wait(0.15)
		end
		Utils.log("MiningAura: STOPPED", "Warning")
	end)
end

function MiningAura.Stop()
	running = false
end

function MiningAura.IsRunning()
	return running
end

-- Get available types (for UI dropdown)
function MiningAura.GetAvailableTypes()
	local foliage = Utils.getFoliage()
	if not foliage then
		return {}
	end

	local types = {}
	for _, node in ipairs(foliage:GetChildren()) do
		types[node.Name] = (types[node.Name] or 0) + 1
	end
	return types
end

return MiningAura
