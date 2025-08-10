# 🎮 Team Nocturnal — Universal Gaming Setup (Linux)

This folder contains **`universal_gaming_setup.sh`**, a cross-distro script that sets up a full Linux gaming environment with **one command**. It’s built for:
- **New users** who want Steam, Lutris/Heroic, Proton helpers, overlays, and codecs without learning package managers.
- **Power users** who want a **repeatable, idempotent** bootstrap they can re-run on any machine.

**Highlights**
- Works on **Fedora/RHEL**, **Ubuntu/Debian**, **Arch**, and **openSUSE** (auto-detects distro, uses the right package manager).
- Installs core gaming apps: **Steam**, **Lutris**, **Heroic**.
- Proton helpers: **ProtonPlus** (Fedora via COPR) with **ProtonUp-Qt** as a Flatpak fallback.
- Performance tools: **MangoHud** (with a sensible default config) and **GameMode**.
- **Vulkan** tools/drivers and common Wine/compatibility dependencies.
- **De-duplicates** apps: if a native package is installed, Flatpak duplicates are removed (safe cleanup).
- **Safe to re-run** — skips what’s already installed; uses safe install flags where applicable.

---

## 🚀 Quick Start (copy & paste)

Run directly from GitHub — no clone needed. You’ll likely be prompted for your password (`sudo`).

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh) -y
```

Want more output?

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh) -y --verbose
```

**Fallback** (if your shell blocks process substitution):

```bash
curl -fsSLo /tmp/universal_gaming_setup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh
bash /tmp/universal_gaming_setup.sh -y --verbose
```

---

## What the script does (at a glance)

- **Repositories (Fedora/RHEL):**
  - Ensures **RPM Fusion** is enabled.
  - Installs **ProtonPlus** from COPR (preferred), with **ProtonUp-Qt** as Flatpak fallback if needed.

- **Apps & tools:**
  - **Steam** (native where available).
  - **Lutris** and **Heroic Games Launcher**.
  - **Wine/compatibility bits** needed by launchers and non-native titles (distro-appropriate).
  - **Vulkan** drivers/tools (e.g., `vulkan-tools`, Mesa/NVIDIA libs depending on distro/GPU).
  - **MangoHud** overlay with a **global default config** (FPS/frametime/temps).
  - **GameMode** for per-game performance tuning.

- **Smart cleanup:**
  - If a **native** package is installed, any **Flatpak duplicate** of the same app is **removed** to avoid two copies in menus.

- **Idempotent & resilient:**
  - Uses safe flags (DNF family: `--skip-broken --best --allowerasing`) and continues if a repo/package is missing.
  - Re-running is safe; installed items are skipped.

---

## Options & flags

- `-y, --assume-yes` — auto-confirm installs.
- `--verbose` — more output for troubleshooting.

> The script is designed to **never exit on the first error**; it logs an error line and continues.

---

## Logging

Every run writes a timestamped log (if `~/scripts/logs` exists, it will be used; otherwise the script will create it):

```
~/scripts/logs/gaming_setup_<timestamp>.log
```

List latest logs:
```bash
ls -lt ~/scripts/logs | head -n 5
```

---

## Tips & troubleshooting

- **Proton GE not showing up in Steam**  
  Open **ProtonPlus** (on Fedora via COPR) or **ProtonUp-Qt** (Flatpak fallback) and install a recent **Proton-GE**.  
  In Steam: *Settings → Steam Play → Enable Steam Play for supported/other titles → choose Proton-GE*.

- **Show MangoHud in a game**  
  Often automatic, but you can force it in Steam:  
  **Launch Options:** `MANGOHUD=1 %command%`  
  Then press `F12`/`Shift+F12` (depending on config) to toggle.

- **Check GameMode is active**  
  Run the game with GameMode; in a terminal you can also check:  
  `gamemoded --status` (look for “GameMode is active” when a game is running).

- **NVIDIA users**  
  Make sure the correct NVIDIA driver is installed for your distro. This script focuses on gaming stack/userland; driver install may be handled elsewhere in this repo.

---

## Supported distros (auto-detected)

- **Fedora** / RHEL family (DNF/DNF5)  
- **Ubuntu / Debian** (APT)  
- **Arch** (pacman)  
- **openSUSE** (zypper)

> Some package names differ by distro. The script accounts for this and **continues** where a package isn’t available.

---

## Run from a local clone (optional)

```bash
git clone https://github.com/XsMagical/Linux-Tools.git
cd Linux-Tools
chmod +x scripts/gaming/universal_gaming_setup.sh
./scripts/gaming/universal_gaming_setup.sh -y --verbose
```

SSH remote (if you’ve set up keys on GitHub):
```bash
git clone git@github.com:XsMagical/Linux-Tools.git
```

---

## Contributing / issues

- If something could be more universal, faster, or safer, open an **Issue** with your distro/version and attach the latest log from `~/scripts/logs/`.
- PRs welcome — keep changes **idempotent** and **cross-distro**.

---

**Made by XsMagical — Team Nocturnal**  
Folder: `scripts/gaming/` • Script: [`universal_gaming_setup.sh`](https://github.com/XsMagical/Linux-Tools/blob/main/scripts/gaming/universal_gaming_setup.sh)
