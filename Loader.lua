--[[
    Loader.lua
    Production loader for 99 Nights OP Script
    
    This is the entry point for running the script from executor
]]

local LOCAL_SERVER = (getgenv and getgenv().OP_BASE_URL) or "http://192.168.1.5:8000/"
if string.sub(LOCAL_SERVER, -1) ~= "/" then
	LOCAL_SERVER = LOCAL_SERVER .. "/"
end

local function normalizeBasePath(base)
	if not base or base == "" then
		return nil
	end
	local normalized = base:gsub("\\", "/")
	if string.sub(normalized, -1) ~= "/" then
		normalized = normalized .. "/"
	end
	return normalized
end

local LOCAL_BASE = normalizeBasePath(getgenv and getgenv().OP_BASE_PATH)

local function httpGet(url)
	return game:HttpGet(url)
end

local function loadModule(path)
	if LOCAL_BASE and readfile and isfile then
		local localPath = LOCAL_BASE .. path
		if isfile(localPath) then
			return loadstring(readfile(localPath))()
		end
	end
	local content = httpGet(LOCAL_SERVER .. path)
	return loadstring(content)()
end

-- ==============================================================================
-- GLOBAL CLEANUP
-- ==============================================================================
local function GlobalCleanup()
	local CoreGui = game:GetService("CoreGui")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")

	local targetNames = { "WindUI", "WindUI/Notifications", "WindUI/Dropdowns", "WindUI/Tooltips", "WindUI_Logger" }

	local function clean(parent)
		if not parent then
			return
		end
		for _, name in ipairs(targetNames) do
			local gui = parent:FindFirstChild(name)
			if gui then
				gui:Destroy()
			end
		end
	end

	pcall(function()
		clean(CoreGui)
	end)
	pcall(function()
		clean(PlayerGui)
	end)
	if gethui then
		pcall(function()
			clean(gethui())
		end)
	end

	if getgenv().Logger then
		pcall(function()
			getgenv().Logger:Destroy()
		end)
		getgenv().Logger = nil
	end
end

GlobalCleanup()

-- ==============================================================================
-- LOAD LIBRARIES
-- ==============================================================================
print("[Loader] Loading WindUI...")
local WindUI = loadModule("Libs/WindUI/dist/main.lua")

print("[Loader] Loading Logger...")
getgenv().Logger = loadModule("Libs/Logger.lua")
getgenv().Logger.SetRemote(LOCAL_SERVER .. "logs", true)
getgenv().Logger.Show()

-- ==============================================================================
-- LOAD APP
-- ==============================================================================
print("[Loader] Loading MainInterface...")
local App = loadModule("Src/UI/MainInterface.lua")

App.Init({
	WindUI = WindUI,
	Logger = getgenv().Logger,
})

print("[Loader] Ready!")
getgenv().Logger.Add("[Loader] 99 Nights OP Script loaded!", "Success")
