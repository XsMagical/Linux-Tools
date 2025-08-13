# Team Nocturnal — Gaming GUI Launcher (BETA)

An optional GUI/TUI front-end for `universal_gaming_setup.sh`.  
Lets users pick options (Discord mode, MangoHud defaults, Proton tools, etc.) and then runs the engine with those flags.

**Status:** Beta (safe to test; does not modify the engine)**

## Paths
- Launcher: `scripts/gaming/gui-beta/tn_gui_gaming_launcher.sh`
- Engine (expected): `~/scripts/universal_gaming_setup.sh` or `scripts/gaming/universal_gaming_setup.sh`

## Run (GUI)
```bash
~/Linux-Tools/scripts/gaming/gui-beta/tn_gui_gaming_launcher.sh --gui
```

## Run (TUI)
```bash
~/Linux-Tools/scripts/gaming/gui-beta/tn_gui_gaming_launcher.sh --tui
```

## Requirements
Needs one of:
- `zenity` / `yad` / `kdialog` (GUI)
- `whiptail` / `dialog` (TUI)

The launcher will attempt to auto-install a helper or fall back to TUI if none are found.
