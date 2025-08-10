# 🎮 Team Nocturnal — Universal Gaming Setup (Linux)

This folder contains **`universal_gaming_setup.sh`**, a cross-distro script that sets up a complete Linux gaming environment with **one simple run**.

- **Who it’s for**
  - **New users:** No need to learn package managers. Paste the commands below and go play.
  - **Power users:** A repeatable, idempotent bootstrap you can re-run on any machine.

- **What it sets up**
  - Core launchers: **Steam**, **Lutris**, **Heroic**
  - Proton helpers: **ProtonPlus** (Fedora via COPR) with **ProtonUp-Qt** fallback
  - Performance: **MangoHud** (global default config) and **GameMode**
  - Compatibility / graphics: **Vulkan** tools/drivers, common **Wine** bits (distro-appropriate)
  - **Duplicate cleanup:** If a native package is installed, matching Flatpak duplicates are removed

- **Safe & universal**
  - Auto-detects **Fedora/RHEL**, **Ubuntu/Debian**, **Arch**, **openSUSE**
  - Uses safe install flags where applicable (DNF family: `--skip-broken --best --allowerasing`)
  - Never stops on first error; continues and prints clear status (✅/❌)
  - Designed to be **re-run safely** (skips what’s already installed)

---

## 🚀 Quick Start (recommended; persistent under `~/scripts`)

> Copy and paste these lines **exactly**. This downloads the script into your home folder, makes it executable, and runs it.

```bash
mkdir -p ~/scripts
cd ~/scripts
wget https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh
chmod +x universal_gaming_setup.sh
sudo ~/scripts/universal_gaming_setup.sh
```

### Optional flags
- `-y` — auto-confirm installs
- `--verbose` — more output

**Examples**
```bash
# Auto-confirm everything
sudo ~/scripts/universal_gaming_setup.sh -y

# Auto-confirm + verbose output
sudo ~/scripts/universal_gaming_setup.sh -y --verbose
```

---

## Update or re-run later

To **refresh** the local script with the latest version from GitHub:
```bash
cd ~/scripts
rm -f universal_gaming_setup.sh
wget https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh
chmod +x universal_gaming_setup.sh
```

Then run it again:
```bash
sudo ~/scripts/universal_gaming_setup.sh -y --verbose
```

---

## What the script does (detail)

- **Repos (Fedora/RHEL only)**
  - Ensures **RPM Fusion** is enabled
  - Installs **ProtonPlus** from COPR when available; falls back to **ProtonUp-Qt** (Flatpak) if needed

- **Apps & tooling**
  - **Steam**, **Lutris**, **Heroic Games Launcher**
  - **Wine/compatibility** bits appropriate to your distro
  - **Vulkan** tools and drivers (Mesa/NVIDIA/AMD as applicable)
  - **MangoHud** overlay with a **sane global default**
  - **GameMode** for per-game performance

- **Smart duplicate cleanup**
  - If a **native** package is present, the script removes the **Flatpak duplicate** of the same app to avoid menu clutter (safe behavior)

---

## Tips

- **Install Proton-GE**
  - Open **ProtonPlus** (Fedora) or **ProtonUp-Qt** and install the latest **Proton-GE**
  - Steam → *Settings → Steam Play* → enable Steam Play and select **Proton-GE**

- **Show MangoHud**
  - Steam launch options: `MANGOHUD=1 %command%`
  - Toggle overlay in-game (common defaults: `F12` or `Shift+F12`)

- **Check GameMode**
  - `gamemoded --status` shows “GameMode is active” while a game is running

---

## Supported distros (auto-detected)

- **Fedora** / RHEL family (DNF/DNF5)  
- **Ubuntu / Debian** (APT)  
- **Arch** (pacman)  
- **openSUSE** (zypper)

> Package names differ across distros; the script accounts for this and **continues** when something isn’t available on your system.

---

## Run from a local clone (optional)

```bash
git clone https://github.com/XsMagical/Linux-Tools.git
cd Linux-Tools
chmod +x scripts/gaming/universal_gaming_setup.sh
sudo ./scripts/gaming/universal_gaming_setup.sh -y --verbose
```

SSH remote (if your key is set up):
```bash
git clone git@github.com:XsMagical/Linux-Tools.git
```

---

## Contributing / issues

- File an **Issue** with your distro/version and terminal output if something can be more universal or robust.
- PRs welcome — please keep changes **idempotent** and **cross-distro**.

---

**Made by XsMagical — Team Nocturnal**  
Script: [`scripts/gaming/universal_gaming_setup.sh`](https://github.com/XsMagical/Linux-Tools/blob/main/scripts/gaming/universal_gaming_setup.sh)
