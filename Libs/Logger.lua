--[[
    Mobile Debug Logger v2.0 for WindUI
    Shows on-screen log panel with filtering
]]

local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Logger State
local Logger = {
	Enabled = true,
	RemoteEnabled = false,
	RemoteURL = nil,
	MaxLogs = 1000,
	Logs = {},
	UI = nil,
	Visible = false,
	SessionStartTime = os.time(),
	SessionId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999)),
	Filters = {
		Info = true,
		Warning = true,
		Error = true,
	},
	ReloadCallback = nil, -- Added for reload support
}

-- Colors for log levels
local Colors = {
	Info = Color3.fromRGB(200, 200, 200),
	Warning = Color3.fromRGB(255, 200, 80),
	Error = Color3.fromRGB(255, 100, 100),
}

-- Create UI
local function CreateUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WindUI_Logger"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999999
	gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

	-- Main Frame
	local frame = Instance.new("Frame")
	frame.Name = "LogPanel"
	frame.Size = UDim2.new(0.45, 0, 0.35, 0)
	frame.Position = UDim2.new(0.02, 0, 0.6, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 70)
	stroke.Thickness = 1
	stroke.Parent = frame

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 32)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	header.BorderSizePixel = 0
	header.Parent = frame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.5, 0, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "📋 Debug Logs"
	title.TextColor3 = Color3.fromRGB(220, 220, 220)
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- Filter Buttons Container
	local filterFrame = Instance.new("Frame")
	-- Default size (will be adjusted if reload button exists)
	filterFrame.Size = UDim2.new(0.5, -60, 1, -6)
	filterFrame.Position = UDim2.new(0.5, 0, 0, 3)
	filterFrame.BackgroundTransparency = 1
	filterFrame.Parent = header

	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	filterLayout.Padding = UDim.new(0, 4)
	filterLayout.Parent = filterFrame

	local function CreateFilterBtn(name, color)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 50, 1, 0)
		btn.BackgroundColor3 = color
		btn.BackgroundTransparency = 0.7
		btn.Text = name
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextSize = 11
		btn.Font = Enum.Font.GothamBold
		btn.Parent = filterFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 4)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			Logger.Filters[name] = not Logger.Filters[name]
			btn.BackgroundTransparency = Logger.Filters[name] and 0.7 or 0.9
			Logger.RefreshDisplay()
		end)

		return btn
	end

	CreateFilterBtn("Error", Colors.Error)
	CreateFilterBtn("Warning", Colors.Warning)
	CreateFilterBtn("Info", Colors.Info)

	-- Reload Button (Custom - Added)
	if Logger.ReloadCallback then
		-- Adjust filter frame to make room
		filterFrame.Size = UDim2.new(0.5, -90, 1, -6)

		local reloadBtn = Instance.new("TextButton")
		reloadBtn.Size = UDim2.new(0, 26, 0, 26)
		reloadBtn.Position = UDim2.new(1, -60, 0, 3) -- Left of close button
		reloadBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 255)
		reloadBtn.BackgroundTransparency = 0.5
		reloadBtn.Text = "⚡"
		reloadBtn.TextColor3 = Color3.new(1, 1, 1)
		reloadBtn.TextSize = 14
		reloadBtn.Font = Enum.Font.GothamBold
		reloadBtn.Parent = header

		local rCorner = Instance.new("UICorner")
		rCorner.CornerRadius = UDim.new(0, 4)
		rCorner.Parent = reloadBtn

		reloadBtn.MouseButton1Click:Connect(function()
			if Logger.ReloadCallback then
				Logger.ReloadCallback()
			end
		end)
	end

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.Position = UDim2.new(1, -30, 0, 3)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	closeBtn.BackgroundTransparency = 0.5
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 4)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		Logger.Hide()
	end)

	-- Scroll Frame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "LogScroll"
	scroll.Size = UDim2.new(1, -16, 1, -40)
	scroll.Position = UDim2.new(0, 8, 0, 36)
	scroll.BackgroundTransparency = 1
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageTransparency = 0.5
	scroll.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	-- Make draggable
	local dragging, dragStart, startPos
	header.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)

	header.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local delta = input.Position - dragStart
			frame.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	Logger.UI = {
		Gui = gui,
		Frame = frame,
		Scroll = scroll,
	}
