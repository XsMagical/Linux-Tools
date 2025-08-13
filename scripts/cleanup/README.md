# 🧹 Universal Linux Cleanup Script

A simple **helper script** for Linux that now works across **Fedora/RHEL**, **Debian/Ubuntu**, **Arch/Manjaro**, **openSUSE**, **Alpine**, and **rpm-ostree** systems.

It offers ready-made presets for **Safe, Aggressive, Steam Cache, Docker, Kernel Pruning, Bootloader Refresh, and Combinations**.

> ✅ Safe by design: doesn’t exit on the first error, logs everything to `~/cleanup_logs/`, and keeps going if a repo/package is missing.

---

## 🚀 Quick Start (wget-style copy & paste)

> These commands save the script to `~/scripts/` so you can run it again later.

```bash
mkdir -p ~/scripts
cd ~/scripts
wget -O universal_cleanup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/cleanup/universal_cleanup.sh
chmod +x universal_cleanup.sh
```

---

## 🔧 Usage & Options

```bash
~/scripts/universal_cleanup.sh [options]
```

```text
--yes                  Non-interactive (auto-confirm where possible)
--dry-run              Show what would run; make no changes

--aggressive           Deeper cache purge:
                       • DNF: 'dnf clean all'
                       • Pacman: paccache keep=1 (or 'pacman -Scc' fallback)
                       • Zypper: 'zypper clean -a'
                       • npm: 'npm cache clean --force'

--journal-days=N       Vacuum systemd journals to N days (default: 14)
--prune-kernels        Safely remove old kernels (per-distro rules)
--refresh-bootloader   Refresh GRUB/systemd-boot configs after changes

--steam-cache          Clear Steam shader & GPU shader caches (safe)
--docker               Run 'docker system prune' to remove ALL unused:
                       images, containers, networks, and dangling volumes

--no-flatpak           Skip Flatpak cleanup
--no-snap              Skip Snap cleanup

-h, --help             Show help
```

---

## 🧼 What It Cleans

- **System packages**
  - **APT:** `autoremove --purge`, then `autoclean` (or `clean` with `--aggressive`).
  - **DNF:** `dnf autoremove`, then `dnf clean packages` (or `clean all` with `--aggressive`).
  - **Pacman:** remove orphans, trim caches (keep 3 or keep 1 with `--aggressive`).
  - **Zypper:** remove orphans, clean caches (`-a` with `--aggressive`).
  - **APK:** clear `/var/cache/apk`.
  - **rpm-ostree:** clean metadata and old deployments.

- **Runtimes & storefronts**
  - **Flatpak:** uninstall unused runtimes, refresh appstream, warn on EOL runtimes.
  - **Snap:** remove disabled revisions.

- **System logs**
  - **journald:** vacuum to N days (default **14**).
  - Rotated `.gz` logs in `/var/log` older than 30 days.

- **User caches**
  - Thumbnail cache, Trash (`~/.local/share/Trash`).

- **Dev/tool caches**
  - `pip`/`pip3`, `npm`, `yarn`, `cargo-cache`.

- **Optional**
  - **Steam:** clear shader caches (safe).
  - **Docker:** prune unused images, containers, networks, volumes.
  - **Kernel pruning:** safely remove old kernels without touching the running one.
  - **Bootloader refresh:** updates GRUB/systemd-boot configs.

---

## 📦 Presets

**1) Safe default cleanup**
```bash
~/scripts/universal_cleanup.sh --yes
```

**2) Aggressive cleanup with shorter journals**
```bash
~/scripts/universal_cleanup.sh --yes --aggressive --journal-days=7
```

**3) Steam cache cleanup only**
```bash
~/scripts/universal_cleanup.sh --yes --steam-cache
```

**4) Docker cleanup only**
```bash
~/scripts/universal_cleanup.sh --yes --docker
```

**5) Aggressive + Steam + Docker + Kernel prune**
```bash
~/scripts/universal_cleanup.sh --yes --aggressive --steam-cache --docker --prune-kernels
```

**6) Dry run (no changes, just show actions)**
```bash
~/scripts/universal_cleanup.sh --dry-run
```

**7) Aggressive cleanup + bootloader refresh**
```bash
~/scripts/universal_cleanup.sh --yes --aggressive --refresh-bootloader
```

**8) Skip Snap & Flatpak cleanup**
```bash
~/scripts/universal_cleanup.sh --yes --no-snap --no-flatpak
```

---

## 📝 Logging

- Logs are saved to: `~/cleanup_logs/clean-YYYYMMDD-HHMM.log`
- Safe to **re-run** — skips already-cleaned or non-existent items.

---

**Made by XsMagical — Team Nocturnal**  
MIT License

Copyright (c) 2025 XsMagical — Team Nocturnal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights  
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
copies of the Software, and to permit persons to whom the Software is  
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in  
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN  
THE SOFTWARE.
