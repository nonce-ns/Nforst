# Cobalt Log Cleaner v3.0

Tool untuk membersihkan Cobalt executor logs (`.log` format) menjadi single-line Lua code yang readable.

## Keuntungan .log vs .html

| | .html | .log |
|---|-------|------|
| **Full Path** | ❌ `--[[Nil Parent]]` | ✅ `workspace.Map.Foliage["Small Tree"]` |
| **Arguments** | ✅ | ✅ |
| **Single Line** | ✅ | ✅ |
| **AI Readable** | ✅ | ✅ |

**Kesimpulan: Pakai .log lebih baik!**

## Usage

1. Letakkan file `.log` di folder `input/`
2. Run `python cleaner.py`
3. Pilih option:
   - `1` - Process latest log
   - `2` - Process all logs
   - `3` - Select from list
4. Hasil ada di folder `output/`

## Output Format

**Input (raw log):**
```
2026-01-30T18:21:360.547Z,17.699379,Outgoing:ToolDamageObject,INFO Instance: ToolDamageObject
    Path: game:GetService("ReplicatedStorage").RemoteEvents.ToolDamageObject
    -------------------- Generated Code --------------------
    local Event = game:GetService("ReplicatedStorage").RemoteEvents.ToolDamageObject
    Event:InvokeServer(
        workspace.Map.Foliage["Small Tree"],
        game:GetService("Players").LocalPlayer.Inventory["Old Axe"],
        "1_8401342884",
        CFrame.new(...)
    )
```

**Output (clean):**
```lua
game:GetService("ReplicatedStorage").RemoteEvents.ToolDamageObject:InvokeServer(workspace.Map.Foliage["Small Tree"], game:GetService("Players").LocalPlayer.Inventory["Old Axe"], "1_8401342884", CFrame.new(-45.880420684814, 3.9341990947723, ...))
```

## Filtered Remotes

Remotes ini di-skip (terlalu spammy):
- `Logger`
- `EquipItemHandle`
- `UnequipItemHandle`
- `RequestReplicateSound`
- `PlayEnemyHitSound`

## Changelog

### v3.0
- Single-line output format
- Skip Incoming events (only process Outgoing)
- Deduplication
- Clean formatting

### v2.0
- Full generated code extraction
- Multi-line format

### v1.0
- Basic event extraction
- Timestamp + remote name only
