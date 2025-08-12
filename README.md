# Team Nocturnal — Linux Tools

Linux Tools is a collection of cross-distro automation scripts designed to make Linux setup and maintenance fast, clean, and consistent — whether you’re brand new to Linux or a power user looking to save time.

---

## Overview

- **Who it’s for:**
  - **New users:** No need to learn package managers — our scripts handle everything with a single run.
  - **Power users:** Idempotent, safe scripts you can re-run anytime to bootstrap or standardize multiple systems.

- **What it offers:**
  - Universal **post-install presets** (Gaming, Media, General, Lite, Full)
  - Automated **gaming environment setup** (Steam, Lutris/Heroic, Proton helpers, MangoHud, GameMode, etc.)
  - **NVIDIA Driver Installation (Signed/Unsigned)** with Secure Boot MOK support — [Wiki: NVIDIA Driver Installer](https://github.com/XsMagical/Linux-Tools/wiki/NVIDIA-Driver-Installer)
  - **System cleanup utilities** for safe removal of cache, unused packages, and more
  - **Update helpers** for keeping your system current
  - Cross-distro compatibility (Fedora/RHEL, Ubuntu/Debian, Arch, openSUSE)
  - Logging for every run to `~/scripts/logs/` with colorful status indicators

- **Design principles:**
  - **Simple** — Sensible defaults, minimal interaction
  - **Safe** — No hard exits; continues on recoverable errors
  - **Repeatable** — Already-installed packages are skipped
  - **Cross-platform** — Auto-detects and uses the native package manager

---

## Repository Structure

scripts/
  post-setup/
    tn_xs_post_install.sh         # Universal post-install script with multiple presets
  gaming/
    universal_gaming_setup.sh     # Gaming environment setup (supersedes old fedora_gaming_setup.sh)
  update/
    ...                            # Update and maintenance helpers
  cleanup/
    ...                            # Cleanup utilities
  drivers/
    tn_universal_nvidia_signed.sh # Universal NVIDIA driver install with Secure Boot support
  common/
    header.sh                      # Shared banner/colors and helper functions

---

## Links to Script Folders

- **Post-Install:** https://github.com/XsMagical/Linux-Tools/tree/main/scripts/post-setup
- **Gaming:** https://github.com/XsMagical/Linux-Tools/tree/main/scripts/gaming
- **Update:** https://github.com/XsMagical/Linux-Tools/tree/main/scripts/update
- **Cleanup:** https://github.com/XsMagical/Linux-Tools/tree/main/scripts/cleanup
- **Drivers (NVIDIA Installer):** https://github.com/XsMagical/Linux-Tools/tree/main/scripts/drivers

---

## Wiki References

- **Full Linux Tools Wiki:** https://github.com/XsMagical/Linux-Tools/wiki
