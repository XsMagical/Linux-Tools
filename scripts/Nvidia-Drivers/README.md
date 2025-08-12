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

## 🆕 Install the latest **without switching to a TTY**

You can stay in your desktop session and still get the **latest available** for your distro **without using the NVIDIA `.run` installer**:

### Fedora / RHEL (RPM Fusion)
```bash
sudo dnf upgrade --refresh
sudo dnf install -y   xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda   nvidia-settings nvidia-persistenced
```

### Ubuntu / Pop!_OS (vendor-signed) — latest from repo
```bash
sudo apt update
sudo ubuntu-drivers autoinstall
```

### Ubuntu — latest from Graphics Drivers PPA
```bash
sudo add-apt-repository -y ppa:graphics-drivers/ppa
sudo apt update
sudo ubuntu-drivers autoinstall
```

### Debian — newer via backports
```bash
echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware" | sudo tee /etc/apt/sources.list.d/backports.list
sudo apt update
sudo apt -t bookworm-backports install -y nvidia-driver
```

### Arch / Manjaro
```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm nvidia-dkms nvidia-utils nvidia-settings
```

> These repo methods **do not require stopping the graphical session**. A **reboot** is still recommended to load the newly built/updated kernel module.

---

## (Optional) Upstream NVIDIA `.run` installer **without killing X**
If you *must* use the official `.run` installer and want to avoid switching to TTY, you can try:
```bash
sudo sh NVIDIA-Linux-x86_64-<VERSION>.run --dkms --no-opengl-files
```

---

## ⚠️ Important warnings
- Installing the **latest NVIDIA driver from your distro repos** is generally safe and tested.  
- Installing with the **NVIDIA `.run` file** can provide the **absolute newest driver**, but may cause breakage on some kernels or desktops, especially with Secure Boot enabled.  
- Only advanced users who know rollback/recovery and module signing should go the `.run` route.


## 🔄 Install NVIDIA 580.76.05 Without Switching to TTY

If you want to install the **latest upstream NVIDIA driver** directly from NVIDIA's site without stopping your graphical session, you can use the `--no-opengl-files` flag to avoid replacing in-use OpenGL libraries.  
⚠ **Note:** This method still requires a reboot and may fail if the kernel module is in active use. It is **not** recommended unless you specifically need this version and know how to recover from possible breakage.

**Steps:**

- 1) Download the official NVIDIA 580.76.05 driver
```bash
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/580.76.05/NVIDIA-Linux-x86_64-580.76.05.run -O NVIDIA-Linux-x86_64-580.76.05.run
```

- 2) Make it executable
```bash
chmod +x NVIDIA-Linux-x86_64-580.76.05.run
```

- 3) Run installer with DKMS and without replacing active OpenGL files
```bash
sudo ./NVIDIA-Linux-x86_64-580.76.05.run --dkms --no-opengl-files
```

- 4) Reboot to load the new driver
```bash
sudo reboot
```

**Additional notes:**
- Secure Boot users will need to sign the new kernel modules or disable Secure Boot.
- This bypasses your package manager — future kernel updates may require manually re-running the installer.
- If installation fails due to the driver module being in use, you may still need to stop the display manager or unload NVIDIA modules manually.


---

## 🔍 Check Current Driver Version

After installation, you can verify the installed NVIDIA driver version:

**If `nvidia-smi` is available (most systems):**
```bash
nvidia-smi --query-gpu=driver_version,name --format=csv,noheader
```

**If `nvidia-smi` is NOT available:**
```bash
modinfo nvidia | grep -E 'version:|signer|sig_key|sig_hash'
```

This will also show whether the module is vendor-signed or signed with a Machine Owner Key (MOK).

---

## 🩺 Troubleshooting

- **No Enroll prompt after reboot:** Some firmwares hide it; power off fully, then boot again. Ensure `mokutil --import` didn’t error.  
- **NVIDIA modules not loading (SB ON):** Run `sudo dmesg | grep -i nvidia` and confirm `modinfo nvidia` shows a signer. If unsigned, re-run with `--force-mok-reimport` and reboot to enroll.  
- **Wayland/black screen:** Try disabling Wayland or ensure `nvidia_drm.modeset=1` is present (unless you passed `--no-modeset`).  
- **GRUB vs systemd-boot:** Script auto-detects and updates the correct boot config; use `--force-initramfs` if you need a fresh image.
