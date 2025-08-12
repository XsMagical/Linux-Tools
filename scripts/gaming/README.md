# 🎮 Team Nocturnal — Universal Gaming Setup Script
**by [XsMagical](https://github.com/XsMagical)**  

---

## 📌 Overview
The **Universal Gaming Setup Script** is a **one-command, cross-distro installer** that sets up a complete Linux gaming environment with **native packages prioritized over Flatpak**, optional per-game overlays, and all the essential tools to game comfortably on Linux.  

Built for:
- **New users** — who just want everything gaming-related installed & working without learning multiple package managers.
- **Experienced users** — who want a clean, repeatable setup across multiple systems.

This script is **safe to re-run** — it will skip already-installed packages, re-install missing ones, and remove duplicate Flatpak/native installs for a cleaner system.

---

## 🛠 Features
- **Cross-distro support** — Works on Fedora/RHEL, Ubuntu/Debian, and Arch-based systems.
- **Native-first installs** — Prefers repo packages over Flatpaks, removing duplicates where possible.
- **Gaming essentials**:
  - Steam (with Proton support)
  - Lutris
  - Heroic Games Launcher
  - MangoHud + vkBasalt (performance overlays)
  - GameMode
  - Wine & DXVK/Vulkan tools
  - OBS Studio (Full mode only)
  - Discord, ProtonPlus, ProtonUp-Qt
- **Overlay management**:
  - No more global env variables breaking non-game apps
  - Per-game Steam wrapper toggle (\`--overlays=games\` / \`--overlays=none\`)
  - Status check for current overlay mode
- **Proton tools**:
  - ProtonPlus (native COPR/DNF install where supported)
  - ProtonUp-Qt (Flatpak fallback)
- **Safe duplicate cleanup** — Removes Flatpak if native installed (and vice versa).

---

## 🚀 Installation & Usage

### 1️⃣ Download the Script
\`\`\`bash
wget -O ~/scripts/universal_gaming_setup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh
chmod +x ~/scripts/universal_gaming_setup.sh
\`\`\`

---

### 2️⃣ Basic Gaming Install
\`\`\`bash
~/scripts/universal_gaming_setup.sh
\`\`\`

---

### 3️⃣ Full Gaming Setup (includes OBS, streaming tools, extras)
\`\`\`bash
~/scripts/universal_gaming_setup.sh full
\`\`\`

---

### 4️⃣ Overlay Control (Games Only)
No more overlays in system apps like HandBrake — overlays only appear when games are launched from Steam.

**Disable per-game overlays:**
\`\`\`bash
~/scripts/universal_gaming_setup.sh --overlays=none --overlay-only
\`\`\`

**Enable per-game overlays:**
\`\`\`bash
~/scripts/universal_gaming_setup.sh --overlays=games --overlay-only
\`\`\`

**Check current overlay status:**
\`\`\`bash
~/scripts/universal_gaming_setup.sh --overlays=status --overlay-only
\`\`\`

---

## 📂 Flags & Options

| Option | Description |
|--------|-------------|
| \`full\` | Installs full gaming suite including OBS Studio & streaming tools |
| \`--overlay-only\` | Runs only the overlay configuration logic |
| \`--overlays=games\` | Enables overlays for Steam-launched games only |
| \`--overlays=none\` | Disables all overlays |
| \`--overlays=status\` | Shows overlay mode & wrapper status |

---

## 💡 Why Per-Game Overlays?
Global overlays set via environment variables (\`MANGOHUD=1\` etc.) can **break non-gaming apps** like video editors or encoders.  
Our script keeps overlays **enabled only for games**, giving you:
- Clean system performance
- No crashes in non-game apps
- Still full overlay functionality in Steam titles

---

## 👤 Who Should Use This?
- **Linux gamers** who want everything configured without spending hours researching.
- **Streamers** who want OBS and gaming tools in one run.
- **Multi-distro users** who need the same setup on Fedora, Ubuntu, or Arch.
- Anyone tired of **duplicate Flatpak/native installs**.

---

## 🔄 Re-running the Script
It’s safe to run again:
- Skips already-installed packages
- Reinstalls missing ones
- Cleans duplicates
- Keeps your configs intact

---

## 📜 License
This project is open-source under the [MIT License](https://opensource.org/licenses/MIT).  

---

## 🔗 Links
- [GitHub Repo](https://github.com/XsMagical/Linux-Tools)
- [Team Nocturnal](https://team-nocturnal.com)
