## PROJECT OVERVIEW

**Nama:** 99 Nights In The Forest - OP Script  
**Game:** Roblox (99 Nights In The Forest)  
**Version:** 1.2.2  
**UI Library:** WindUI (local, custom)  
**Architecture:** Modular dengan clean unload system

---

## 📁 PROJECT STRUCTURE

```
Nforst/
├── main.lua                  # Entry point, module loader
├── Src/
│   ├── Core/                 # Core utilities
│   │   ├── Config.lua        # All feature settings & constants
│   │   ├── Utils.lua         # Helper functions
│   │   ├── Scanner.lua       # Game object scanning
│   │   └── RemoteHandler.lua # RemoteEvent wrappers
│   ├── Features/             # Feature Logic (modular)
│   │   ├── GodMode.lua       # Infinite health
│   │   ├── AutoEat.lua       # Smart food consumption
│   │   ├── KillAura.lua      # Auto attack enemies
│   │   └── MapRevealer.lua   # Reveal map fog
│   └── UI/                   # User Interface
│       ├── MainInterface.lua # Main Window setup
│       └── Tabs/
│           ├── HomeTab.lua   # Dashboard (flat layout)
│           ├── CombatTab.lua # Combat features
│           ├── SurvivalTab.lua # Collapsible sections
│           └── SettingsTab.lua # Config & themes
├── WindUI/                   # UI Library (local copy)
│   ├── src/Init.lua          # WindUI main
│   ├── src/components/       # UI components
│   ├── src/elements/         # UI elements (Toggle, Slider, etc)
│   └── src/themes/           # 16 built-in themes
├── replicated_storage_dump.txt  # Game ReplicatedStorage structure
└── workspace_dump.txt           # Game Workspace structure
```

---

## 🎮 GAME STRUCTURE (DARI DUMP FILES)

### ReplicatedStorage Structure:
- **Assets/** - Game assets folder
  - **Alec/** - NPC/Character assets
    - BuildArea [MeshPart]
    - FakeDiamond [Model]
    - LeafPileTracks [Model] - Contains ChestMarker with ProximityPrompt
    - MapClient [Folder] - Map UI with Biome frames
- **MapClient/Map/** - Map UI dengan Biome0-Biome63 frames
- **Icons/** - Map icons folder

### Workspace Structure:
- **Characters/** - NPCs folder
  - **Mossy Wolf [Model]** - Enemy NPC
    - NPC [Humanoid]
    - Animations: Run, Attack, Walk, Sit, Eat
    - NPCTarget [ObjectValue]
    - NpcEvent [RemoteEvent] - For NPC interactions
    - HealthBar [BillboardGui]
- **MusicNORMAL [Sound]** - Background music
- **Camera** - Player camera

### Key Game Elements:
- **ProximityPrompt** - Untuk interaksi (chests, items)
- **RemoteEvent (NpcEvent)** - Untuk komunikasi client-server
- **Humanoid** - NPC health system
- **BillboardGui** - Health bars
- **ObjectValue (NPCTarget)** - NPC targeting system

---

## 🏗️ ARCHITECTURE RULES (WAJIB DIKUTI)

### 1. Feature Module Pattern
Setiap feature di `Src/Features/` HARUS mengikuti pattern ini:

```lua
local FeatureName = {}

-- Dependencies
local Remote = nil

-- State
local State = {
    Enabled = false,
    Thread = nil,
}

-- Public API
function FeatureName.Init(deps)
    Remote = deps.Remote
end

function FeatureName.Start()
    if State.Thread then return end
    State.Enabled = true
    State.Thread = task.spawn(function()
        while State.Enabled do
            -- Logic here
            task.wait(1)
        end
        State.Thread = nil
    end)
end

function FeatureName.Stop()
    State.Enabled = false
end

function FeatureName.IsEnabled()
    return State.Enabled
end

return FeatureName
```

### 2. Clean Unload (WAJIB)
Setiap feature HARUS bisa di-stop bersih via `Stop()` function.
Unload button akan memanggil semua `feature.Stop()`.

### 3. Config System
Semua settings ada di `Src/Core/Config.lua`:
- Gunakan struktur table yang terorganisir
- Format: `Config.FeatureName = { Enabled = false, ... }`

### 4. UI Integration
- Gunakan WindUI library (local)
- Tabs di `Src/UI/Tabs/`
- Main window setup di `Src/UI/MainInterface.lua`

---

## 🎨 WINDUI USAGE

WindUI adalah UI library custom. Element yang tersedia:
- **Toggle** - On/Off switch
- **Slider** - Numeric input
- **Dropdown** - Select from list
- **Button** - Click action
- **Input** - Text input
- **Label** - Display text
- **Section** - Collapsible group
- **Keybind** - Key binding

Contoh penggunaan:
```lua
Tab:Section({ Title = "Survival" })

Tab:Toggle({
    Title = "God Mode",
    Default = Config.GodMode.Enabled,
    Callback = function(value)
        Config.GodMode.Enabled = value
        if value then GodMode.Start() else GodMode.Stop() end
    end
})
```

---

## ⚙️ CONFIG CATEGORIES

1. **Survival:** GodMode, AutoEat, AutoWarmth
2. **Combat:** KillAura, MiningAura
3. **Automation:** AutoLoot, AutoPlant
4. **Visual:** MapRevealer, ESP
5. **System:** Config persistence, Theme selector

---

## 📝 CODING STANDARDS

1. **Gunakan `task.spawn()`** untuk async operations
2. **Gunakan `pcall()`** untuk remote calls
3. **State management** via local State table
4. **Logging** dengan format: `[OP] FeatureName: message`
5. **Cleanup** selalu implement `Stop()` function
6. **Dependencies** inject via `Init(deps)` pattern

---

## 🎯 SAAT MEMBUAT FITUR BARU

1. Buat file di `Src/Features/NamaFitur.lua`
2. Tambah config di `Src/Core/Config.lua`
3. Tambah UI di tab yang sesuai (`Src/UI/Tabs/`)
4. Register di `MainInterface.lua`
5. Implement clean unload di `Stop()`
6. Test unload button berfungsi dengan baik

---

## ⚠️ PENTING

- SELALU GUNAKAN THINKING, PAHAMI SAMPAI BENAR BENAR PAHAM
- JANGAN lupa implement `Stop()` function
- JANGAN buat infinite loop tanpa `task.wait()`
- JANGAN lupa cleanup threads saat unload
- SELALU gunakan `pcall()` untuk remote calls
- SELALU ikuti pattern existing
- REFERENSI dump files untuk memahami struktur game
