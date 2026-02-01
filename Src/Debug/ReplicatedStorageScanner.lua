--[[
    Debug/ReplicatedStorageScanner.lua
    Deep scans ReplicatedStorage and exports a clean, indented text dump.
    
    Output File: replicated_storage_dump.txt
    Features:
    - Lists all Remotes, Modules, and Folders
    - Shows values for StringValue, IntValue, BoolValue, etc.
]]

local RSScanner = {}

-- Settings
local OUTPUT_FILE = "replicated_storage_dump.txt"
local INDENT_SIZE = 2
local MAX_DEPTH = 20
local PREVIEW_VALUE_LEN = 50 -- Max length for value strings

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Helper: Get object details string
local function getObjectDetails(obj)
    local details = {}
    
    -- Show Value for ValueBase objects
    if obj:IsA("ValueBase") and obj.ClassName ~= "ObjectValue" then
        local val = tostring(obj.Value)
        if #val > PREVIEW_VALUE_LEN then
            val = string.sub(val, 1, PREVIEW_VALUE_LEN) .. "..."
        end
        table.insert(details, "Value: " .. val)
    end
    
    -- Show ObjectValue target
    if obj:IsA("ObjectValue") then
        local target = obj.Value
        table.insert(details, "Target: " .. (target and target.Name or "nil"))
    end
    
    -- Tag Remotes for easier spotting
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        table.insert(details, "⭐ REMOTE")
    end
    
    -- Tag Modules
    if obj:IsA("ModuleScript") then
        table.insert(details, "📜 MODULE")
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
    -- Sort children: Folders first, then alphabetically? Or just default?
    -- Default is usually fine, but sorting helps reading. Let's sort manually.
    table.sort(children, function(a, b)
        return a.Name < b.Name
    end)
    
    for _, child in ipairs(children) do
        scanRecursive(child, depth + 1, buffer)
    end
end

-- Main Function
function RSScanner.Run()
    print("[Scanner] Starting ReplicatedStorage scan...")
    local startTime = os.clock()
    
    local buffer = {}
    table.insert(buffer, "=== REPLICATED STORAGE DUMP ===")
    table.insert(buffer, "Time: " .. os.date("%c"))
    table.insert(buffer, "===============================")
    
    -- Start scan
    scanRecursive(ReplicatedStorage, 0, buffer)
    
    -- Join buffer
    local content = table.concat(buffer, "\n")
    
    -- Write to file logic (try writefile, fallback to print preview)
    local success, err = pcall(function()
        writefile(OUTPUT_FILE, content)
    end)
    
    if success then
        print("[Scanner] Output saved to: " .. OUTPUT_FILE)
    else
        warn("[Scanner] writefile failed, printing preview only.")
    end
    
    local duration = math.floor((os.clock() - startTime)*10)/10
    print("[Scanner] Scan complete in " .. duration .. "s!")
    print("[Scanner] Total Lines: " .. #buffer)

    return content
end

return RSScanner
