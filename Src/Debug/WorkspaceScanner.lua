--[[
    Debug/WorkspaceScanner.lua
    Deep scans the Workspace and exports a clean, indented text dump.
    
    Output File: workspace_dump.txt
    Format:
    Name [ClassName] (Pos: X, Y, Z | Size: X, Y, Z)
      ChildName [ClassName] ...
]]

local WorkspaceScanner = {}

-- Settings
local OUTPUT_FILE = "workspace_dump.txt"
local INDENT_SIZE = 2
local MAX_DEPTH = 20 -- Prevent infinite recursion loops
local ROUND_DECIMALS = 1

-- Services
local Workspace = game:GetService("Workspace")

-- Helper: Round number
local function round(num)
    return math.floor(num * (10 ^ ROUND_DECIMALS) + 0.5) / (10 ^ ROUND_DECIMALS)
end

-- Helper: Format Vector3
local function formatVector(v)
    if not v then return "-" end
    return round(v.X) .. ", " .. round(v.Y) .. ", " .. round(v.Z)
end

-- Helper: Get object details string
local function getObjectDetails(obj)
    local details = {}
    
    -- Position (for BasePart and Model)
    if obj:IsA("BasePart") then
        table.insert(details, "Pos: " .. formatVector(obj.Position))
        table.insert(details, "Size: " .. formatVector(obj.Size))
    elseif obj:IsA("Model") then
        local pivot = obj:GetPivot()
        if pivot then
             table.insert(details, "Pos: " .. formatVector(pivot.Position))
        end
    end
    
    if #details > 0 then
        return " (" .. table.concat(details, " | ") .. ")"
    end
    return ""
end

-- Recursive Scan Function
local function scanRecursive(obj, depth, buffer)
    if depth > MAX_DEPTH then return end
    
    -- Format: Indentation + Name + [ClassName] + Details
    local indent = string.rep(" ", depth * INDENT_SIZE)
    local line = string.format("%s%s [%s]%s", 
        indent, 
        obj.Name, 
        obj.ClassName, 
        getObjectDetails(obj)
    )
    
    table.insert(buffer, line)
    
    -- Process children
    local children = obj:GetChildren()
    for _, child in ipairs(children) do
        scanRecursive(child, depth + 1, buffer)
    end
end

-- Main Function
function WorkspaceScanner.Run()
    print("[Scanner] Starting Workspace scan...")
    local startTime = os.clock()
    
    local buffer = {}
    table.insert(buffer, "=== WORKSPACE DUMP ===")
    table.insert(buffer, "Time: " .. os.date("%c"))
    table.insert(buffer, "======================")
    
    -- Start scan from Workspace
    scanRecursive(Workspace, 0, buffer)
    
    -- Join buffer
    local content = table.concat(buffer, "\n")
    
    -- Write to file
    local success, err = pcall(function()
        writefile(OUTPUT_FILE, content)
    end)
    
    if success then
        local duration = round(os.clock() - startTime)
        print("[Scanner] Scan complete in " .. duration .. "s!")
        print("[Scanner] Output saved to: " .. OUTPUT_FILE)
        print("[Scanner] Total Lines: " .. #buffer)
        
        -- Notify UI if available
        if getgenv and getgenv().OP_WINDOW and getgenv().OP_WINDOW.Notify then
            getgenv().OP_WINDOW:Notify({
                Title = "Scan Complete",
                Content = "Saved to " .. OUTPUT_FILE,
                Duration = 5
            })
        end
    else
        warn("[Scanner] Failed to write file: " .. tostring(err))
    end
    
    return content
end

return WorkspaceScanner