end

-- Add log entry to display
local function AddLogEntry(log)
	if not Logger.UI or not Logger.UI.Scroll then
		return
	end
	if not Logger.Filters[log.Level] then
		return
	end

	local entry = Instance.new("TextLabel")
	entry.Size = UDim2.new(1, 0, 0, 0)
	entry.AutomaticSize = Enum.AutomaticSize.Y
	entry.BackgroundTransparency = 1
	entry.Text = string.format("[%s] %s", log.Time, log.Message)
	entry.TextColor3 = Colors[log.Level] or Colors.Info
	entry.TextSize = 12
	entry.Font = Enum.Font.Code
	entry.TextWrapped = true
	entry.TextXAlignment = Enum.TextXAlignment.Left
	entry.LayoutOrder = log.Order
	entry.Parent = Logger.UI.Scroll
end

-- Refresh display based on filters
function Logger.RefreshDisplay()
	if not Logger.UI or not Logger.UI.Scroll then
		return
	end

	-- Clear existing
	for _, child in pairs(Logger.UI.Scroll:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	-- Re-add filtered logs
	for _, log in ipairs(Logger.Logs) do
		AddLogEntry(log)
	end
end

-- Add log
function Logger.Add(message, level)
	level = level or "Info"

	local log = {
		Message = tostring(message),
		Level = level,
		Time = os.date("%H:%M:%S"),
		Timestamp = os.time(),
		Order = #Logger.Logs + 1,
	}

	table.insert(Logger.Logs, log)

	-- Purge old logs
	while #Logger.Logs > Logger.MaxLogs do
		table.remove(Logger.Logs, 1)
	end

	-- Add to display
	if Logger.Visible then
		AddLogEntry(log)
	end

	-- Send to remote server
	if Logger.RemoteEnabled and Logger.RemoteURL then
		task.spawn(function()
			pcall(function()
				local payload = HttpService:JSONEncode({
					message = log.Message,
					level = log.Level,
					time = log.Time,
					timestamp = log.Timestamp,
					userId = LocalPlayer and LocalPlayer.UserId or 0,
					username = LocalPlayer and LocalPlayer.Name or "Unknown",
				})

				local request = http_request or (syn and syn.request) or request
				if request then
					request({
						Url = Logger.RemoteURL,
						Method = "POST",
						Headers = { ["Content-Type"] = "application/json" },
						Body = payload,
					})
				end
			end)
		end)
	end
end

-- Show/Hide
function Logger.Show()
	if not Logger.UI then
		CreateUI()
	end
	Logger.UI.Frame.Visible = true
	Logger.Visible = true
	Logger.RefreshDisplay()
end

function Logger.Hide()
	if Logger.UI then
		Logger.UI.Frame.Visible = false
	end
	Logger.Visible = false
end

function Logger.Toggle()
	if Logger.Visible then
		Logger.Hide()
	else
		Logger.Show()
	end
end

-- Clear logs
function Logger.Clear()
	Logger.Logs = {}
	if Logger.UI and Logger.UI.Scroll then
		for _, child in pairs(Logger.UI.Scroll:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end
end

-- Destroy Logger (Cleanup)
function Logger.Destroy()
	if Logger.UI and Logger.UI.Gui then
		Logger.UI.Gui:Destroy()
	end
	Logger.UI = nil
	Logger.Logs = {}
	Logger.Enabled = false
end

-- Copy logs to clipboard
function Logger.Copy()
	local buffer = {}
	for _, log in ipairs(Logger.Logs) do
		table.insert(buffer, string.format("[%s][%s] %s", log.Time, log.Level, log.Message))
	end

	local text = table.concat(buffer, "\n")
	pcall(function()
		setclipboard(text)
	end)

	return #Logger.Logs
end

-- Set remote server
function Logger.SetRemote(url, enabled)
	Logger.RemoteURL = url
	Logger.RemoteEnabled = enabled
end

-- Set Reload Callback (NEW)
function Logger.SetReloadAction(callback)
	Logger.ReloadCallback = callback
	-- Re-create UI if it exists to show button
	if Logger.UI then
		Logger.UI.Gui:Destroy()
		Logger.UI = nil
		if Logger.Visible then
			Logger.Show()
		end
	end
end

-- Upload entire session logs
function Logger.UploadSession()
	if not Logger.RemoteURL then
		return false, "Remote URL not set"
	end

	if #Logger.Logs == 0 then
		return false, "No logs to upload"
	end

	-- Calculate session stats
	local now = os.time()
	local duration = now - Logger.SessionStartTime
	local infoCount, warnCount, errorCount = 0, 0, 0

	for _, log in ipairs(Logger.Logs) do
		if log.Level == "Info" then
			infoCount = infoCount + 1
		elseif log.Level == "Warning" then
			warnCount = warnCount + 1
		elseif log.Level == "Error" then
			errorCount = errorCount + 1
		end
	end

	-- Build session payload
	-- Generate unique upload ID for this specific upload (different each time)
	local uploadId = os.date("%Y%m%d_%H%M%S") .. "_" .. tostring(math.random(1000, 9999))

	local sessionData = {
		type = "session_upload",
		sessionId = uploadId, -- Use unique uploadId instead of fixed SessionId
		uploadTime = os.date("%Y-%m-%d %H:%M:%S"),
		userId = LocalPlayer and LocalPlayer.UserId or 0,
		username = LocalPlayer and LocalPlayer.Name or "Unknown",
		startTime = os.date("%Y-%m-%d %H:%M:%S", Logger.SessionStartTime),
		endTime = os.date("%Y-%m-%d %H:%M:%S", now),
		durationSeconds = duration,
		durationFormatted = string.format(
			"%02d:%02d:%02d",
			math.floor(duration / 3600),
			math.floor((duration % 3600) / 60),
			duration % 60
		),
		totalLogs = #Logger.Logs,
		infoCount = infoCount,
		warningCount = warnCount,
		errorCount = errorCount,
		logs = {},
	}

	-- Add all logs
	for _, log in ipairs(Logger.Logs) do
		table.insert(sessionData.logs, {
			message = log.Message,
			level = log.Level,
			time = log.Time,
			timestamp = log.Timestamp,
		})
	end

	-- Send to server
	local success = false
	local result = nil

	task.spawn(function()
		pcall(function()
			local payload = HttpService:JSONEncode(sessionData)

			local request = http_request or (syn and syn.request) or request
			if request then
				local response = request({
					Url = Logger.RemoteURL,
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = payload,
				})
				success = response and response.StatusCode == 200
			end
		end)
	end)

	return true, sessionData.totalLogs, sessionData.durationFormatted
end

-- Get session info
function Logger.GetSessionInfo()
	local now = os.time()
	local duration = now - Logger.SessionStartTime

	return {
		sessionId = Logger.SessionId,
		startTime = os.date("%H:%M:%S", Logger.SessionStartTime),
		duration = string.format(
			"%02d:%02d:%02d",
			math.floor(duration / 3600),
			math.floor((duration % 3600) / 60),
			duration % 60
		),
		totalLogs = #Logger.Logs,
	}
end

-- Auto-capture game logs
local function GetLogLevel(msgType)
	if msgType == Enum.MessageType.MessageWarning then
		return "Warning"
	elseif msgType == Enum.MessageType.MessageError then
		return "Error"
	else
		return "Info"
	end
end

LogService.MessageOut:Connect(function(message, msgType)
	if Logger.Enabled then
		Logger.Add(message, GetLogLevel(msgType))
	end
end)

-- Export to global
_G.WindUILogger = Logger

return Logger
