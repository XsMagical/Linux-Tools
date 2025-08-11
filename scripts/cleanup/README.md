# Universal Linux Cleanup Script (`universal_cleanup.sh`)

~~~text
████████╗███╗   ██╗
╚══██╔══╝████╗  ██║
   ██║   ██╔██╗ ██║
   ██║   ██║╚██╗██║
   ██║   ██║ ╚████║
   ╚═╝   ╚═╝  ╚═══╝
----------------------------------------------------------
   Team-Nocturnal.com Universal Cleanup Script by XsMagical
----------------------------------------------------------
~~~

**Safe-by-default cleanup** for Debian/Ubuntu (APT), Fedora/RHEL (DNF), and Arch/Manjaro (Pacman).  
Optional extras include Flatpak/Snap tidying, Steam shader cache cleanup, dev tool cache purges, and Docker pruning.

---

## 📌 Overview

This script provides a safe and universal way to clean up your Linux system without breaking anything important. It detects your package manager (APT, DNF, Pacman) and removes:

- Orphaned and unneeded packages  
- Old package caches  
- Unused Flatpak runtimes/apps  
- Disabled Snap revisions  
- Old logs and journal files  
- User thumbnail and trash files  
- Dev caches (pip, npm, yarn, cargo)  
- *(Optional)* Steam shader/GPU caches  
- *(Optional)* Docker unused images/containers/volumes

It works safely out of the box, with optional flags for more aggressive cleaning.

---

## 📂 Script Source

View or download here:  
`https://github.com/XsMagical/Linux-Tools/blob/main/scripts/cleanup/universal_cleanup.sh`

---

## ▶️ One-Line Usage (Run Directly from GitHub)

**1) Safe default cleanup (recommended for first run)**

~~~bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/cleanup/universal_cleanup.sh) --yes
~~~

**2) Aggressive cleanup (deeper cache removal)**

~~~bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/cleanup/universal_cleanup.sh) --yes --aggressive --journal-days=7
~~~

**3) Add Steam cache cleanup (safe: games/configs untouched)**

~~~bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/cleanup/universal_cleanup.sh) --yes --steam-cache
~~~

**4) Docker cleanup (removes ALL unused images, containers, volumes)**

~~~bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/cleanup/universal_cleanup.sh) --yes --docker
~~~

**5) Combine aggressive + Steam + Docker**

~~~bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/cleanup/universal_cleanup.sh) --yes --aggressive --journal-days=7 --steam-cache --docker
~~~

---

## 💾 Running Locally (After Download)

*First, download and make the script executable:*

~~~bash
mkdir -p ~/scripts
cd ~/scripts
wget https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/cleanup/universal_cleanup.sh
chmod +x ~/scripts/universal_cleanup.sh
~~~

*Then you can run it from your saved copy:*

**1) Safe default cleanup**

~~~bash
~/scripts/universal_cleanup.sh --yes
~~~

**2) Aggressive cleanup**

~~~bash
~/scripts/universal_cleanup.sh --yes --aggressive --journal-days=7
~~~

**3) Steam cache cleanup**

~~~bash
~/scripts/universal_cleanup.sh --yes --steam-cache
~~~

**4) Docker cleanup**

~~~bash
~/scripts/universal_cleanup.sh --yes --docker
~~~

**5) Aggressive + Steam + Docker**

~~~bash
~/scripts/universal_cleanup.sh --yes --aggressive --journal-days=7 --steam-cache --docker
~~~

---

## 🔧 Usage & Options

~~~bash
~/scripts/universal_cleanup.sh [options]
~~~

~~~text
--yes              Non-interactive (auto-confirm where possible)
--dry-run          Show what would run; make no changes

--aggressive       Deeper cache purge:
                   • DNF: 'dnf clean all'
                   • Pacman: paccache keep=1 (or 'pacman -Scc' fallback)
                   • npm: 'npm cache clean --force'
--journal-days=N   Vacuum systemd journals to N days (default: 14)

--steam-cache      Clear Steam shader caches and GPU shader caches (safe)
--docker           Run 'docker system prune' to remove ALL unused:
                   images, containers, networks, and dangling volumes

--no-flatpak       Skip Flatpak cleanup
--no-snap          Skip Snap cleanup

-h, --help         Show help
~~~

---

## 🧼 What It Cleans

- **System packages**
  - **APT:** `autoremove --purge`, then `autoclean` (or `clean` with `--aggressive`).
  - **DNF:** `dnf autoremove`, then `dnf clean packages` (or `clean all` with `--aggressive`).
  - **Pacman:** remove orphans (`pacman -Rns …`), then trim caches with `paccache` (keep 3 by default, keep 1 with `--aggressive`). Falls back to `pacman -Sc/-Scc` if `paccache` is missing.

- **Runtimes & storefronts**
  - **Flatpak:** `flatpak uninstall --unused` + appstream refresh (optional `flatpak repair` with `--aggressive`).
  - **Snap:** clean disabled/obsolete revisions (skippable with `--no-snap`).

- **System logs**
  - **journald:** vacuum to N days (default **14**).
  - Rotated `.gz` logs in `/var/log` older than 30 days.

- **User caches**
  - Thumbnail cache, Trash (`~/.local/share/Trash`).

- **Dev/tool caches (auto-detected)**
  - `pip`/`pip3` cache purge, `npm cache verify` (or `npm cache clean --force` with `--aggressive`), `yarn cache clean`, `cargo-cache -a` (if installed).

- **Optional**
  - **Steam:** clear shader caches (safe) plus GPU shader caches with `--steam-cache`.
  - **Docker:** `docker system prune` (prompts unless `--yes`) with `--docker`.

---

## 🖥️ Supported Distros

- **Debian/Ubuntu** (APT)
- **Fedora/RHEL** (DNF/dnf5)
- **Arch/Manjaro** (Pacman, optional `paccache`)

> **Pacman tip:** If `paccache` is missing, install `pacman-contrib`:
>
> ~~~bash
> sudo pacman -Syu --needed pacman-contrib
> ~~~

---

## 🗂️ Logs & Exit Codes

- **Logs:** `~/cleanup_logs/clean-YYYYMMDD-HHMM.log`  
- **Exit codes:** `0` success, `1` error

---

## ⚠ Notes

- Does **NOT** remove kernels — leave kernel management to your package manager.
- Designed for Fedora, Ubuntu/Debian, and Arch/Manjaro.
- Safe defaults — only cleans more aggressively when you add flags.
- Keeps a log in `~/cleanup_logs` for every run.
- All scripts in this repo are intended to live under `~/scripts`.

---

**Enjoy your cleaner, faster Linux system!**
