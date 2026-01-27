# 99 Nights In The Forest - OP Script

> **🎮 Game:** 99 Nights In The Forest (Roblox)  
> **📅 Last Updated:** 2026-01-27  
> **🔧 Version:** 1.2.0

Script OP untuk game survival "99 Nights In The Forest" dengan arsitektur modular, UI WindUI yang clean, dan fitur lengkap.

---

## 📋 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Project Structure](#-project-structure)
- [Usage](#-usage)
- [Configuration](#-configuration)
- [Development](#-development)
- [Remote Mapping](#-remote-mapping)
- [Credits](#-credits)

---

## ✨ Features

Saat ini script memiliki **4 fitur utama** yang berfungsi penuh, sementara fitur lainnya masih dalam pengembangan (roadmap).

### ✅ Implemented Features

| Feature | Category | Description |
|---------|----------|-------------|
| **God Mode** | 🛡️ Survival | Infinite health via `DamagePlayer(-math.huge)` spam |
| **Auto Eat** | 🛡️ Survival | Smart system yang otomatis makan saat lapar (Scan & Eat) |
| **Config System** | 🔧 System | Save & Load settings, Auto-load last config |
| **Modular Core** | � System | Arsitektur modular yang stabil dan mudah di-maintain |

### � Roadmap (Coming Soon)

Fitur berikut sudah ada placeholder di code tapi **belum aktif**:

- [ ] **Auto Warmth**: Manage temperature & campfire
- [ ] **Kill Aura**: Auto attack enemies
- [ ] **Mining Aura**: Auto harvest resources
- [ ] **Auto Loot**: Auto pickup drops
- [ ] **Auto Plant**: Mass plant exploit
- [ ] **Auto Craft**: Crafting automation

---

## 🚀 Installation

### Option 1: Local Development

```lua
-- Set base path untuk development lokal
getgenv().OP_BASE_PATH = "C:/path/to/Nforst/"

-- Load script
loadstring(readfile("path/to/Nforst/main.lua"))()
```

### Option 2: Remote Load

```lua
-- Load dari debug server
loadstring(game:HttpGet("http://192.168.1.5:8000/main.lua"))()
```

### Dependencies

- **WindUI Library** - UI Framework
  - Location: `/Libs/WindUI/`
  - Source: [Footagesus/WindUI](https://github.com/Footagesus/WindUI)

---

## 📁 Project Structure

```
Nforst/
├── README.md                 # This file
├── main.lua                  # Entry point (Loaders)
├── Src/
│   ├── Core/                 # Core utilities
│   │   ├── Config.lua        # Settings & Catalog
│   │   ├── Utils.lua         # Helper functions
│   │   ├── RemoteHandler.lua # Remote wrappers
│   │   └── Scanner.lua       # Entity scanner
│   ├── Features/             # Feature Logic
│   │   ├── AutoEat.lua       # Auto Eat implementation
│   │   ├── GodMode.lua       # God Mode implementation
│   │   └── Placeholders.lua  # Future features
│   ├── UI/                   # User Interface
│   │   ├── MainInterface.lua # Main Window Layout
│   │   └── Tabs/             # Tab Components
│   │       ├── SurvivalTab.lua
│   │       ├── CombatTab.lua
│   │       ├── AutomationTab.lua
│   │       └── SettingsTab.lua
└── logs/                     # Debug logs
```

---

## 🎮 Usage

### UI Controls

1. **Tabs**: Navigasi antar kategori (Home, Survival, Combat, etc)
2. **Features**: Toggle fitur ON/OFF
3. **Settings**: Atur parameter seperti Radius, Threshold, dll
4. **Quick Actions**: 
   - `❌ Destroy UI` - Tutup dan bersihkan script
   - `⏹️ Stop All` - Matikan semua fitur
5. **Config**: Save/Load via tab Settings

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `RightShift` | Toggle UI visibility |

---

## ⚙️ Configuration

### Config System

Settings disimpan otomatis di folder workspace executor:
`workspace/99NightsOP/config.json`

---

## 🔨 Development

### Adding New Features

1. **Create Module**: Buat file baru di `Src/Features/NamaFitur.lua`
2. **Implement Logic**: `Init`, `Start`, `Stop` functions
3. **Connect UI**: Edit Tab yang sesuai di `Src/UI/Tabs/` dan hubungkan callback ke module

### Debugging

- Gunakan `Server/debug_server.py` untuk **Hot Reload**
- Cek log di console (F9) atau file log eksternal

---

## 🙏 Credits

- **Script Development**: OP Script Team
- **UI Library**: [WindUI](https://github.com/Footagesus/WindUI)

---

## ⚠️ Disclaimer

Script ini dibuat untuk tujuan edukasi. Penggunaan script exploit dalam game online dapat melanggar Terms of Service dan berisiko ban. Gunakan dengan risiko sendiri.

---

<p align="center">
  <b>99 Nights OP Script</b><br>
  Built with ❤️ using WindUI
</p>
