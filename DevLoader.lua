--[[
    WindUI Development Loader
    - Loads libraries
    - Loads 'app.lua' with Hot Reload capability
    - Integrates Reload button into Logger UI
]]

local LOCAL_SERVER = (getgenv and getgenv().OP_BASE_URL) or "http://192.168.1.5:8000/"

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

local function load_module(path)
	if LOCAL_BASE and readfile and isfile then
		local localPath = LOCAL_BASE .. path
		if isfile(localPath) then
			return loadstring(readfile(localPath))()
		end
	end
	local content = game:HttpGet(LOCAL_SERVER .. path)
	return loadstring(content)()
end

-- ==============================================================================
-- 0. GLOBAL CLEANUP (SAFETY FOR RE-EXECUTION)
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

	-- Check gethui() for modern executors
	if gethui then
		pcall(function()
			clean(gethui())
		end)
	end

	-- Cleanup Previous Logger if exists
	if getgenv().Logger then
		pcall(function()
			getgenv().Logger:Destroy()
		end)
		getgenv().Logger = nil
	end
end
GlobalCleanup()
-- ==============================================================================

-- 1. Setup Environment
-- 1. Setup Environment
getgenv().Logger = load_module("Libs/Logger.lua")
getgenv().Logger.SetRemote(LOCAL_SERVER .. "logs", true)
getgenv().Logger.Show()

-- State
local CurrentApp = nil

-- Forward declaration
local LoadApp

-- 2. Setup Reload Action in Logger
-- This puts the ⚡ button directly in the Debug Logs header
Logger.SetReloadAction(function()
	Logger.Add("Reloading...", "Warning")
	LoadApp()
end)

-- 3. Load App Function
function LoadApp()
	-- Cleanup previous
	if CurrentApp and CurrentApp.Destroy then
		pcall(function()
			CurrentApp:Destroy()
		end)
	end
	CurrentApp = nil

	Logger.Add("Loader: Fetching MainInterface...", "Info")

	local success, result = pcall(function()
		-- IMPORTANT: Load compiled/bundled WindUI FRESH every time.
		local windUiInstance = load_module("WindUI/dist/main.lua")

		local appModule = load_module("Src/UI/MainInterface.lua")
		CurrentApp = appModule.Init({
			WindUI = windUiInstance,
			Logger = Logger,
		})
	end)

	if not success then
		Logger.Add("Loader Error: " .. tostring(result), "Error")
		warn(result)
	end
end

-- Initial Load
LoadApp()

Logger.Add("Loader: Ready. Use '⚡' button in Logger to reload.", "Success")
