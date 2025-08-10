# Team Nocturnal — Universal Post-Install Script

A simple **post-install helper** for Linux that works across **Fedora/RHEL**, **Debian/Ubuntu**, **Arch**, and **openSUSE**.  
It offers ready-made presets for **Gaming**, **Media**, **General use**, **Lite**, and **Full** setups.

The **Gaming** preset automatically chains to the Team-Nocturnal Gaming Setup script:
[universal_gaming_setup.sh](../gaming/universal_gaming_setup.sh)

---

## 🚀 Quick Start — Copy & Paste
> These commands will download and run the script from your local clone.

```bash
# 1. Make the script executable (if not already)
chmod +x /home/xs/Linux-Tools/scripts/post-setup/tn_xs_post_install.sh

# 2. Run with a preset (examples below)

# Gaming setup (chains to TN gaming script)
 /home/xs/Linux-Tools/scripts/post-setup/tn_xs_post_install.sh -y gaming

# Media stack & codecs (VLC, MPV, FFmpeg, HandBrake, etc.)
/home/xs/Linux-Tools/scripts/post-setup/tn_xs_post_install.sh -y media

# General tools (CLI utilities, sensors, etc.)
/home/xs/Linux-Tools/scripts/post-setup/tn_xs_post_install.sh -y general

# Lite essentials (minimal tools)
 /home/xs/Linux-Tools/scripts/post-setup/tn_xs_post_install.sh -y lite

# Full package (General + Media + Dev/Virtualization tools)
 /home/xs/Linux-Tools/scripts/post-setup/tn_xs_post_install.sh -y full
