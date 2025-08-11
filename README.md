# Team Nocturnal — Linux Tools

**Linux Tools** is a collection of **copy-and-paste automation scripts** that make a fresh Linux install fast, clean, and consistent — whether you’re brand-new to Linux or a power user who wants to save time.

- **Who it’s for:**  
  - **New users:** You don’t need to know how to install or update packages. Paste one command and the script handles the rest.  
  - **Power users:** Idempotent, safe scripts you can re-run anytime to standardize and bootstrap new machines quickly.

- **What it does (at a glance):**  
  - Post-install presets (Gaming, Media, General, Lite, Full)  
  - Gaming environment automation (Steam, Lutris/Heroic, Proton helpers, MangoHud, GameMode)  
  - Clean, cross-distro package installs using the right package manager for your system  
  - Sanity-safe flags (`--skip-broken --best --allowerasing` on DNF family) and **no hard exits** on transient errors  
  - Colorful status + ✅/❌ indicators; **logs every run to `~/scripts/logs/`**

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

## Design principles

- **Simple:** One line to run; sensible presets.  
- **Safe:** Never `set -e`; errors are logged and the script continues.  
- **Repeatable:** Re-running is safe — already-installed items are skipped.  
- **Cross-distro:** Auto-detects Fedora/RHEL, Ubuntu/Debian, Arch, and openSUSE and uses the native package manager.  
- **Visible:** Every run logs to `~/scripts/logs/post_install_<timestamp>.log`.

---

## Repository structure

```
scripts/
  post-setup/
    tn_xs_post_install.sh         # Universal post-install presets (Gaming/Media/General/Lite/Full)
  gaming/
    universal_gaming_setup.sh     # Team Nocturnal gaming stack (preferred; replaces old fedora_gaming_setup.sh)
  update/
    ...                            # Update/maintenance helpers (WIP / subject to change)
  cleanup/
    ...                            # Cleanup utilities (WIP / subject to change)
  common/
    header.sh                      # Shared banner/colors and helper includes
```

> Note: `universal_gaming_setup.sh` supersedes any old `fedora_gaming_setup.sh`. The Fedora-specific one was removed to avoid duplication.

---

## 🚀 Quick start (copy & paste)

> These one-liners run directly from GitHub — no clone required. You’ll likely be prompted for your password (that’s `sudo`).

### 🎮 Gaming (chains to Team-Nocturnal `universal_gaming_setup.sh`)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y gaming
```

### 🎬 Media (VLC, MPV, Celluloid, FFmpeg, HandBrake, GStreamer codecs)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y media
```

### 🛠️ General (everyday CLI tools)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y general
```

### 🪶 Lite (minimal essentials)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y lite
```

### 🧰 Full (General + Media + Dev/Virtualization stack)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y full
```

**Want more output?** Add `--verbose` to any command:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y --verbose full
```

### Fallback (if your shell blocks process substitution)
```bash
curl -fsSLo /tmp/tn_post_install.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh
bash /tmp/tn_post_install.sh -y full
```

---

## What the presets do

- **Gaming**  
  Fetches and runs Team-Nocturnal `universal_gaming_setup.sh` (Steam, Lutris/Heroic, Proton helpers, MangoHud, GameMode, etc.).

- **Media**  
  Installs **VLC**, **MPV**, **Celluloid**, **FFmpeg**, **HandBrake**, and common **GStreamer** plugins/codecs.  
  On Fedora, RPM Fusion is ensured where needed.

- **General**  
  Installs common CLI utilities: `curl`, `wget`, `git`, editors, archive tools, `jq`, `ripgrep`, `fzf`, `tree`, `fastfetch`, networking basics, etc.

- **Lite**  
  Minimal essentials for a tiny footprint: `curl`, `wget`, `git`, editor, `htop`, `unzip`.

- **Full**  
  **General + Media** plus a developer/virtualization base: `gcc`, `make`, `cmake`, `clang`, kernel headers, **QEMU/KVM**, **libvirt**, **virt-manager**, **OVMF**.

---

## Where do things get logged?

Every run writes a timestamped log here:
```
~/scripts/logs/post_install_<timestamp>.log
```

List your latest logs:
```bash
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

If you prefer SSH (after adding your key on GitHub):
```bash
git clone git@github.com:XsMagical/Linux-Tools.git
```

---

## Supported distros (auto-detected)

- **Fedora** / RHEL family (DNF/DNF5)  
- **Ubuntu / Debian** (APT)  
- **Arch** (pacman)  
- **openSUSE** (zypper)

> The scripts use safe flags and will **continue** if a repo/package isn’t available on your system.

---

## Contributing / issues

- Found something that could be more universal, faster, or safer?  
  Open an **Issue** with your distro/version and attach the latest log from `~/scripts/logs/`.
- PRs are welcome — please keep changes idempotent and cross-distro friendly.

---

## Credits

Made by **XsMagical** — Team Nocturnal  
GitHub: https://github.com/XsMagical/Linux-Tools
