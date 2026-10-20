# 🚀 Advanced FiveM HUD

A modern, clean, and optimized HUD for FiveM servers.
Designed to provide all essential player information without clutter, focusing on smooth UX and performance.

---

## ✨ Features

### 🧍 Player status
* 🎤 **Microphone / voice indicator**
* ❤️ **Health** and 🛡️ **Armor** rings
* 🍔 **Hunger** and 💧 **Thirst** (real-time, smooth animations; reads `esx_status` or the framework metadata)
* ⚡ **Stamina**

### 💰 Money & job
* Cash and bank balance, updated automatically
* Current job and grade (e.g. `LSPD - Lieutenant`)
* Works with `ox_inventory`, `qs-inventory`, `qb-inventory` or the plain framework balance

### 🗺️ Minimap
* **Round minimap** with a compass ring: current heading in degrees, rotating N / E / S / W markers
* Waypoint **distance** (GPS route length)
* Optional zone and street name next to the map (`Config.Minimap.showLocation`)
* Ring colour **follows the HUD colour** you pick in `/hud`
* **Light iOS / Google Maps style map** (FlyBanditMods iOS LS Map Lite) included in `stream/`
* **ON / OFF switch in the `/hud` dashboard**: round minimap or the stock GTA minimap, applied instantly and remembered
* **Movable and resizable**: both the round and the stock GTA minimap can be placed anywhere with *HUD Layout → Edit*
* Native health / armor bars and satnav are hidden so the radar stays clean

### 🚗 Car HUD
* Speedometer in **km/h** with a speed ring
* **Fuel** level ring (supports `Entity(vehicle).state.fuel` or native fuel)
* Status icons with key hints: **engine** (`CTRL`), **doors** (`L`), **lights** (`H`)
* Shown automatically when you are in a vehicle

### 🪢 Seatbelt
* Seatbelt icon next to the engine icon
  * unbuckled: red icon fades in and blinks
  * buckled: green icon fades in and out once
* **Warning beep** while driving unbuckled (default above 10 km/h)
* Toggle with **`B`** (rebindable in the FiveM key bindings), can't leave the vehicle while buckled
* Not shown on motorcycles, bicycles, boats, helicopters and planes
* Other scripts can control it: `TriggerEvent('muda:seatbelt:set', true/false)`, `exports.muda:IsSeatbeltOn()` or `LocalPlayer.state.seatbelt`

### 🔫 Weapon HUD
* Ammo counter (current / max)
* Weapon icon by weapon name (falls back to a default icon)

### 🎛️ `/hud` dashboard
* Show or hide each element: Microphone, Thirst, Hunger, Armor, Stamina, Wallet, Bank, Job, Location, Minimap
* **Primary colour** picker, the whole HUD recolours instantly
* **HUD Layout editor**: drag to move, drag the corner or scroll to resize, Save / Cancel / Reset
* All choices are stored per player and survive restarts

### 🧠 Optimized
* Lightweight NUI
* Event-driven updates, values are only sent when they change
* Clean and readable code

---

## 📸 Preview

![HUD Preview](https://github.com/user-attachments/assets/6163d0b3-6aa7-4990-af52-0e6f9e3a3e6c)
![HUD Preview 3](https://github.com/user-attachments/assets/c7778f89-63f0-45a4-bb31-5276410391ec)
![HUD Preview 2](https://github.com/user-attachments/assets/640fc192-bec8-4202-910e-d9c7830ff66c)

---

## 📦 Installation

1. Download the repository:

```
git clone https://github.com/Harun15-Sokac/Modern-Clean-HUD
```

2. Place it in your `resources` folder

3. Add to your `server.cfg`:

```
ensure your-hud
```

4. Do a **full server restart** (the map files in `stream/` are not reliably loaded by a plain `restart`)

> Don't run FlyBanditMods iOS LS Map, `linx_minimap` or `coii_nativeui` as separate resources, the files are already included.

---

## ⚙️ Configuration

Everything is in `config.lua`:

| Option | Description |
| --- | --- |
| `Config.Framework` | `'esx'` or `'qb'` |
| `Config.Inventory` | `'ox'`, `'qs'`, `'qb'` or `'none'` |
| `Config.SettingsCommand` | Command that opens the dashboard (default `hud`) |
| `Config.AlwaysMap` | `true`: minimap always visible, `false`: only in a vehicle |
| `Config.Minimap` | Enable the round minimap, position, size, zoom, location text |
| `Config.Seatbelt` | Key, exit lock, warning sound, speed and interval |
| `Config.Enable*` | Turn individual elements on or off (health, armor, hunger, thirst, stamina, wallet, bank, job, location, voice) |

Set `Config.Minimap.enabled = false` to use only the stock GTA minimap.

---

## 🔌 Commands, exports and events

| | |
| --- | --- |
| `/hud` | Open the settings dashboard |
| `/resethud` | Re-sync all HUD values |
| `B` | Toggle seatbelt |
| `exports.muda:ShowHUD(bool)` | Show or hide the framework status display (`esx_status` / `qb-hud`) |
| `exports.muda:Notify(msg, type)` | Show a notification |
| `exports.muda:ToggleHud(bool)` | Show or hide the whole HUD |
| `exports.muda:SetMinimapVisible(bool/nil)` | Force the minimap on / off, `nil` = automatic |
| `exports.muda:RefreshMinimapLayout()` | Re-measure the minimap position |
| `exports.muda:IsSeatbeltOn()` | `true` if the player is buckled |
| `exports.muda:SetCustomMinimap(bool)` | Switch between the round and the stock minimap |

(Replace `muda` with the folder name of the resource.)

---

## 📁 Structure

```
├── fxmanifest.lua
├── config.lua
├── client/     main.lua, minimap.lua, seatbelt.lua
├── shared/     bridge.lua (framework bridge)
├── web/        index.html, css/, js/, images/, weapons/
├── assets/     radar-mask.png
└── stream/     map files
```

---

## 🔗 Dependencies

* ESX
* QBOX
* QB

---

## 🛠️ Customization

* Fully modular structure
* Easy to enable/disable components
* Fully editable UI (HTML/CSS)

---

## 🧪 Status

⚠️ **NOTE:**
This script is currently in **testing phase**.

If you find any bugs or issues, feel free to contact me on Discord.

---

## 💬 Support

For support or custom requests:

👉 Discord: `Harun15_`

---

## 🙏 Credits

* Round minimap and compass design based on [coii_nativeui](https://github.com/coiiq/coii_nativeui) (COII)
* Map style: FlyBanditMods iOS LS Map (Lite) by TheFlyBandit

---

## 📜 License

Free to use and modify.
Credits are appreciated ❤️
