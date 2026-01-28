--[[
    UI/Tabs/HomeTab.lua
    Home/Dashboard tab for the interface
]]

local HomeTab = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Helper to get executor name safely
local function getExecutor()
    return (identifyexecutor and identifyexecutor()) or "Unknown Executor"
end

function HomeTab.Create(Window, CONFIG, WindUI)
    local Tab = Window:Tab({
        Title = "Home",
        Icon = "solar:home-2-bold",
    })

    -- ========================================
    -- HEADER / WELCOME
    -- ========================================
    local WelcomeSection = Tab:Section({
        Title = "Welcome back, " .. LocalPlayer.DisplayName,
        TextSize = 22,
        FontWeight = Enum.FontWeight.Bold,
    })

    WelcomeSection:Paragraph({
        Title = "Ready to survive the 99 Nights?",
        Desc = "Your dashboard for all automation tools.",
        Image = "solar:stars-bold-duotone",
        ImageColor = CONFIG.COLORS.Yellow,
    })

    Tab:Space({ Size = 10 })

    -- ========================================
    -- PLAYER & SESSION INFO (Grid Layout)
    -- ========================================
    -- Since WindUI doesn't strictly have a "Grid", we use Sections/Paragraphs.
    
    local InfoSection = Tab:Section({
        Title = "Session Information",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })

    -- User Stats
    InfoSection:Paragraph({
        Title = "Identity",
        Desc = string.format("User: @%s\nID: %d\nAccount Age: %d days", 
            LocalPlayer.Name, 
            LocalPlayer.UserId, 
            LocalPlayer.AccountAge),
        Image = "solar:user-id-bold",
        ImageColor = CONFIG.COLORS.Blue,
    })

    -- System Stats
    InfoSection:Paragraph({
        Title = "System",
        Desc = string.format("Executor: %s\nScript Version: 1.0.0\nWindUI Version: %s", 
            getExecutor(), 
            (WindUI.Version or "Latest")),
        Image = "solar:monitor-smartphone-bold", -- Mobile/PC icon
        ImageColor = CONFIG.COLORS.Purple,
    })

    Tab:Space({ Size = 10 })

    -- ========================================
    -- CHANGELOG
    -- ========================================
    local ChangelogSection = Tab:Section({
        Title = "What's New",
        Box = true,
        BoxBorder = true, -- Distinct look
        Opened = true,
    })

    local changes = {
        { "New UI Design", "Completely redesigned Home tab for better clarity." },
        { "Mobile Support", "Fixed topbar buttons and spacing for mobile users." },
        { "Local Loader", "Optimized loading speed with local debug server." },
    }

    for _, change in ipairs(changes) do
        ChangelogSection:Paragraph({
            Title = change[1],
            Desc = change[2],
            Image = "solar:check-circle-bold",
            ImageColor = CONFIG.COLORS.Green,
        })
    end

    Tab:Space({ Size = 10 })

    -- ========================================
    -- ACTION CENTER
    -- ========================================
    local ActionSection = Tab:Section({
        Title = "Quick Actions",
    })

    ActionSection:Button({
        Title = "Unload Script",
        Desc = "Clean up and close the interface",
        Icon = "solar:trash-bin-trash-bold",
        Color = CONFIG.COLORS.Red,
        Callback = function()
            if getgenv and getgenv().OP_WINDOW then
                getgenv().OP_WINDOW = nil
            end
            Window:Destroy() -- WindUI destroy method
        end,
    })

    return Tab
end

return HomeTab
