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

> 🛡️ **No kernel removals.** Only caches, orphans, old logs/journals, and optional user/dev/tool caches are touched.  
> 🧾 **Logging:** Every run is logged to `~/cleanup_logs/clean-YYYYMMDD-HHMM.log`.  
> 📁 **Location:** All scripts in this repo live under `~/scripts`.

---

## What it cleans

- **System packages**
  - **APT:** `autoremove --purge`, then `autoclean` (or `clean` with `--aggressive`).
  - **DNF:** `dnf autoremove`, then `dnf clean packages` (or `clean all` with `--aggressive`).
  - **Pacman:** remove orphans (`pacman -Rns …`), then trim caches with `paccache` (keep 3 by default, keep 1 with `--aggressive`). Falls back to `pacman -Sc/-Scc` if `paccache` is missing.

- **Runtimes & storefronts**
  - **Flatpak:** `flatpak uninstall --unused`, refresh appstream, optional `flatpak repair` with `--aggressive`.
  - **Snap:** safely remove disabled/obsolete revisions (skipped with `--no-snap`).

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

## Usage

~~~bash
~/scripts/universal_cleanup.sh [options]
~~~

### Options

~~~text
--journal-days=N   Vacuum systemd journals to N days (default: 14)
--aggressive       Deeper cache purge (DNF clean all / Pacman keep=1 / npm clean)
--docker           Include Docker prune (prompts unless --yes)
--steam-cache      Clear Steam & GPU shader caches
--dry-run          Show what would run; make no changes
--yes              Non-interactive (auto-confirm where possible)
--no-snap          Skip Snap cleanup
--no-flatpak       Skip Flatpak cleanup
-h, --help         Show help
~~~

---

## Quick start

**Install to `~/scripts` (once):**
~~~bash
mkdir -p ~/scripts && cd ~/scripts
curl -fsSLo universal_cleanup.sh \
  https://raw.githubusercontent.com/XsMagical/Linux-Tools/refs/heads/main/scripts/cleanup/universal_cleanup.sh
chmod +x universal_cleanup.sh
~~~

**Dry run (no changes):**
~~~bash
~/scripts/universal_cleanup.sh --dry-run
~~~

**Safe default cleanup (non-interactive):**
~~~bash
~/scripts/universal_cleanup.sh --yes
~~~

**Keep journals for 7 days:**
~~~bash
~/scripts/universal_cleanup.sh --journal-days=7 --yes
~~~

**Aggressive cache trimming:**
~~~bash
~/scripts/universal_cleanup.sh --aggressive --yes
~~~

**Steam shader cleanup:**
~~~bash
~/scripts/universal_cleanup.sh --steam-cache --yes
~~~

**Include Docker prune:**
~~~bash
~/scripts/universal_cleanup.sh --docker --yes
~~~

**Skip Flatpak & Snap:**
~~~bash
~/scripts/universal_cleanup.sh --no-flatpak --no-snap --yes
~~~

**TN one-liner (install + run safe cleanup):**
~~~bash
mkdir -p ~/scripts && curl -fsSLo ~/scripts/universal_cleanup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/refs/heads/main/scripts/cleanup/universal_cleanup.sh && chmod +x ~/scripts/universal_cleanup.sh && ~/scripts/universal_cleanup.sh --yes
~~~

---

## Supported distros

- **Debian/Ubuntu** (APT)
- **Fedora/RHEL** (DNF/dnf5)
- **Arch/Manjaro** (Pacman, optional `paccache`)

**Pacman note:** If `paccache` is missing, install `pacman-contrib` for better cache trimming:
~~~bash
sudo pacman -Syu --needed pacman-contrib
~~~

---

## Logs & exit codes

- **Logs:** `~/cleanup_logs/clean-YYYYMMDD-HHMM.log`
- **Exit codes:** `0` success, `1` error

---

## Notes & safety

- Designed to be **re-runnable** and idempotent where possible.
- **No kernel package removals**; no bootloader changes.
- Docker prune only runs when `--docker` is supplied.
- Steam cleanup only runs when `--steam-cache` is supplied.

---

## Contributing

PRs welcome! Keep changes **safe by default**, distro-aware, and behind flags when behavior may be destructive. Please test on at least one distro per package manager family (APT/DNF/Pacman) before submitting.
