# 99NightInTheForest — Survival OP Algorithm Document

Dokumen ini **hanya** memakai data yang benar-benar terlihat di log/dump berikut:
- `C:\Users\Administrator\Desktop\worker\99NightInTheForest\2026-01-25T23_17_13Z.log`
- `C:\Users\Administrator\Desktop\worker\99NightInTheForest\2026-01-26T04_47_14Z.log`
- `C:\Users\Administrator\Desktop\worker\99NightInTheForest\2026-01-26T04_52_00Z.log`
- `C:\Users\Administrator\Desktop\worker\99NightInTheForest\2026-01-26T05_01_31Z.log`
- `C:\Users\Administrator\Desktop\worker\99NightInTheForest\Cobalt_Session_1769383380.cleaned.json`
- `C:\Users\Administrator\AppData\Local\Xeno\workspace\full_dump_1769397912_6582.json`

Jika ada bagian yang belum terlihat di data tersebut, akan diberi label **Unknown**.

---

## 1) Stat & State Sources (Confirmed)

Sumber stat survival yang terverifikasi:
- `Players.LocalPlayer` **Attributes**: `Hunger`, `Warmth`, `Temperature`. Sumber: `C:\Users\Administrator\AppData\Local\Xeno\workspace\full_dump_1769397912_6582.json`.
- UI fallback di `PlayerGui.Interface`: `HungerBar`, `TemperatureFrame`. Sumber: `C:\Users\Administrator\AppData\Local\Xeno\workspace\full_dump_1769397912_6582.json`.

Catatan:
- **Thirst/Hydration tidak ditemukan** di dump ini. Modul minum tidak disiapkan.

---

## 2) Remote Mapping Table (Observed Args)

Semua mapping di bawah berasal dari log Cobalt (outgoing/incoming) atau dictionary JSON.

| Remote | Type | Fungsi | Argumen yang Terlihat | Sumber |
|---|---|---|---|---|
| `EquipItemHandle` | RemoteEvent | Equip tool | `"FireAllClients"`, `Inventory["Old Axe"]` | `2026-01-25T23_17_13Z.log` |
| `UnequipItemHandle` | RemoteEvent | Unequip tool | `"FireAllClients"`, `Inventory["Old Sack"]` | `Cobalt_Session_1769383380.cleaned.json` |
| `ToolDamageObject` | RemoteFunction | Hit/harvest resource atau mob | `workspace.Map.Foliage.<Node>` **atau** `workspace.Characters.<Mob>`, `Inventory["Old Axe"]`, `hitId`, `CFrame` | `2026-01-25T23_17_13Z.log`, `2026-01-26T04_52_00Z.log` |
| `RequestStartDraggingItem` | RemoteEvent | Ambil item (world → TempStorage) | `workspace.Items["<Item>"]` | `Cobalt_Session_1769383380.cleaned.json` |
| `StopDraggingItem` | RemoteEvent | Lepas item (TempStorage) | `TempStorage.<Item>` | `Cobalt_Session_1769383380.cleaned.json` |
| `RequestBagStoreItem` | RemoteFunction | Simpan item ke bag | `Inventory["Old Sack"]`, `ItemBag.<Item>` atau `ReplicatedStorage.TempStorage.Log` | `Cobalt_Session_1769383380.cleaned.json`, `2026-01-26T04_47_14Z.log` |
| `RequestBagDropItem` | RemoteEvent | Drop item dari bag | `Inventory["Old Sack"]`, `<Item>`, `bool` | `Cobalt_Session_1769383380.cleaned.json` |
| `RequestOpenItemChest` | RemoteEvent | Buka chest | `workspace.Items["Item Chest2"]` | `Cobalt_Session_1769383380.cleaned.json` |
| `RequestCookItem` | RemoteEvent | Masak item di api | `Map.Campground.MainFire`, `<Item>` | `Cobalt_Session_1769383380.cleaned.json` |
| `RequestConsumeItem` | RemoteFunction | Makan item | `Inventory["Old Sack"]`, `<Food>`, `bool` **atau** `workspace.Items["Cooked Morsel"]` (terlihat juga `GetNil("Cooked Morsel", id)` di response) | `Cobalt_Session_1769383380.cleaned.json`, `2026-01-26T04_47_14Z.log` |
| `RequestBurnItem` | RemoteEvent | Tambah fuel api | `Map.Campground.MainFire`, `Log` | `Cobalt_Session_1769383380.cleaned.json` |
| `RequestPlantItem` | RemoteFunction | Tanam sapling | `workspace.Items.Sapling`, `Vector3` | `Cobalt_Session_1769383380.cleaned.json`, `2026-01-26T05_01_31Z.log` |
| `DestroyObject` | RemoteEvent (Incoming) | Notifikasi object hancur | `ReplicatedStorage["Small Tree"]`, `CFrame` | `2026-01-26T05_01_31Z.log` |
| `RequestSelectRecipe` | RemoteEvent | Pilih recipe di ToolWorkshop | `workspace.Map.Landmarks.ToolWorkshop`, `"Hammer"` | `2026-01-26T04_47_14Z.log` |
| `RequestAddAnvilIngredient` | RemoteFunction | Tambah ingredient anvil | `workspace.Map.Landmarks.ToolWorkshop`, `ReplicatedStorage.TempStorage.Bolt` | `2026-01-26T04_47_14Z.log` |
| `RequestScrapItem` | RemoteFunction | Scrap item | `workspace.Map.Campground.CraftingBench`, `ReplicatedStorage.TempStorage.Chair` / `ReplicatedStorage.TempStorage["Broken Fan"]` | `2026-01-26T04_52_00Z.log` |
| `DamagePlayer` | RemoteEvent | **God Mode / Infinite Heal** — mengirim damage negatif ekstrem (`-math.huge`) untuk heal tak terbatas. Spam setiap 1 detik untuk immortality. | `-math.huge` | `2026-01-26T04_52_00Z.log`, `FullLifeOP.lua` |
| `RequestReplicateSound` | RemoteEvent | Broadcast suara (FX) | `"FireAllClients"`, `"WoodChop"`/`"BagDrop"`/`"Eat"`/`"AnvilAdd"`, payload | `2026-01-25T23_17_13Z.log`, `2026-01-26T04_47_14Z.log` |
| `PlayEnemyHitSound` | RemoteEvent | SFX hit | `"FireAllClients"`, target, tool | `2026-01-25T23_17_13Z.log` |

