# WindUI Documentation & Cheat Sheet

This guide explains how to use the WindUI library components based on the source code analysis.

## 1. Window Creation

```lua
local Window = WindUI:CreateWindow({
    Title = "My Script",
    Author = "My Name", -- Optional: Shows below title
    Icon = "rbxassetid://10723415903", -- Optional
    IconSize = 22, -- Default: 22
    Theme = "Dark", -- "Dark" or "Light"
    Transparency = false, -- Enable transparent background
    Acrylic = true, -- Enable blur effect
    ToggleKey = Enum.KeyCode.RightControl, -- Key to hide/show UI
    Size = UDim2.new(0, 580, 0, 460), -- Default size
    MinSize = Vector2.new(560, 350), -- Minimum resize limit
    Resizable = true, -- Allow user to resize UI
    Folder = "MyScript", -- Folder for saving assets/configs
})
```

## 2. Tabs & Sections

**Create a Tab:**
```lua
local HomeTab = Window:Tab({
    Title = "Home",
    Icon = "home", -- Lucide icon name (e.g. "home", "settings", "user")
    IconColor = Color3.fromRGB(255, 255, 255), -- Optional
})
```

**Create a Section:**
```lua
local MainSection = HomeTab:Section({
    Title = "Main Features",
    Icon = "star", -- Optional icon for section header
})
```

## 3. UI Elements

### Button
```lua
MainSection:Button({
    Title = "Click Me",
    Desc = "This is a description", -- Optional
    Icon = "zap", -- Optional Icon
    Callback = function()
        print("Button clicked")
    end
})
```

### Toggle (Switch & Checkbox)
```lua
-- Standard Toggle (Switch)
MainSection:Toggle({
    Title = "Auto Farm",
    Desc = "Enable auto farming",
    Value = false, -- Default value
    Callback = function(state)
        print("Auto Farm:", state)
    end
})

-- Checkbox Style
MainSection:Toggle({
    Title = "Silent Aim",
    Type = "Checkbox", -- Changes look to a checkbox
    Value = false,
    Callback = function(state)
        print("Silent Aim:", state)
    end
})
```

### Slider
```lua
MainSection:Slider({
    Title = "Walk Speed",
    Desc = "Set your character speed",
    Value = {
        Min = 16,
        Max = 100,
        Default = 16
    },
    Step = 1, -- Increment step (supports decimals)
    Icons = {
        From = "turtle", -- Optional start icon
        To = "rabbit",   -- Optional end icon
    },
    Callback = function(value)
        print("Speed set to:", value)
    end
})
```

### Dropdown
```lua
MainSection:Dropdown({
    Title = "Select Weapon",
    Desc = "Choose your weapon",
    Values = {"Sword", "Bow", "Axe"}, -- List of options
    Value = "Sword", -- Default option
    Multi = false, -- Set to true for multi-select
    Callback = function(value)
        -- value is string (or table if Multi=true)
        print("Selected:", value)
    end
})
```

### Input (Textbox)
```lua
MainSection:Input({
    Title = "Target Player",
    Desc = "Enter player name",
    Value = "", -- Default text
    Placeholder = "Username...",
    Callback = function(text)
        print("Input:", text)
    end
})
```

### Colorpicker
```lua
MainSection:Colorpicker({
    Title = "ESP Color",
    Desc = "Change ESP color",
    Default = Color3.fromRGB(255, 0, 0),
    Transparency = 0, -- Set to non-nil (e.g. 0) to enable Alpha slider
    Callback = function(color, transparency)
        print("New Color:", color)
    end
})
```

### Keybind
```lua
MainSection:Keybind({
    Title = "Toggle Menu",
    Desc = "Bind key to toggle",
    Value = Enum.KeyCode.RightControl, -- Default key
    CanChange = true, -- Allow user to change key
    Callback = function()
        print("Key pressed")
    end
})
```

### Paragraph (Label)
```lua
MainSection:Paragraph({
    Title = "Information",
    Desc = "This requires some key to be pressed."
})
```

## 4. Notifications

```lua
WindUI:Notify({
    Title = "Success",
    Content = "Settings saved!",
    Duration = 3, -- Seconds
    Icon = "check" -- Optional icon
})
```

## Icons
WindUI uses **Lucide Icons**. You can find icon names at [lucide.dev](https://lucide.dev/icons) (use lowercase names).
