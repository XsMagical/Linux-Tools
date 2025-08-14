# 🎮 Team Nocturnal — Universal Gaming Setup (Linux)
**By [XsMagical](https://github.com/XsMagical)**

A universal, native-first Linux gaming setup script designed for newcomers from Windows or Mac.
Installs essential gaming tools with minimal hassle and includes smart defaults — without breaking system apps.

---

## ⚠️ Heads-up: if `wget` isn’t installed

Some fresh installs don’t include `wget`. If the commands below fail with “wget: command not found”, install it first:

**Fedora / RHEL (dnf or dnf5)**
```bash
sudo dnf install -y wget    # or: sudo dnf5 install -y wget
```

**Ubuntu / Debian**
```bash
sudo apt-get update && sudo apt-get install -y wget
```

**Arch**
```bash
sudo pacman -Sy --needed wget
```

**openSUSE**
```bash
sudo zypper install -y wget
```

---

## 📥 One-Time Install

```bash
# Create scripts folder & download the latest gaming setup script
mkdir -p ~/scripts
cd ~/scripts
wget -O universal_gaming_setup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh
chmod +x universal_gaming_setup.sh
```

```bash
# Example usage (choose a bundle from the table below)
./universal_gaming_setup.sh --bundle=full -y
```

---

## 🔄 Update Script

```bash
cd ~/scripts
wget -O universal_gaming_setup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh
chmod +x universal_gaming_setup.sh
```
---

## 📦 Install Bundles

| Bundle | Description | Command |
|--------|-------------|---------|
| **Lite** | Core tools only | `./universal_gaming_setup.sh --bundle=lite -y` |
| **Normal** | Core + Steam, Lutris, Heroic, Discord, Proton tools | `./universal_gaming_setup.sh --bundle=normal -y` |
| **Full** | Everything in Normal **plus** OBS, GOverlay, Gamescope, v4l2loopback | `./universal_gaming_setup.sh --bundle=full -y` |

---

## 📦 What It Installs

- **Core tools:** MangoHud, GameMode, Vulkan tools, Wine, Winetricks, Protontricks
- **Launchers:** Steam (native-first), Lutris, Heroic Games Launcher
- **Proton Tools:** ProtonPlus (Fedora COPR), ProtonUp-Qt (Flatpak fallback)
- **Comms:** Discord
- **Extras (Full bundle):** OBS Studio, GOverlay, Gamescope, v4l2loopback

Uses native-first logic with Flatpak fallback when needed — keeps your system clean.

---

## ⚙ Optional Flags

```text
-y, --yes               Auto-confirm installations
-v, --verbose           Verbose installation logs
--native-only           Force native package installs
--flatpak-only          Force Flatpak installs
--keep-flatpak          Keep Flatpak versions even if native exists
--no-clean              Skip cleanup of duplicate packages

# Skip specific apps:
--no-steam
--no-lutris
--no-heroic
--no-discord
--no-protonplus
--no-protonupqt
--no-protontricks
```

**Examples:**
```bash
# Full bundle, native-only, verbose
./universal_gaming_setup.sh --bundle=full --native-only --verbose -y
```

```bash
# Flatpak-only setup, skip Discord
./universal_gaming_setup.sh --flatpak-only --no-discord -y
```

---

## 💻 Supported Distros

- Fedora / RHEL (Auto-config RPM Fusion & COPR)
- Debian / Ubuntu
- Arch-based distros
- openSUSE (partial support)
- ARM devices supported (Steam is auto-skipped)

---

## 🔄 Safe to Re-Run

- Skips already installed tools
- Creates MangoHud config only if missing
- Removes duplicate Flatpaks unless `--keep-flatpak` is used

---

## 🛠 Troubleshooting

**Steam doesn’t launch or crashes on start?**
```bash
rm -rf ~/.steam ~/.local/share/Steam
./universal_gaming_setup.sh --bundle=normal --native-only -y
```

**Flatpak & native versions are conflicting?**
```bash
flatpak uninstall --unused
sudo dnf remove steam  # (or apt/pacman/zypper equivalent)
```

**Proton tools missing in Steam?**
```bash
./universal_gaming_setup.sh --no-steam --protonplus --protonupqt -y
```

**Discord not launching voice correctly?**
```bash
flatpak uninstall com.discordapp.Discord
./universal_gaming_setup.sh --discord=native -y
```

---

## 🔄 Enable per game overlay in Steam launcher options

```bash
MANGOHUD=1 ENABLE_VKBASALT=0 %command%
```

---


## 🔗 Links & License

- [GitHub Repository](https://github.com/XsMagical/Linux-Tools)
- [Team Nocturnal](https://team-nocturnal.com)
- Licensed under **MIT**

# Universal Gaming Setup — README

Team Nocturnal • Linux-Tools — `scripts/gaming/universal_gaming_setup.sh`

> Cross‑distro gaming bootstrap with bundle presets. Defaults to **native packages** whenever possible (Discord native-first with Flatpak fallback). Includes an end‑of‑run ✅/❌ status report for every app.

---

## Contents
- [Supported Distros](#supported-distros)
- [Bundles](#bundles)
- [What Each App Does](#what-each-app-does)
- [Flags](#flags)
- [Examples](#examples)
- [How Status ✅/❌ Works](#how-status--works)
- [Troubleshooting](#troubleshooting)
- [Notes](#notes)

---

## Supported Distros

- **Fedora / RHEL family** (dnf/dnf5; enables RPM Fusion assumed)
- **Ubuntu / Debian family** (apt; enables i386 where needed)
- **Arch / Manjaro** (pacman)

> ARM devices: Steam is skipped automatically.

---

## Bundles

Choose one with `--bundle=<name>`. Alias: `--bundle=gaming` = `normal`.

| Bundle  | Installed Components |
|--------:|-----------------------|
| **lite** | Core tools only → Wine, Winetricks, Vulkan tools, MangoHud, GameMode |
| **normal** | **lite** + Steam, Lutris, Heroic, Discord, Proton tools (ProtonPlus on Fedora + ProtonUp‑Qt via Flatpak) |
| **full** | **normal** + OBS Studio, GOverlay, Gamescope, v4l2loopback |

> Native is preferred for everything (rpm/deb/pacman). If a native package isn’t available or fails after a quick repo refresh, the script falls back to Flatpak for specific apps (Heroic, OBS, Lutris, ProtonUp‑Qt, Discord).

---

## What Each App Does

- **Wine / Winetricks** — Windows compatibility and helpers.
- **Vulkan tools** — Vulkan verification utilities (`vulkaninfo`/`vkcube`).
- **MangoHud** — In‑game overlay (FPS/frametime/temps/etc.).
- **GameMode** — Runtime performance tuning (`gamemoderun`).
- **Steam** — Native Steam client (i386 arch enabled where needed).
- **Lutris** — Game launcher/runner (native preferred, Flatpak fallback).
- **Heroic** — Epic/GOG launcher (native preferred where reliable; Flatpak fallback).
- **ProtonPlus** (Fedora COPR) — Proton/Wine management.
- **ProtonUp‑Qt** (Flatpak) — Install and manage Proton‑GE/GE‑Wine.
- **Discord** — **Native‑first**; if mirrors fail or not available, falls back to Flatpak.
- **OBS Studio** — Recording/streaming (native preferred, Flatpak fallback).
- **GOverlay** — GUI for MangoHud/Gamescope parms (Flatpak preferred for consistency).
- **Gamescope** — Micro‑compositor for game sessions.
- **v4l2loopback** — Virtual webcam kernel module (akmod/dkms where appropriate).

---


## Examples

```bash
# Core only
./universal_gaming_setup.sh --bundle=lite -y

# Workhorse stack
./universal_gaming_setup.sh --bundle=normal -y

# Everything (adds OBS, GOverlay, Gamescope, v4l2loopback)
./universal_gaming_setup.sh --bundle=full -y

# Force Discord to Flatpak (overrides native-first)
./universal_gaming_setup.sh --bundle=normal --discord=flatpak -y
```

---

## How Status ✅/❌ Works

At the end of a run, the script prints a summary for **every component** it manages.  
Detection rules prefer **native** checks; when applicable it reports **Flatpak** instead.

- Native checks: commands exist (e.g., `steam`, `mangohud`, `heroic`, `obs`) **or** package presence (e.g., `rpm -q discord`).
- Flatpak checks: `flatpak list --app --columns=application` for known app IDs, e.g.:
  - `com.discordapp.Discord`
  - `net.davidotek.pupgui2` (ProtonUp-Qt)
  - `com.heroicgameslauncher.hgl`
  - `com.obsproject.Studio`
  - `net.lutris.Lutris`
  - `com.github.gicmo.goverlay`
  - `org.freedesktop.Platform.VulkanLayer.MangoHud`

---

## Troubleshooting

### “Discord native failed with 404s” (Fedora/RPM Fusion)
Mirrors rotate. The script already performs a **quick repo refresh** and retries once. If you’re doing it manually:

```bash
sudo dnf clean metadata && sudo dnf clean all
sudo dnf --refresh makecache
sudo dnf --refresh install -y discord
```

### Heroic says “already installed” but script didn’t detect it
Detection looks for **native** first (`heroic`), then the Flatpak ID `com.heroicgameslauncher.hgl`. If you installed to a different Flatpak remote or user scope only, ensure `flathub` is configured or install the ID shown above.

### Steam skipped on ARM
Intended. Steam x86 deps aren’t available on ARM in most distros.

---

## Notes

- The script refreshes package metadata (no full distro upgrades) to avoid stale mirror errors.
- Native > Flatpak: if a native app installs successfully, a Flatpak duplicate is removed to avoid duplicates in menus.
- Steam logic is left unchanged from the known-good baseline.
- Repo: https://github.com/XsMagical/Linux-Tools

## 🔄 Update Script

```bash
cd ~/scripts
wget -O universal_gaming_setup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh
chmod +x universal_gaming_setup.sh
```

---

## 🔗 Links & License

- [GitHub Repository](https://github.com/XsMagical/Linux-Tools)
- [Team Nocturnal](https://team-nocturnal.com)
- Licensed under **MIT**
