--[[
    UI/Tabs/HomeTab.lua
    Home/Dashboard tab - Clean design without collapsible sections
]]

local HomeTab = {}

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function getExecutor()
    local success, name = pcall(function()
        return identifyexecutor and identifyexecutor() or nil
    end)
    return (success and name) or "Unknown"
end

local function getAvatarUrl()
    local success, url = pcall(function()
        return Players:GetUserThumbnailAsync(
            LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
    end)
    return (success and url) or ""
end

local function formatAccountAge(days)
    if days >= 365 then
        return math.floor(days / 365) .. " years"
    elseif days >= 30 then
        return math.floor(days / 30) .. " months"
    else
        return days .. " days"
    end
end

-- ============================================
-- CREATE HOME TAB
-- ============================================
function HomeTab.Create(Window, CONFIG, WindUI)
    local Tab = Window:Tab({
        Title = "Home",
        Icon = "solar:home-2-bold",
        IconColor = CONFIG.COLORS.Blue,
    })

    -- ========================================
    -- PLAYER INFO (Direct on Tab = no toggle)
    -- ========================================
    Tab:Paragraph({
        Title = LocalPlayer.DisplayName,
        Desc = string.format("@%s • Account Age: %s", 
            LocalPlayer.Name, 
            formatAccountAge(LocalPlayer.AccountAge)),
        Image = getAvatarUrl(),
    })

    Tab:Space({ Size = 8 })

    -- ========================================
    -- SYSTEM INFO
    -- ========================================  
    Tab:Paragraph({
        Title = getExecutor(),
        Desc = string.format("Script v1.2.1 • WindUI v%s", WindUI.Version or "Latest"),
        Image = "solar:monitor-bold",
        ImageColor = CONFIG.COLORS.Purple,
    })

    Tab:Space({ Size = 8 })

    -- ========================================
    -- CHANGELOG
    -- ========================================
    Tab:Paragraph({
        Title = "v1.2.1 - Dashboard Update",
        Desc = "• Clean Home tab\n• God Mode (DamagePlayer)\n• Auto Eat with scanner",
        Image = "solar:star-bold",
        ImageColor = CONFIG.COLORS.Yellow,
    })

    Tab:Space({ Size = 12 })

    -- ========================================
    -- QUICK ACTIONS
    -- ========================================
    Tab:Button({
        Title = "Copy Discord Invite",
        Icon = "solar:link-bold",
        Color = CONFIG.COLORS.Blue,
        Callback = function()
            if setclipboard then
                setclipboard("https://discord.gg/yourserver")
                WindUI:Notify({
                    Title = "Discord",
                    Content = "Invite link copied!",
                    Icon = "solar:check-circle-bold",
                    Duration = 3,
                })
            end
        end,
    })

    Tab:Button({
        Title = "Unload Script",
        Icon = "solar:logout-3-bold",
        Color = CONFIG.COLORS.Red,
        Callback = function()
            -- Stop all features
            if getgenv and getgenv().OP_FEATURES then
                for name, feature in pairs(getgenv().OP_FEATURES) do
                    pcall(function()
                        if feature.Stop then 
                            feature.Stop() 
                            print("[OP] Stopped: " .. tostring(name))
                        end
                    end)
                end
                getgenv().OP_FEATURES = nil
            end
            
            -- Clear global state
            if getgenv then
                getgenv().OP_WINDOW = nil
                getgenv().OP_DEBUG = nil
                getgenv().OP_BASE_PATH = nil
            end
            
            -- Destroy UI completely
            Window:Destroy()
            
            -- Notify user
            print("[OP] Script unloaded successfully! All features stopped.")
        end,
    })

    return Tab
end

return HomeTab
