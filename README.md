# 99 Nights In The Forest - OP Script

> **🎮 Game:** 99 Nights In The Forest (Roblox)  
> **📅 Last Updated:** 2026-02-01  
> **🔧 Version:** 2.6.0

Modular survival script dengan WindUI, clean architecture, dan config persistence.

---

## 📋 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Project Structure](#-project-structure)
- [Tools](#-tools)
- [Coding Standards](#-coding-standards)
- [Development Guide](#-development-guide)
- [Credits](#-credits)

---

## ✨ Features

| Feature | Category | Description |
|---------|----------|-------------|
| **Dashboard** | 🏠 UI | Home tab dengan User Info & Changelog |
| **Chest Explorer** | 🗺️ Explorer | **NEW!** Auto Scan & Open Chests (Fly Stabilizer + Teleport) |
| **Map Revealer** | 🗺️ Explorer | Spiral fly untuk remove fog + Satellite Camera |
| **Universal Fly** | 🚀 Movement | **NEW!** PC/Mobile Fly (NoClip, Camera Aim Assist) |
| **Walk Speed** | 🚀 Movement | **NEW!** Persistent Speed Hack (Anti-Slow) |
| **God Mode** | 🛡️ Survival | Infinite health |
| **Auto Eat** | 🛡️ Survival | Smart food consumption system |
| **Kill Aura** | ⚔️ Combat | Auto melee nearby enemies (75 studs) |
| **Tree Farm** | 🌲 Farming | Burst chopping (instant), smart tier check |
| **Auto Plant** | 🌲 Farming | 6 Patterns (Heart, Star, etc) + Preview |
| **Item Collector** | 🎒 Inventory | Auto collect items with optimized filtering |
| **Anti-Lag** | 🔧 System | Delete All Sounds mode for max FPS |

### New Features (v2.6.0)
- **Chest Explorer v2.1**: Menggunakan sistem **Hybrid Teleport + Fly Stabilizer**. Karakter tidak akan jatuh ke void atau nyangkut. Aman reload script (Auto Cleanup).
- **Universal Fly**:
  - **PC**: WASD + Spasi (Naik) + Ctrl (Turun).
  - **Mobile**: Gunakan Joystick + Arahkan Kamera ke Atas/Bawah saat bergerak maju untuk terbang.
  - **NoClip**: Otomatis aktif.
- **Walk Speed**: Slider 16-200. Kecepatan **Persistent** (tidak akan reset saat respawn/efek slow).
- **Kill Aura**: Support senjata **Scythe**.

### Map Revealer Details
- **Spiral Fly**: Otomatis terbang spiral dari Campfire ke radius max
- **Satellite Camera**: Top-down view untuk menghindari pusing
- **Beam ESP**: Garis merah vertikal + circle untuk tracking posisi player
- **Anchor Mode**: Safe return tanpa jatuh ke void
- **Clean Unload**: Full resource cleanup saat stop/unload

### Combat & Farming
- **Kill Aura**: Auto-detect equipped melee (Sword, Axe, **Scythe**, etc), 75 studs range
- **Tree Farm**: Auto-detect equipped axe, scans `Workspace.Map` only (optimized)
- Both features idle when no tool equipped (saves CPU)

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

Nforst/
├── main.lua                  # Entry point
├── Src/
│   ├── Core/                 # Core utilities
│   │   ├── Config.lua        # Settings & Constants
│   │   ├── Utils.lua         # Helper functions
│   │   └── RemoteHandler.lua # Remote wrappers
│   ├── Features/             # Feature Logic
│   │   ├── AutoEat.lua       
│   │   ├── GodMode.lua       
│   │   ├── KillAura.lua      # Melee combat (75 studs)
│   │   ├── TreeFarm.lua      # Burst chop (v2.5)
│   │   ├── MapRevealer.lua   # Spiral fly + ESP
│   │   ├── AutoPlant.lua     # Pattern planting (v2.5)
│   │   ├── SoundManager.lua  # Anti-Lag / Delete Mode (v2.5)
│   │   ├── ItemCollector.lua # Optimized Item Scan (v2.6)
│   │   ├── ChestExplorer.lua # Chest Auto-Open (v2.6)
│   │   ├── Fly.lua           # Universal Fly (v2.6)
│   │   └── Speed.lua         # Persistent Speed (v2.6)
│   └── UI/                   # User Interface
│       ├── MainInterface.lua # Main Window
│       └── Tabs/             
│           ├── HomeTab.lua   # Dashboard + Unload
│           ├── SurvivalTab.lua 
│           ├── CombatTab.lua 
│           ├── FarmingTab.lua # Tree Farm & Auto Plant
│           ├── ExplorerTab.lua # Map Revealer & Chest Explorer
│           ├── MiscTab.lua   # Movement (Fly/Speed) & Utilities
│           ├── AutoCollectTab.lua # Item Collector Control
│           └── SettingsTab.lua 
├── WindUI/                   # UI Library (local)
└── CobaltLogCleaner/         # Log analysis tool

---

## 🔧 Tools

### Cobalt Log Cleaner (v3.0)

Tool untuk membersihkan Cobalt executor logs (`.log` format) menjadi single-line Lua code.

**Keuntungan .log vs .html:**
| | .html | .log |
|---|-------|------|
| **Full Path** | ❌ `--[[Nil Parent]]` | ✅ `workspace.Map.Foliage["Small Tree"]` |
| **Arguments** | ✅ | ✅ |
| **Single Line** | ✅ | ✅ |

**Usage:**
```bash
cd CobaltLogCleaner
python cleaner.py
# Select: 1 (Latest), 2 (All), or 3 (Pick from list)
```

**Sample Output:**
```lua
game:GetService("ReplicatedStorage").RemoteEvents.ToolDamageObject:InvokeServer(workspace.Map.Foliage["Small Tree"], game:GetService("Players").LocalPlayer.Inventory["Old Axe"], "1_8401342884", CFrame.new(...))
```

---

## 📐 Coding Standards

### 1. Clean Unload (WAJIB)

Setiap feature **HARUS** bisa di-cleanup dengan bersih. Unload button akan call `Cleanup()` first, fallback ke `Stop()`:

```lua
-- HomeTab.lua - Unload Callback
Callback = function()
    if getgenv().OP_FEATURES then
        for name, feature in pairs(getgenv().OP_FEATURES) do
            pcall(function()
                -- Cleanup > Stop priority
                if feature.Cleanup then 
                    feature.Cleanup()
                elseif feature.Stop then 
                    feature.Stop()
                end
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

### 2. Feature Module Pattern

Setiap feature di `/Src/Features/` harus mengikuti pola:

```lua
local FeatureName = {}

local State = {
    Enabled = false,
}

function FeatureName.Init(deps)
    -- Initialize dependencies
end

function FeatureName.Start()
    State.Enabled = true
    -- Feature logic
end

function FeatureName.Stop()
    State.Enabled = false
end

-- OPTIONAL: Full cleanup untuk resource-heavy features
function FeatureName.Cleanup()
    State.Enabled = false
    -- Disconnect connections
    -- Destroy instances
    -- Clear caches
end

return FeatureName
```

### 3. Performance Optimization

```lua
-- ✅ BENAR - Scan folder tertentu
local mapFolder = Workspace:FindFirstChild("Map")
for _, entity in ipairs(mapFolder:GetDescendants()) do

-- ❌ SALAH - Scan seluruh Workspace (LAG!)
for _, entity in ipairs(Workspace:GetDescendants()) do
```

### 4. Config Save/Load (Flag System)

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

---

## 🔨 Development Guide

### Adding New Feature

1. **Buat Module** di `Src/Features/NewFeature.lua`
2. **Implement Pattern** (Init, Start, Stop, Cleanup)
3. **Register** di `MainInterface.lua`:
   ```lua
   Features.NewFeature = require("Features/NewFeature")
   Features.NewFeature.Init(deps)
   getgenv().OP_FEATURES.NewFeature = Features.NewFeature
   ```
4. **Buat UI** di Tab yang sesuai dengan Flag

### Adding New Tab

1. Buat file `Src/UI/Tabs/NewTab.lua`
2. Export function `NewTab.Create(Window, Features, CONFIG, WindUI)`
3. Import di `MainInterface.lua`

### Testing

```bash
# Start debug server
cd Nforst/Server
python3 debug_server.py

# Load di executor
loadstring(game:HttpGet("http://localhost:8000/main.lua"))()
```

---

## 📜 Changelog

### v2.6.0 (2026-02-01)
- **Chest Explorer**: Upgraded to v2.1 with Teleport + Fly Stabilizer (Anti-Void)
- **Features**: Added **Universal Fly** (PC/Mobile NoClip) in Misc Tab
- **Features**: Added **Walk Speed** (Persistent) in Misc Tab
- **Combat**: Added Scythe support to Kill Aura
- **Optimization**: Reduced Item Collector scan lag
- **Docs**: Updated README.md

### v2.5.0 (2026-01-30)
- **AutoPlant**: Added pattern generator (Circle, Square, Triangle, Heart, Star, Spiral)
- **AutoPlant**: Added part pooling for efficient previews
- **TreeFarm**: Burst Logic (Instant sequential chopping) with smart tier detection
- **SoundManager**: Added Sound Mute feature with "Delete Mode" for extreme anti-lag
- **UI**: Added **Misc** tab for generic utilities (Mute, Notifs)

### v2.4.0 (2026-01-30)
- **TreeFarm**: Optimized to scan `Workspace.Map` only (10x faster)
- **TreeFarm**: Added MapFolder cache, increased CYCLE_DELAY
- **CobaltLogCleaner**: v3.0 - Single-line output with full paths
- **README**: Updated with all tools and features

### v2.3.0 (2026-01-30)
- **MapRevealer**: New Beam ESP (vertical line + circle marker)
- **MapRevealer**: Anchor Mode for safe return (anti-void fall)
- **MapRevealer**: Removed fog counting (memory optimization)
- **Cleanup System**: Enhanced with `Cleanup()` function priority
- **Code Cleanup**: Removed unused functions, consolidated configs

### v2.2.0 (2026-01-29)
- **MapRevealer**: with Spiral Fly
- **Satellite Camera**: mode
- **Streaming-aware**: teleport

---

## 🙏 Credits

- **UI Library**: [WindUI by Footagesus](https://github.com/Footagesus/WindUI)

---

## ⚠️ Disclaimer

Script untuk edukasi. Penggunaan exploit melanggar ToS dan berisiko ban.

---

<p align="center">
  <b>99 Nights OP Script v2.6.0</b><br>
  Built with ❤️ using WindUI
</p>
