--[[
    Features/AutoPlant.lua
    Auto Plant - Exploit-based pattern planting system
    
    Uses 1 Sapling to plant many trees in patterns (Circle, Square, Spiral)
]]

local AutoPlant = {}

local Config = nil
local Utils = nil
local Remote = nil

-- State
local running = false
local planting = false

function AutoPlant.Init(config, utils, remote)
	Config = config
	Utils = utils
	Remote = remote
end

-- ============================================
-- PATTERN GENERATORS
-- ============================================
local function getPositions(center)
	local cfg = Config.AutoPlant
	local pattern = cfg.Pattern

	if pattern == "Circle" then
		return Utils.getCirclePositions(center, cfg.Radius, cfg.InnerRadius, cfg.Spacing)
	elseif pattern == "Square" then
		return Utils.getGridPositions(center, cfg.Rows, cfg.Columns, cfg.Spacing)
	elseif pattern == "Spiral" then
		return Utils.getSpiralPositions(center, cfg.Radius, cfg.Spacing)
	else
		-- Default to circle
		return Utils.getCirclePositions(center, cfg.Radius, cfg.InnerRadius, cfg.Spacing)
	end
end

-- ============================================
-- EXPLOIT PLANT (one-shot)
-- ============================================
function AutoPlant.PlantNow()
	if planting then
		Utils.log("AutoPlant: Already planting!", "Warning")
		return
	end

	planting = true

	local cfg = Config.AutoPlant

	-- Get center position
	local center
	if cfg.CenterOnPlayer then
		local root = Utils.getRoot()
		center = root and root.Position or Vector3.new(0, 0, 0)
	else
		local fire = Utils.getMainFire()
		center = fire and Utils.getModelPosition(fire) or Vector3.new(0, 0, 0)
	end

	-- Find a sapling in world (we only need 1 for exploit)
	local items = Utils.getItemsFolder()
	local sapling = items and items:FindFirstChild("Sapling")

	if not sapling then
		Utils.logThrottled("AutoPlant.NoSapling", "AutoPlant: No sapling found in world!", "Error", 10)
		planting = false
		return
	end

	-- Get positions based on pattern
	local positions = getPositions(center)
	local maxPlants = math.min(#positions, cfg.PlantCount)

	Utils.log("AutoPlant: Planting " .. maxPlants .. " trees (" .. cfg.Pattern .. ")", "Info")

	-- Plant at each position
	local planted = 0
	for i = 1, maxPlants do
		local pos = positions[i]
		Remote.RequestPlantItem(sapling, pos)
		planted = planted + 1
		task.wait(cfg.PlantDelay)
	end

	Utils.log("AutoPlant: Planted " .. planted .. " trees!", "Success")
	planting = false
end

-- ============================================
-- AUTO LOOP (continuous planting)
-- ============================================
function AutoPlant.Start()
	if running then
		return
	end
	running = true

	Utils.log("AutoPlant: STARTED", "Success")

	task.spawn(function()
		while running do
			if Config.AutoPlant.Enabled and not planting then
				AutoPlant.PlantNow()
				task.wait(2) -- Wait before next batch
			end
			task.wait(0.5)
		end
		Utils.log("AutoPlant: STOPPED", "Warning")
	end)
end

function AutoPlant.Stop()
	running = false
end

function AutoPlant.IsRunning()
	return running
end

function AutoPlant.IsPlanting()
	return planting
end

-- ============================================
-- PREVIEW (get positions without planting)
-- ============================================
function AutoPlant.GetPreviewPositions()
	local cfg = Config.AutoPlant
	local center

	if cfg.CenterOnPlayer then
		local root = Utils.getRoot()
		center = root and root.Position or Vector3.new(0, 0, 0)
	else
		local fire = Utils.getMainFire()
		center = fire and Utils.getModelPosition(fire) or Vector3.new(0, 0, 0)
	end

	return getPositions(center)
end

return AutoPlant
