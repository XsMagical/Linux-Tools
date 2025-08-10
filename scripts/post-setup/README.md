# Team Nocturnal — Universal Post-Install Script

A simple **post-install helper** for Linux that works across **Fedora/RHEL**, **Debian/Ubuntu**, **Arch**, and **openSUSE**.  
It offers ready-made presets for **Gaming**, **Media**, **General use**, **Lite**, and **Full** setups.

The **Gaming** preset automatically chains to the Team-Nocturnal gaming script:  
[universal_gaming_setup.sh](../gaming/universal_gaming_setup.sh)

---

## 🚀 Quick Start — Copy & Paste
> Runs directly from GitHub — no local clone required.

**Gaming (chains to TN gaming script)**
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y gaming

**Media stack (VLC, MPV, FFmpeg, HandBrake, codecs)**
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y media

**General tools (CLI utilities, sensors, gparted, etc.)**
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y general

**Lite essentials (minimal tools)**
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y lite

**Full package (General + Media + Dev/Virtualization)**
bash <(curl -fsSL https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/post-setup/tn_xs_post_install.sh) -y full
