# Team Nocturnal — Universal Post-Install Script

A simple **post-install helper** for Linux that works across **Fedora/RHEL**, **Debian/Ubuntu**, **Arch**, and **openSUSE**.

It offers ready-made presets for **Gaming**, **Media**, **General**, **Lite**, and **Full** setups.

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
wget -O tn_xs_post_install.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh
chmod +x tn_xs_post_install.sh
```

### Run a preset (choose one)

#### 🎮 Gaming
```bash
~/scripts/tn_xs_post_install.sh -y gaming
```

#### 🎬 Media (VLC, MPV, Celluloid, FFmpeg, HandBrake, GStreamer codecs)
```bash
~/scripts/tn_xs_post_install.sh -y media
```

#### 🛠️ General (everyday CLI tools)
```bash
~/scripts/tn_xs_post_install.sh -y general
```

#### 🪶 Lite (minimal essentials)
```bash
~/scripts/tn_xs_post_install.sh -y lite
```

#### 🧰 Full (General + Media + Dev/Virtualization stack)
```bash
~/scripts/tn_xs_post_install.sh -y full
```

## 🕹️ Full + Gaming
```bash
~/scripts/tn_xs_post_install.sh -y full && ~/scripts/tn_xs_post_install.sh -y gaming
```

> Need more output for troubleshooting? Add `--verbose` to any command:
```bash
~/scripts/tn_xs_post_install.sh -y --verbose full
```

### 🔄 Update to the latest script later
```bash
cd ~/scripts
rm -f tn_xs_post_install.sh
wget -O tn_xs_post_install.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh
chmod +x tn_xs_post_install.sh
```

---

## What each preset does

- **Gaming**
  - Fetches and runs Team-Nocturnal `universal_gaming_setup.sh` (from this repo).
  - Typical tools: Steam, Lutris, Heroic, Proton helpers, MangoHud, GameMode.

- **Media**
  - Installs **VLC**, **MPV**, **Celluloid**, **FFmpeg**, **HandBrake**.
  - Adds GStreamer plugins/codecs (on Fedora, uses RPM Fusion where appropriate).

- **General**
  - Installs common CLI utilities: `curl`, `wget`, `git`, editors, archive tools,
    `jq`, `ripgrep`, `fzf`, `tree`, `fastfetch`, networking basics, etc.

- **Lite**
  - Minimal essentials: a tiny subset (curl/wget/git/editor/htop/unzip) to get started fast.

- **Full**
  - **General + Media** plus a developer/virtualization base: `gcc`, `make`, `cmake`, `clang`,
    kernel headers, **QEMU/KVM**, **libvirt**, **virt-manager**, **OVMF**.

> The script auto-detects your distro and uses its native package manager with safe options (e.g., DNF: `--skip-broken --best --allowerasing`).  
> If a package isn’t available on your distro, it’s skipped and the script continues.

---

## Logging & re-running

- Logs are written to: `~/scripts/logs/post_install_<timestamp>.log`
- It’s safe to **re-run** any preset; already-installed items are skipped.

```bash
# View your most recent logs
ls -lt ~/scripts/logs | head -n 5
```

---

## Run from a local clone (optional)

```bash
git clone https://github.com/XsMagical/Linux-Tools.git
cd Linux-Tools
chmod +x scripts/post-setup/tn_xs_post_install.sh
./scripts/post-setup/tn_xs_post_install.sh -y full
```

---

## Supported distros (auto-detected)

- **Fedora** / RHEL family (DNF / DNF5)
- **Ubuntu / Debian** (APT)
- **Arch** (pacman)
- **openSUSE** (zypper)

> On Fedora, RPM Fusion is enabled automatically when needed for media/codecs.

---

## Notes for new users

- You’ll likely be asked for your **password** — that’s `sudo` asking to install packages.
- Seeing **“already installed”** or **“skipped”** messages is normal.
- If a repo or package is missing on your distro, the script **continues** and logs it.

---

**Made by XsMagical — Team Nocturnal**  
If something doesn’t work on your distro, open an issue with your distro/version and the latest log from `~/scripts/logs/`.
