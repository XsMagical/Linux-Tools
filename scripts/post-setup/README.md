# Team Nocturnal — Universal Post-Install Script

A simple **post-install helper** for Linux that works across **Fedora/RHEL**, **Debian/Ubuntu**, **Arch**, and **openSUSE**.

It offers ready-made presets for **Gaming**, **Media**, **General**, **Lite**, and **Full** setups.

> ✅ Safe by design: doesn’t exit on the first error, logs everything to `~/scripts/logs/`, and keeps going if a repo/package is missing.

---

## 🚀 Quick Start (Copy & Paste)

> Paste one line in your terminal. The script runs directly from GitHub — no clone needed.

```bash
# Gaming preset (chains to Team-Nocturnal "universal_gaming_setup.sh")
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y gaming

# Media preset (VLC, MPV, Celluloid, FFmpeg, HandBrake, GStreamer codecs)
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y media

# General tools (everyday CLI utilities)
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y general

# Lite essentials (minimal footprint)
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y lite

# Full stack (General + Media + Dev/Virtualization)
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y full
```

### Optional flags

```bash
# Skip Google Chrome (recommended if you don’t want Chrome or your distro doesn’t offer it)
--no-chrome

# More output for troubleshooting
--verbose
```

**Examples**

```bash
# Full stack, skip Chrome, verbose
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y --no-chrome --verbose full

# Media preset, default behavior (Chrome attempted only if available)
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y media
```

---

## What each preset does

- **Gaming**
  - Fetches and runs **Team-Nocturnal**: `universal_gaming_setup.sh` (from this repo).
  - Typical tools: Steam, Lutris, Heroic, Proton helpers, MangoHud, GameMode.

- **Media**
  - Installs **VLC**, **MPV**, **Celluloid**, **FFmpeg**, **HandBrake**.
  - Adds GStreamer plugins/codecs (on Fedora, uses RPM Fusion where appropriate).

- **General**
  - Installs common CLI utilities: `curl`, `wget`, `git`, editors, archive tools, `jq`, `ripgrep`, `fzf`, `tree`, `fastfetch`, networking basics, etc.

- **Lite**
  - Minimal essentials: a tiny subset (curl/wget/git/editor/htop/unzip) to get started fast.

- **Full**
  - **General + Media** plus a developer/virtualization base: `gcc`, `make`, `cmake`, `clang`, kernel headers, **QEMU/KVM**, **libvirt**, **virt-manager**, **OVMF**.

> The script auto-detects your distro and uses its native package manager with safe options (e.g., DNF: `--skip-broken --best --allowerasing`). If a package isn’t available on your distro, it’s skipped and the script continues.

---

## Chrome policy

- Chrome install is **optional**. The script will try to install it **only if** a repo is already available on your distro (e.g., Fedora’s `google-chrome` repo).
- To **skip Chrome explicitly**, add `--no-chrome` to your command.

---

## Logging & re-running

- Logs are written to: `~/scripts/logs/post_install_<timestamp>.log`
- It’s safe to **re-run** any preset; already-installed items are skipped.

```bash
# View your most recent logs
ls -lt ~/scripts/logs | head -n 5
```

---

## Local clone (optional)

Prefer running from a local copy?

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

- You’ll likely be asked for your **password** (that’s `sudo` asking to install packages).
- It’s normal to see some lines marked as **skipped** or **already installed**.
- If a package isn’t available on your distro, the script **continues** without failing.

---

**Made by XsMagical — Team Nocturnal**  
If something doesn’t work on your distro, open an issue with your distro/version and the latest log from `~/scripts/logs/`.
