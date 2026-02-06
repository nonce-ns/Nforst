--[[
    Core/RemoteHandler.lua
    Handles all remote event firing with safety and caching
]]

local RemoteHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Cache
local RemotesFolder = nil
local RemoteCache = {}

-- Logger
local log = function(msg, level)
	print("[Remote][" .. (level or "Info") .. "] " .. msg)
end

function RemoteHandler.SetLogger(logFn)
	log = logFn
end

-- ============================================
-- GET REMOTES FOLDER
-- ============================================
function RemoteHandler.GetRemotesFolder()
	if RemotesFolder then
		return RemotesFolder
	end

	RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not RemotesFolder then
		RemotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
	end

	if RemotesFolder then
		log("RemoteEvents found: " .. #RemotesFolder:GetChildren() .. " remotes", "Success")
	else
		log("RemoteEvents NOT FOUND!", "Error")
	end

	return RemotesFolder
end

-- ============================================
-- GET SPECIFIC REMOTE (cached)
-- ============================================
function RemoteHandler.Get(name)
	if RemoteCache[name] then
		return RemoteCache[name]
	end

	local folder = RemoteHandler.GetRemotesFolder()
	if not folder then
		return nil
	end

	local remote = folder:FindFirstChild(name)
	if remote then
		RemoteCache[name] = remote
	end

	return remote
end

-- ============================================
-- SAFE FIRE (with error handling)
-- ============================================
function RemoteHandler.Fire(remoteName, ...)
	local args = { ... }
	local remote = RemoteHandler.Get(remoteName)
	if not remote then
		log("Remote not found: " .. remoteName, "Warning")
		return false
	end

	local ok, err = pcall(function()
		if remote:IsA("RemoteEvent") then
			remote:FireServer(unpack(args))
		elseif remote:IsA("RemoteFunction") then
			return remote:InvokeServer(unpack(args))
		end
	end)

	if not ok then
		log("Fire failed for " .. remoteName .. ": " .. tostring(err), "Error")
		return false
	end

	return true
end

-- INVOKE for RemoteFunctions (returns result)
function RemoteHandler.Invoke(remoteName, ...)
	local args = { ... }
	local remote = RemoteHandler.Get(remoteName)
	if not remote then
		log("Remote not found: " .. remoteName, "Warning")
		return nil
	end

	if not remote:IsA("RemoteFunction") then
		log("Invoke called on non-RemoteFunction: " .. remoteName, "Warning")
		return nil
	end

	local ok, result = pcall(function()
		return remote:InvokeServer(unpack(args))
	end)

	if not ok then
		log("Invoke failed for " .. remoteName .. ": " .. tostring(result), "Error")
		return nil
	end

	return result
end

-- ============================================
-- COMMON REMOTES (shortcuts)
-- ============================================
function RemoteHandler.DamagePlayer(amount)
	return RemoteHandler.Fire("DamagePlayer", amount)
end

function RemoteHandler.ToolDamageObject(target, tool, hitId, cframe)
	-- This is a RemoteFunction, not RemoteEvent!
	return RemoteHandler.Invoke("ToolDamageObject", target, tool, hitId, cframe)
end

function RemoteHandler.ProjectileDamageEnemy(target, projectileId, hitId, hitPart)
	-- This is a RemoteFunction, not RemoteEvent!
	return RemoteHandler.Invoke("ProjectileDamageEnemy", target, projectileId, hitId, hitPart)
end

-- EquipItemHandle - required before shooting
function RemoteHandler.EquipItemHandle(weapon)
	return RemoteHandler.Fire("EquipItemHandle", "FireAllClients", weapon)
end

-- RegisterProjectile must be called BEFORE ProjectileDamageEnemy
-- Returns: { Success = true/false }
function RemoteHandler.RegisterProjectile(weapon, projectileId)
	return RemoteHandler.Invoke("RegisterProjectile", weapon, projectileId)
end

-- Auto-reload firearm
function RemoteHandler.RequestReloadFirearm(weapon)
	return RemoteHandler.Invoke("RequestReloadFirearm", weapon)
end

-- ReplicateBullet - MANDATORY for ranged weapons
-- Must be called after RegisterProjectile, before damage call
-- bulletData format: { ProjectileGravity, HeadPos, Origin, Velocity, ProjectileName }
function RemoteHandler.ReplicateBullet(projectileId, bulletData)
	return RemoteHandler.Fire("ReplicateBullet", "FireAllClients", projectileId, bulletData)
end

-- ExplosiveProjectileDamageEnemy - for AOE weapons (Laser Canon, Raygun)
-- targets format: { {Model = targetModel, Distance = float}, ... }
function RemoteHandler.ExplosiveProjectileDamageEnemy(targets, projectileId, hitId, explosionPos)
	return RemoteHandler.Invoke("ExplosiveProjectileDamageEnemy", targets, projectileId, hitId, explosionPos)
end

function RemoteHandler.RequestConsumeItem(item, bag)
	if bag and item then
		if RemoteHandler.Fire("RequestConsumeItem", bag, item, true) then
			return true
		end
		if RemoteHandler.Fire("RequestConsumeItem", bag, item, false) then
			return true
		end
	end
	if item then
		if RemoteHandler.Fire("RequestConsumeItem", item) then
			return true
		end
	end
	if bag and item then
		return RemoteHandler.Fire("RequestConsumeItem", bag, item)
	end
	return false
end

function RemoteHandler.RequestPlantItem(sapling, position)
	return RemoteHandler.Fire("RequestPlantItem", sapling, position)
end

function RemoteHandler.RequestBurnItem(item, fire)
	if fire and item then
		if RemoteHandler.Fire("RequestBurnItem", fire, item) then
			return true
		end
	end
	if item then
		return RemoteHandler.Fire("RequestBurnItem", item)
	end
	return false
end

function RemoteHandler.RequestStartDraggingItem(item)
	return RemoteHandler.Fire("RequestStartDraggingItem", item)
end

function RemoteHandler.StopDraggingItem(item)
	return RemoteHandler.Fire("StopDraggingItem", item)
end

function RemoteHandler.RequestBagStoreItem(bag, item)
	return RemoteHandler.Fire("RequestBagStoreItem", bag, item)
end

function RemoteHandler.RequestScrapItem(item, bench)
	if bench and item then
		if RemoteHandler.Fire("RequestScrapItem", bench, item) then
			return true
		end
	end
	if item then
		return RemoteHandler.Fire("RequestScrapItem", item)
	end
	return false
end

function RemoteHandler.RequestCookItem(item, fire)
	if fire and item then
		if RemoteHandler.Fire("RequestCookItem", fire, item) then
			return true
		end
	end
	if item then
		return RemoteHandler.Fire("RequestCookItem", item)
	end
	return false
end

function RemoteHandler.RequestSelectRecipe(workshop, recipe)
	return RemoteHandler.Fire("RequestSelectRecipe", workshop, recipe)
end

function RemoteHandler.RequestOpenItemChest(chest)
	return RemoteHandler.Fire("RequestOpenItemChest", chest)
end

function RemoteHandler.FadeOutFogBlock(mode, part)
    return RemoteHandler.Fire("FadeOutFogBlock", mode, part)
end

-- ============================================
-- FISHING REMOTES
-- ============================================
function RemoteHandler.StartCatchTimer(rod, waterPart, position)
    return RemoteHandler.Invoke("StartCatchTimer", rod, waterPart, position)
end

function RemoteHandler.ConfirmCatchItem()
    return RemoteHandler.Fire("ConfirmCatchItem")
end

-- Visual animation remotes
function RemoteHandler.PlayerCastRod(castData)
    return RemoteHandler.Fire("PlayerCastRod", castData)
end

function RemoteHandler.PlayerRodBobbleInWater(position)
    return RemoteHandler.Fire("PlayerRodBobbleInWater", position)
end

function RemoteHandler.EndCatching()
    return RemoteHandler.Fire("EndCatching")
end

-- ============================================
-- LIST ALL REMOTES (for debugging)
-- ============================================
function RemoteHandler.ListAll()
	local folder = RemoteHandler.GetRemotesFolder()
	if not folder then
		return {}
	end

	local list = {}
	for _, remote in ipairs(folder:GetChildren()) do
		table.insert(list, {
			Name = remote.Name,
			Class = remote.ClassName,
		})
	end
	return list
end

return RemoteHandler
