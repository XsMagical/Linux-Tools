# Universal Linux Cleanup Script

A simple **helper script** for Linux that works across **Fedora/RHEL**, **Debian/Ubuntu**, **Arch**, and **openSUSE**.

It offers ready-made presets for **Safe, Aggressive, Steam Cache, Docker, Combined Aggressive + Steam + Docker**.

> ✅ Safe by design: doesn’t exit on the first error, logs everything to `~/scripts/logs/`, and keeps going if a repo/package is missing.

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

## 🚀 Quick Start (wget-style copy & paste)

> These commands save the script to `~/scripts/` so you can run it again later. Paste them exactly into your terminal.

### One-time download
```bash
mkdir -p ~/scripts
cd ~/scripts
wget -O universal_cleanup.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/cleanup/universal_cleanup.sh
chmod +x universal_cleanup.sh
```

### Run a preset (choose one)
```bash
~/scripts/universal_cleanup.sh -y (plus optional flags)
```

---

## Presets

- **Safe** — Performs safe default cleanup without removing critical files.
- **Aggressive** — Deeper cache purge including APT/DNF/Pacman caches, npm, yarn, cargo, etc.
- **Steam Cache** — Clears Steam shader and GPU shader caches without touching games/configs.
- **Docker** — Removes all unused images, containers, networks, and dangling volumes.
- **Combined** — Aggressive + Steam Cache + Docker in one run.

---

## 🔧 Usage & Options

```bash
~/scripts/universal_cleanup.sh [options]
```

```text
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
```

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

## Logging & re-running

- Logs are written to: `~/scripts/logs/universal_cleanup_YYYYMMDD_HHMMSS.log`
- It’s safe to **re-run** any preset; already-installed items are skipped.

```bash
# View your most recent logs
ls -lt ~/scripts/logs | head -n 5
```

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


## Supported distros (auto-detected)

- **Fedora** / RHEL family (DNF / DNF5)
- **Ubuntu / Debian** (APT)
- **Arch** (pacman, optional `paccache`)
- **openSUSE** (zypper)

> **Pacman tip:** If `paccache` is missing, install `pacman-contrib`:
>
> ```bash
> sudo pacman -Syu --needed pacman-contrib
> ```

---

## Notes for new users

- You’ll likely be asked for your **password** — that’s `sudo` asking to install packages.
- Seeing **“already installed”** or **“skipped”** messages is normal.
- If a repo or package is missing on your distro, the script **continues** and logs it.

---

**Made by XsMagical — Team Nocturnal**  
If something doesn’t work on your distro, open an issue with your distro/version and the latest log from `~/scripts/logs/`.

---

## License

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
