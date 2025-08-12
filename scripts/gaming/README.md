# 🎮 Team Nocturnal — Universal Gaming Setup (Linux)
**By [XsMagical](https://github.com/XsMagical)**  

A universal, native-first Linux gaming setup script designed for newcomers from Windows or Mac.  
Installs essential gaming tools with minimal hassle and includes smart defaults for overlays — without breaking system apps.  

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

## 📦 Install Bundles

| Bundle | Description | Command |
|--------|-------------|---------|
| **Lite** | Core tools only | `./universal_gaming_setup.sh --bundle=lite -y` |
| **Normal** | Core + Steam, Lutris, Heroic, Discord, Proton tools | `./universal_gaming_setup.sh --bundle=normal -y` |
| **Full** | Everything in Normal **plus** OBS, GOverlay, Gamescope, v4l2loopback | `./universal_gaming_setup.sh --bundle=full -y` |

---

## 📦 What It Installs

- **Core tools:** MangoHud, GameMode, Vulkan tools, Wine, Winetricks, Protontricks  
- **Launchers:** Steam, Lutris, Heroic Games Launcher  
- **Proton Tools:** ProtonPlus (Fedora COPR), ProtonUp-Qt (Flatpak fallback)  
- **Comms:** Discord  
- **Extras (Full bundle):** OBS Studio, GOverlay, Gamescope, v4l2loopback  

Uses native-first logic with Flatpak fallback when needed — keeps your system clean.  

---

## 🎯 Overlay Control (Per-Game via Steam)

Overlays are now **strictly per-game** to avoid conflicts with non-gaming apps like OBS.  

**Enable overlays for games (Steam only):**
```bash
./universal_gaming_setup.sh --overlays=games --overlay-only
```

**Disable overlays entirely:**
```bash
./universal_gaming_setup.sh --overlays=none --overlay-only
```

**Check current overlay status:**
```bash
./universal_gaming_setup.sh --overlays=status --overlay-only
```

---

## ⚙ Optional Flags

```text
-y, --yes               Auto-confirm installations
-v, --verbose           Verbose installation logs
--native-only           Force native package installs
--flatpak-only          Force flatpak installs
--keep-flatpak          Keep flatpak versions even if native exists
--no-clean              Skip cleanup of duplicates

# Skip specific parts:
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

**Overlay appears in non-games?**
```bash
./universal_gaming_setup.sh --overlays=none --overlay-only
exec bash -l
```

**Steam launcher not showing "(TN Overlays)"?**
```bash
./universal_gaming_setup.sh --overlays=games --overlay-only
```

---

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