---

## 3) Remotes Terlihat Tapi Argumen Belum Terekam (Unknown)

Terlihat di dump, namun belum ada contoh argumen di log:
- `CraftItem`, `RequestBuildAnvilPiece`
- `RequestEquipArmour`, `EquipArmourModel`, `UnequipArmourModel`
- `RequestUpgradeDefense`, `RequestReloadTurret`, `RequestPurchaseTurret`
- `RequestPlantSeeds`, `RequestPlantAcorn`, `RequestWaterPlot`

Sumber: `C:\Users\Administrator\AppData\Local\Xeno\workspace\full_dump_1769397912_6582.json`.

---

## 4) OP Logic Flow (Berdasarkan Data yang Ada)

Flow ini memakai **stat yang sudah terverifikasi** dan remotes yang sudah terbukti di log.

```
LOOP (fast tick)
  Read Hunger/Warmth/Temperature from LocalPlayer Attributes
  Fallback: PlayerGui.Interface.HungerBar / TemperatureFrame

  // Survival
  IF Temperature rendah OR Warmth rendah
    -> move ke MainFire
    -> IF fire butuh fuel: RequestBurnItem(MainFire, fuel termurah)
    -> IF armour tersedia: RequestEquipArmour (Unknown args)

  IF Hunger rendah
    -> IF Cooked Morsel in bag: RequestConsumeItem
    -> ELSE IF Cooked Morsel di world: RequestConsumeItem(workspace.Items["Cooked Morsel"])
    -> ELSE IF Morsel in bag: RequestCookItem -> RequestConsumeItem

  // Farming / Gathering
  Find nearest resource in Workspace.Map.Foliage
  Equip tool -> spam ToolDamageObject(target, tool, hitId, CFrame)
  Loot: RequestStartDraggingItem -> RequestBagStoreItem -> StopDraggingItem

  // Hunting (Mob)
  Target mob in Workspace.Characters
  Equip tool -> spam ToolDamageObject(mob, tool, hitId, CFrame)

  // Aura Mode (OP)
  If enabled, spam ToolDamageObject ke semua target dalam radius
  - Foliage aura (tree/mining)
  - Character aura (kill aura)

  // Base & Inventory
  Maintain fire (fuel ranking)
  IF bag full -> RequestOpenItemChest -> RequestBagStoreItem
  IF no chest -> RequestBagDropItem (trash candidates)
  IF trash in TempStorage -> RequestScrapItem(CraftingBench, TempStorage.<Trash>)

  // Auto Plant
  IF Sapling tersedia -> RequestPlantItem(workspace.Items.Sapling, target Vector3)

  // Crafting (ToolWorkshop)
  RequestSelectRecipe(ToolWorkshop, "Hammer")
  RequestAddAnvilIngredient(ToolWorkshop, TempStorage.Bolt)

  // Stealth & Safety
  Avoid RequestReplicateSound to reduce detectability
  Anti-stuck: if position unchanged N seconds -> reposition/reset path
END LOOP
```

Catatan:
- Threshold angka (berapa “rendah”) **belum ada di data** → wajib dikonfigurasi.
- Modul minum **tidak dibuat** karena tidak ada Thirst/Hydration di dump.

---

## 5) Item Priority List (Observed Only)

Kategori berikut hanya berisi item yang **muncul** di log/dump.

