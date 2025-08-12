# Team Nocturnal — Universal NVIDIA (Signed) Installer

**What this is:**  
A **cross‑distro NVIDIA installer** that prefers **vendor‑signed drivers** where available (Ubuntu/Pop), and automatically handles **DKMS + Secure Boot (MOK) signing** when needed (Fedora/Arch/Debian paths). It also takes care of **nouveau** blacklisting and **kernel boot flags** (optional via flags).

**Who this is for:**  
- Users who want a **clean, reliable NVIDIA install** across Fedora/RHEL, Ubuntu/Debian, and Arch/Manjaro.  
- Systems with **Secure Boot ON** that need signed kernel modules.  
- Anyone who wants a **safe, re‑runnable** setup script with sensible defaults and easy flags.

---

## 📁 Repo & Location

- GitHub Repo: `https://github.com/XsMagical/Linux-Tools`  
- Local path (recommended): `~/scripts/tn_universal_nvidia_signed.sh`  
- Make it executable: `chmod +x ~/scripts/tn_universal_nvidia_signed.sh`

---

## ✅ What it does (by distro)

- **Fedora/RHEL**: Enables **RPM Fusion**, installs **akmods** + NVIDIA stack, builds modules, optional local MOK signing if vendor signing isn’t present, updates boot flags, enables persistence services.  
- **Ubuntu/Pop/Debian**: Uses **ubuntu‑drivers** (when available) to install **vendor‑signed** drivers. Falls back to `nvidia-driver` + DKMS; handles MOK signing if Secure Boot is on and modules are unsigned.  
- **Arch/Manjaro**: Installs `nvidia-dkms` + headers; signs DKMS‑built modules via MOK when Secure Boot is on; updates boot flags; optional services.

**Safe to re‑run**: Skips existing work where possible, won’t break if repos or drivers already exist.

---

## 🚀 Quick Start


Save script into ~/scripts and make executable
```bash
mkdir -p ~/scripts
nano ~/scripts/tn_universal_nvidia_signed.sh   # paste script, save
chmod +x ~/scripts/tn_universal_nvidia_signed.sh
```


Run
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh -y
```


Reboot when finished (and enroll MOK if prompted during boot)


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

## 🧪 Examples

**Fedora/Ubuntu/Arch — full automatic (recommended):**
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh -y
```

**Install drivers only (no blacklist, no boot flags, no signing/services):**
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh -y --install-only
```

**Configure system only (e.g., after manual driver install):**
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh --configure-only
```

**Review plan without changing anything:**
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh --dry-run
```

**Secure Boot: regenerate & re-import MOK, then force initramfs:**
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh -y --force-mok-reimport --force-initramfs
```

**Keep nouveau (not recommended) and skip modeset flag:**
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh --no-blacklist --no-modeset
```

**Leave repos alone (useful on tightly controlled systems):**
```bash
sudo ~/scripts/tn_universal_nvidia_signed.sh -y --skip-repos
```

---

## 🔐 Secure Boot & MOK Notes

- **Ubuntu/Pop** generally provide **vendor‑signed** modules, so local signing usually isn’t required.  
- On **Fedora/Arch/Debian** paths with **DKMS**, Secure Boot will reject unsigned modules. The script can generate a **MOK key** and sign locally.  
- If a new MOK is imported, **reboot → Enroll MOK** (single-time action).

Check signing state:
```bash
mokutil --sb-state
modinfo nvidia | grep -E 'signer|sig_key|sig_hash' || true
```

---

## 🩺 Troubleshooting

- **No Enroll prompt after reboot:** Some firmwares hide it; power off fully, then boot again. Ensure `mokutil --import` didn’t error.  
- **NVIDIA modules not loading (SB ON):** Run `sudo dmesg | grep -i nvidia` and confirm `modinfo nvidia` shows a signer. If unsigned, re-run with `--force-mok-reimport` and reboot to enroll.  
- **Wayland/black screen:** Try disabling Wayland or ensure `nvidia_drm.modeset=1` is present (unless you passed `--no-modeset`).  
- **GRUB vs systemd‑boot:** Script auto-detects and updates the correct boot config; use `--force-initramfs` if you need a fresh image.

---

## ❌ Uninstall (manual, brief)

> Tip: Keep your display stack in mind; removing NVIDIA on a Wayland desktop mid‑session can be messy. Use a TTY (Ctrl+Alt+F3).

- **Fedora/RHEL (RPM Fusion):**
```bash
sudo dnf remove -y xorg-x11-drv-nvidia\* nvidia-settings nvidia-persistenced
sudo rm -f /etc/modprobe.d/blacklist-nouveau.conf
# Optional: remove added kernel params and rebuild configs (grub2-mkconfig/bootctl).
```

- **Ubuntu/Pop/Debian:**
```bash
sudo apt-get remove --purge -y '^nvidia-.*' nvidia-settings nvidia-persistenced
sudo rm -f /etc/modprobe.d/blacklist-nouveau.conf
sudo update-initramfs -u -k all
sudo update-grub
```

- **Arch/Manjaro:**
```bash
sudo pacman -Rns --noconfirm nvidia-dkms nvidia-utils nvidia-settings
sudo rm -f /etc/modprobe.d/blacklist-nouveau.conf
sudo mkinitcpio -P
```

Then **reboot**.

---

## 🧷 Notes & Guarantees

- Script is **idempotent** and designed to be **safe to re‑run**.  
- Respects `--skip-repos` and won’t touch repositories if you don’t want it to.  
- If you manage boot params yourself, use `--no-blacklist` and `--no-modeset`.  
- If vendor-signed modules are already present, **local signing is skipped**.

---

## 🖊 Author & Credits

- Team Nocturnal — **XsMagical**  
- GitHub: `https://github.com/XsMagical/Linux-Tools`
