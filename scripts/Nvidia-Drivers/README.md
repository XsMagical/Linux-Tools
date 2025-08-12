# Team Nocturnal — Universal NVIDIA (Signed) Installer

**What this is:**  
A **cross-distro NVIDIA installer** that prefers **vendor-signed drivers** where available (Ubuntu/Pop), and automatically handles **DKMS + Secure Boot (MOK) signing** when needed (Fedora/Arch/Debian paths). It also takes care of **nouveau** blacklisting and **kernel boot flags** (optional via flags).

**Who this is for:**  
- Users who want a **clean, reliable NVIDIA install** across Fedora/RHEL, Ubuntu/Debian, and Arch/Manjaro.  
- Systems with **Secure Boot ON** that need signed kernel modules.  
- Anyone who wants a **safe, re-runnable** setup script with sensible defaults and easy flags.

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

## 📁 Repo & Location

- GitHub Repo: `https://github.com/XsMagical/Linux-Tools`  
- Script Path in Repo: `scripts/Nvidia-Drivers/tn_universal_nvidia_signed.sh`  
- Direct download with `wget`:


---

## ✅ What it does (by distro)

- **Fedora/RHEL**: Enables **RPM Fusion**, installs **akmods** + NVIDIA stack, builds modules, optional local MOK signing if vendor signing isn’t present, updates boot flags, enables persistence services.  
- **Ubuntu/Pop/Debian**: Uses **ubuntu-drivers** (when available) to install **vendor-signed** drivers. Falls back to `nvidia-driver` + DKMS; handles MOK signing if Secure Boot is on and modules are unsigned.  
- **Arch/Manjaro**: Installs `nvidia-dkms` + headers; signs DKMS-built modules via MOK when Secure Boot is on; updates boot flags; optional services.

**Safe to re-run**: Skips existing work where possible, won’t break if repos or drivers already exist.

---

## 🚀 Quick Start (repo-safe install)

1) Download & make executable
```bash
mkdir -p ~/scripts
wget -O ~/scripts/tn_universal_nvidia_signed.sh https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/Nvidia-Drivers/tn_universal_nvidia_signed.sh
chmod +x ~/scripts/tn_universal_nvidia_signed.sh
```

2) Run
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh -y
```

3) Reboot when finished (and enroll MOK if prompted during boot)

- **Secure Boot ON?** If the script imports a new MOK, you’ll be prompted at next boot to **Enroll MOK** → choose **Enroll**, then **Continue**.

---

## 🧰 Flags (install options)

| Flag | What it does |
|---|---|
| `-y`, `--yes` | Non-interactive when supported (assume “yes”). |
| `--dry-run` | Print actions without executing (great for review). |
| `--skip-repos` | Don’t enable/modify repos (RPM Fusion / apt sources). |
| `--install-only` | Only install/upgrade NVIDIA packages (skip config/boot flags/signing/services). |
| `--configure-only` | Only do configuration/signing/services (skip package installs). |
| `--force-initramfs` | Force rebuilding initramfs/dracut/mkinitcpio. |
| `--no-sign` | Don’t do MOK signing even if Secure Boot is enabled. |
| `--force-mok-reimport` | Regenerate MOK key and re-import (requires reboot enrollment). |
| `--no-blacklist` | Don’t blacklist `nouveau`. |
| `--no-modeset` | Don’t add `nvidia_drm.modeset=1` to kernel params. |
| `--no-services` | Don’t enable `nvidia-persistenced` / `nvidia-powerd`. |

**Mutual exclusives:** `--install-only` and `--configure-only` cannot be used together.

---

## ⚠️ Important Warnings
- Installing the **latest NVIDIA driver from your distro repos** is generally safe and tested.  
- Installing from **NVIDIA’s official site (.run file)**, such as the one linked below, can provide the **absolute newest driver**, but may cause breakage on some kernels or desktop environments, especially with Secure Boot enabled.  
- Only advanced users who know how to roll back drivers or sign modules manually should install this way.

**Latest official NVIDIA driver (.run)** — version **580.76.05**:  
https://us.download.nvidia.com/XFree86/Linux-x86_64/580.76.05/NVIDIA-Linux-x86_64-580.76.05.run

**To install this driver manually (advanced users only):**
```bash
# Download
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/580.76.05/NVIDIA-Linux-x86_64-580.76.05.run -O NVIDIA-Linux-x86_64-580.76.05.run
chmod +x NVIDIA-Linux-x86_64-580.76.05.run

# Switch to a TTY and stop graphical session
sudo systemctl isolate multi-user.target

# Run installer
sudo ./NVIDIA-Linux-x86_64-580.76.05.run --dkms

# Reboot
sudo reboot
```
⚠️ **Warning:** This will overwrite your existing NVIDIA driver installation and bypass package manager updates. Secure Boot users must manually sign the installed kernel modules.

---

## 🩺 Troubleshooting

- **No Enroll prompt after reboot:** Some firmwares hide it; power off fully, then boot again. Ensure `mokutil --import` didn’t error.  
- **NVIDIA modules not loading (SB ON):** Run `sudo dmesg | grep -i nvidia` and confirm `modinfo nvidia` shows a signer. If unsigned, re-run with `--force-mok-reimport` and reboot to enroll.  
- **Wayland/black screen:** Try disabling Wayland or ensure `nvidia_drm.modeset=1` is present (unless you passed `--no-modeset`).  
- **GRUB vs systemd-boot:** Script auto-detects and updates the correct boot config; use `--force-initramfs` if you need a fresh image.