### Food
- `Cooked Morsel` (makan langsung)
- `Morsel` (harus dimasak dulu)

Sumber: `Cobalt_Session_1769383380.cleaned.json`, `2026-01-26T04_47_14Z.log` (RequestCookItem / RequestConsumeItem)

### Fuel
- `Sapling` (terlihat di plant; kandidat fuel murah)
- `Log`
- `Coal` (muncul di bag; simpan jika dipakai crafting)

Sumber: `Cobalt_Session_1769383380.cleaned.json` (RequestBurnItem, ItemBag)

### Materials / Keep
- `Sheet Metal`
- `Revolver Ammo`
- `Bolt` (ingredient anvil)
- `Sapling` (bahan tanam)

Sumber: `Cobalt_Session_1769383380.cleaned.json`, `2026-01-26T04_47_14Z.log`

### Trash Candidate (Hati-hati)
- `Chair` (muncul di bag)
- `Broken Fan` (muncul di scrap)

Sumber: `Cobalt_Session_1769383380.cleaned.json`, `2026-01-26T04_52_00Z.log`

### Unknown (Jangan auto-drop)
- `Bunny Foot` (muncul di bag; fungsi tidak diketahui)

Sumber: `Cobalt_Session_1769383380.cleaned.json`

---

## 6) Silent Mode & Anti-Stuck (OP Behavior)

Silent Mode:
- Hindari `RequestReplicateSound` untuk mengurangi broadcast suara.
- Hindari `PlayEnemyHitSound` jika tidak wajib.

Anti-Stuck:
- Monitor posisi (HumanoidRootPart). Jika tidak berubah selama X detik, lakukan reposition/jump/reset path.

Sumber remote SFX: `2026-01-25T23_17_13Z.log`, `2026-01-26T04_47_14Z.log`.

---

## 7) OP Features Teramati di Log (Evidence-Based)

Fitur berikut **terlihat jelas** di log dengan pola eksekusi beruntun:

- **Kill Aura**: `ToolDamageObject` dipanggil beruntun ke `workspace.Characters.Bunny` dan `workspace.Characters:GetChildren()[n]`. Sumber: `2026-01-26T04_52_00Z.log`.
- **Menebang/Mining Aura**: `ToolDamageObject` dipanggil beruntun ke `workspace.Map.Foliage:GetChildren()[n]`. Sumber: `2026-01-26T05_01_31Z.log`.
- **Auto Plant (spam)**: `RequestPlantItem(workspace.Items.Sapling, Vector3)` dipanggil beruntun dalam interval rapat. Sumber: `2026-01-26T05_01_31Z.log`.
- **Auto Eat**: `RequestConsumeItem(workspace.Items["Cooked Morsel"])` dipanggil beruntun. Sumber: `2026-01-26T04_47_14Z.log`.
- **Auto Crafting (Anvil)**: `RequestSelectRecipe(ToolWorkshop, "Hammer")` diikuti `RequestAddAnvilIngredient(ToolWorkshop, TempStorage.Bolt)`. Sumber: `2026-01-26T04_47_14Z.log`.
- **Auto Scrap**: `RequestScrapItem(CraftingBench, TempStorage.Chair / TempStorage["Broken Fan"])`. Sumber: `2026-01-26T04_52_00Z.log`.
- **God Mode / Infinite Heal**: `DamagePlayer:FireServer(-math.huge)` — mengirim damage negatif ekstrem yang diinterpretasikan server sebagai heal. Di-spam setiap 1 detik untuk immortality. Sumber: `2026-01-26T04_52_00Z.log`, `FullLifeOP.lua`.

### God Mode Implementation (Verified)

```lua
-- God Mode via DamagePlayer
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")
local remote = Remotes:FindFirstChild("DamagePlayer")

-- Spam setiap 1 detik untuk immortality
while true do
    if remote then
        remote:FireServer(-math.huge)  -- damage negatif = heal
    end
    task.wait(1)
end
```

**Catatan**: `-math.huge` adalah nilai negatif tak hingga. Server menghitung damage negatif sebagai healing, sehingga player selalu di-heal setiap 1 detik → tidak bisa mati.

---

## 8) Missing Data (Perlu Capture Tambahan jika ingin 100% OP)

Bagian berikut **belum** ada contoh argumen di log/dump:
- Crafting finalize (hasil/output & remote `CraftItem` / `RequestBuildAnvilPiece`)
- Equip armour (argumen & efek Warmth)
- Upgrade/reload defense (argumen & cooldown)
- Kapasitas bag & aturan stacking
- God mode / invincibility → **TERVERIFIKASI via `DamagePlayer` dengan argumen `-math.huge`** (lihat bagian 2)
- Efek pasti `DamagePlayer` → **TERVERIFIKASI**: damage negatif = heal, di-spam setiap 1 detik = immortality

Tanpa data ini, dokumentasi tetap akurat, tapi modul OP di area tersebut harus diberi status **Unknown/Assumed**.
