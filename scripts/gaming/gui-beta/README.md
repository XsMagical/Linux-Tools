# 🎮 Team Nocturnal — Beta Gaming GUI/TUI Launcher

**By [XsMagical](https://github.com/XsMagical)**

---

## 📌 What is this?

This is a **beta** version of the Gaming Setup Script launcher with a **GUI/TUI** interface.  
Instead of typing flags manually, you select options from checkboxes and radio buttons, and it will run the main gaming setup engine (`universal_gaming_setup.sh`) with the correct flags.

---

## ✨ Features

- Choose **Discord install mode**: `auto`, `native`, `flatpak`, or skip entirely.
- Enable/disable:
  - Flatpak duplicate cleanup
  - MangoHud default config
  - ProtonPlus (repo/COPR)
  - ProtonUp-Qt (fallback tool)
  - Skip Steam install
  - Assume yes to prompts (`-y`)
- GUI mode with **Zenity/Yad/KDialog** (auto-detected)
- TUI mode with **Whiptail/Dialog** (fallback if no GUI)
- Logs to: `~/scripts/logs/gaming_gui_*.log`

---

## 📂 Script Source

**Repo Folder:**  
[scripts/gaming/gui-beta/](https://github.com/XsMagical/Linux-Tools/tree/gui-gaming-beta/scripts/gaming/gui-beta)  

**Script File:**  
[tn_gui_gaming_launcher.sh](https://github.com/XsMagical/Linux-Tools/blob/gui-gaming-beta/scripts/gaming/gui-beta/tn_gui_gaming_launcher.sh)

---

## ▶️ How to Run

### **Option 1: Run directly from GitHub (no clone)**
```bash
bash <(curl -s https://raw.githubusercontent.com/XsMagical/Linux-Tools/gui-gaming-beta/scripts/gaming/gui-beta/tn_gui_gaming_launcher.sh) --gui
```
Or TUI:
```bash
bash <(curl -s https://raw.githubusercontent.com/XsMagical/Linux-Tools/gui-gaming-beta/scripts/gaming/gui-beta/tn_gui_gaming_launcher.sh) --tui
```

---

### **Option 2: Run locally from your repo**
```bash
~/Linux-Tools/scripts/gaming/gui-beta/tn_gui_gaming_launcher.sh --gui
```
Or TUI:
```bash
~/Linux-Tools/scripts/gaming/gui-beta/tn_gui_gaming_launcher.sh --tui
```

---

## 📦 Requirements

Needs one of:
- `zenity` / `yad` / `kdialog` (GUI)
- `whiptail` / `dialog` (TUI)

The launcher will attempt to auto-install a helper or fall back to TUI if none are found.
