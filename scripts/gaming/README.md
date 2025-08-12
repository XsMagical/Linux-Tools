# 🎮 Team Nocturnal — Universal Gaming Setup (Linux)
**by [XsMagical](https://github.com/XsMagical)**

A universal, native-first Linux gaming setup script with optional Flatpak fallbacks and overlays. Built for both newcomers and advanced users. Keep it clean, fast, and focused — no bloat.

---

## ⚡ Quick Start

**Download & setup**
```bash
mkdir -p ~/scripts
wget -O ~/scripts/universal_gaming_setup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh
chmod +x ~/scripts/universal_gaming_setup.sh
```

---

## 🧰 What it Installs

- **Core (all bundles):**
  - Vulkan tools
  - Wine + Winetricks
  - Protontricks
  - MangoHud + GameMode
- **Launchers (normal/full):**
  - Steam, Lutris, Heroic
- **Proton Tools:**
  - ProtonPlus (Fedora COPR)
  - ProtonUp-Qt (Flatpak fallback)
- **Comms:**
  - Discord (native preferred)
- **Extras (full only):**
  - OBS Studio
  - GOverlay
  - Gamescope
  - v4l2loopback kernel module

**Smart defaults:** Native-first logic. Flatpaks used only as fallback or when forced. Cleans duplicate apps unless told not to.

---

## 🧩 Install Types

### ✅ Lite
```bash
~/scripts/universal_gaming_setup.sh --bundle=lite -y
```
Installs only core tools (Wine, MangoHud, GameMode, Protontricks).

---

### ✅ Normal (default)
```bash
~/scripts/universal_gaming_setup.sh -y
```
Installs core tools, Steam, Lutris, Heroic, Discord, ProtonPlus.

---

### ✅ Full
```bash
~/scripts/universal_gaming_setup.sh --bundle=full -y
```
Everything in **Normal**, plus OBS Studio, Gamescope, GOverlay, v4l2loopback.

---

## 🎛️ Overlay Toggle (Steam-only, per-game)

Enable:
```bash
~/scripts/universal_gaming_setup.sh --overlays=games --overlay-only
```

Disable:
```bash
~/scripts/universal_gaming_setup.sh --overlays=none --overlay-only
```

Check:
```bash
~/scripts/universal_gaming_setup.sh --overlays=status --overlay-only
```

> Adds or removes a Steam launcher wrapper (`steam_with_overlays.sh`)  
> Prevents `MANGOHUD=1` leaks into non-gaming apps (like OBS, HandBrake)

---

## 🛠️ Optional Flags

```text
-y, --yes                 Auto-accept prompts
-v, --verbose             Show all output
--native-only             Force native install only
--flatpak-only            Force Flatpak install only
--keep-flatpak            Don’t remove duplicate Flatpaks
--no-clean                Don’t clean after setup

# Component toggles:
--no-steam                Skip Steam
--no-lutris               Skip Lutris
--no-heroic               Skip Heroic
--no-discord              Skip Discord
--no-protonplus           Skip ProtonPlus
--no-protonupqt           Skip ProtonUp-Qt
--no-protontricks         Skip Protontricks
```

**Examples**
```bash
# Full bundle, native-only, verbose
~/scripts/universal_gaming_setup.sh --bundle=full --native-only -v -y

# Flatpak-only, skip Discord
~/scripts/universal_gaming_setup.sh --flatpak-only --no-discord -y
```

---

## 🐧 Supported Distros

- Fedora/RHEL (auto-configures RPM Fusion & COPR)
- Debian/Ubuntu
- Arch-based
- openSUSE (partial support)
- ARM systems supported (Steam auto-skipped)

---

## 🔁 Safe to Re-Run

- Automatically skips already-installed tools
- MangoHud config only created if missing
- Duplicates removed only if `--keep-flatpak` isn’t used

---

## ❓ Troubleshooting

Overlay showing up in non-games?
```bash
~/scripts/universal_gaming_setup.sh --overlays=none --overlay-only
exec bash -l
```

Steam “(TN Overlays)” entry not appearing?
```bash
~/scripts/universal_gaming_setup.sh --overlays=games --overlay-only
```

---

## 🔗 Links

- GitHub: [XsMagical/Linux-Tools](https://github.com/XsMagical/Linux-Tools)
- Team Nocturnal: [team-nocturnal.com](https://team-nocturnal.com)

---

## 📜 License

MIT
