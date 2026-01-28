# 99 Nights In The Forest - OP Script

> **🎮 Game:** 99 Nights In The Forest (Roblox)  
> **📅 Last Updated:** 2026-01-28  
> **🔧 Version:** 1.2.2

Modular survival script dengan WindUI, clean architecture, dan config persistence.

---

## 📋 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Project Structure](#-project-structure)
- [Coding Standards](#-coding-standards)
- [Development Guide](#-development-guide)
- [Credits](#-credits)

---

## ✨ Features

| Feature | Category | Description |
|---------|----------|-------------|
| **Dashboard** | 🏠 UI | Home tab dengan User Info & Changelog |
| **God Mode** | 🛡️ Survival | Infinite health |
| **Auto Eat** | 🛡️ Survival | Smart food consumption system |
| **Config System** | 🔧 System | Save & Load settings dengan Flag system |
| **Theme Selector** | 🎨 UI | 16 WindUI themes |
| **Notification Control** | 🔔 System | Toggle untuk disable semua notifikasi |

---

## 🚀 Installation

```lua
-- Option 1: Local Development
getgenv().OP_BASE_PATH = "C:/path/to/Nforst/"
loadstring(readfile("path/to/Nforst/main.lua"))()

-- Option 2: Remote Load
loadstring(game:HttpGet("http://192.168.1.5:8000/main.lua"))()
```

---

## 📁 Project Structure

```
Nforst/
├── main.lua                  # Entry point
├── Src/
│   ├── Core/                 # Core utilities
│   │   ├── Config.lua        # Settings & Constants
│   │   ├── Utils.lua         # Helper functions
│   │   └── RemoteHandler.lua # Remote wrappers
│   ├── Features/             # Feature Logic
│   │   ├── AutoEat.lua       
│   │   └── GodMode.lua       
│   └── UI/                   # User Interface
│       ├── MainInterface.lua # Main Window
│       └── Tabs/             
│           ├── HomeTab.lua   # Dashboard (flat layout)
│           ├── SurvivalTab.lua # Collapsible sections
│           └── SettingsTab.lua # Flat layout
└── WindUI/                   # UI Library (local)
```

---

## 📐 Coding Standards

### 1. Clean Unload (WAJIB)

Setiap feature **HARUS** bisa di-stop dengan bersih. Unload button harus:

```lua
-- HomeTab.lua - Unload Callback
Callback = function()
    -- Stop ALL features
    if getgenv().OP_FEATURES then
        for name, feature in pairs(getgenv().OP_FEATURES) do
            pcall(function()
                if feature.Stop then feature.Stop() end
            end)
        end
        getgenv().OP_FEATURES = nil
    end
    
    -- Clear ALL globals
    getgenv().OP_WINDOW = nil
    getgenv().OP_DEBUG = nil
    getgenv().OP_BASE_PATH = nil
    
    -- Destroy UI
    Window:Destroy()
end
```

### 2. Config Save/Load (Flag System)

Setiap UI element yang perlu di-save **HARUS** memiliki `Flag`:

```lua
-- ✅ BENAR - Akan tersimpan
Tab:Toggle({
    Flag = "GodMode.Enabled",  -- WAJIB untuk config save
    Title = "Enable God Mode",
    Value = false,
    Callback = function(state) ... end,
})

-- ❌ SALAH - Tidak tersimpan
Tab:Toggle({
    Title = "Enable God Mode",  -- Tidak ada Flag!
    Value = false,
    Callback = function(state) ... end,
})
```

**Flag Naming Convention:**
- Format: `Category.SettingName`
- Contoh: `GodMode.Enabled`, `AutoEat.HungerThreshold`, `System.Theme`

### 3. Feature Module Pattern

Setiap feature di `/Src/Features/` harus mengikuti pola:

```lua
local FeatureName = {}

local State = {
    Enabled = false,
    Thread = nil,
}

function FeatureName.Init(deps)
    -- Initialize dependencies
end

function FeatureName.Start()
    if State.Thread then return end  -- Prevent duplicate
    State.Enabled = true
    State.Thread = task.spawn(function()
        while State.Enabled do
            -- Feature logic
            task.wait(1)
        end
        State.Thread = nil
    end)
end

function FeatureName.Stop()
    State.Enabled = false  -- Thread akan cleanup sendiri
end

return FeatureName
```

### 4. UI Tab Layout

**HomeTab & SettingsTab → Flat Layout (tanpa chevron):**
```lua
Tab:Paragraph({ Title = "Section Title", ... })
Tab:Toggle({ ... })
Tab:Button({ ... })
Tab:Space({ Size = 12 })
```

**SurvivalTab & Feature Tabs → Collapsible Sections:**
```lua
local Section = Tab:Section({
    Title = "Section Name",
    Icon = "solar:icon-bold",
    Box = true,           -- Enable collapsible
    BoxBorder = true,
    Opened = true,        -- Default expanded
})

Section:Toggle({ ... })
Section:Slider({ ... })

Tab:Space({ Size = 10 })  -- Space between sections
```

### 5. Notification System

**Konfigurasi default (di `WindUI/dist/main.lua`):**
- Position: Left side, 46% from top
- Width: 180px
- Duration: 3 seconds
- Single mode: New notif replaces old

**Disable via Settings:**
```lua
-- Toggle di SettingsTab
Tab:Toggle({
    Flag = "System.DisableNotifications",
    Title = "Disable Notifications",
    Callback = function(state)
        getgenv().OP_DISABLE_NOTIF = state
    end,
})
```

### 6. Theme System

Gunakan WindUI themes dengan dropdown:
```lua
Tab:Dropdown({
    Flag = "System.Theme",  -- Tersimpan di config
    Title = "Theme",
    Values = themes,        -- dari WindUI:GetThemes()
    Value = WindUI:GetCurrentTheme(),
    Callback = function(theme)
        WindUI:SetTheme(theme)
    end,
})
```

---

## 🔨 Development Guide

### Adding New Feature

1. **Buat Module** di `Src/Features/NewFeature.lua`
2. **Ikuti Pattern** (Init, Start, Stop)
3. **Register** di `MainInterface.lua`:
   ```lua
   Features.NewFeature = require("Features/NewFeature")
   Features.NewFeature.Init(deps)
   getgenv().OP_FEATURES.NewFeature = Features.NewFeature
   ```
4. **Buat UI** di Tab yang sesuai dengan Flag

### Adding New Tab

1. Buat file `Src/UI/Tabs/NewTab.lua`
2. Pilih layout: Flat atau Collapsible
3. Pastikan semua UI elements punya Flag
4. Import di `MainInterface.lua`

### Testing

```bash
# Start debug server
cd Nforst/Server
python3 debug_server.py

# Load di executor
loadstring(game:HttpGet("http://localhost:8000/main.lua"))()
```

---

## 🙏 Credits

- **UI Library**: [WindUI by Footagesus](https://github.com/Footagesus/WindUI)

---

## ⚠️ Disclaimer

Script untuk edukasi. Penggunaan exploit melanggar ToS dan berisiko ban.

---

<p align="center">
  <b>99 Nights OP Script v1.2.2</b><br>
  Built with ❤️ using WindUI
</p>
