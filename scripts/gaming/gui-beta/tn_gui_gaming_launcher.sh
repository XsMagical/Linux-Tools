#!/usr/bin/env bash
# Team Nocturnal — Gaming GUI Launcher (for revised universal_gaming_setup.sh)
# Location: ~/scripts/tn_gui_gaming_launcher.sh
# Purpose: Optional GUI/TUI to collect options, then call:
#          ~/scripts/universal_gaming_setup.sh
# Compatible flags (from engine):
#   --discord=<auto|native|flatpak|none>
#   --no-cleanup-flatpak-dupes
#   --mangohud-defaults
#   --protonplus
#   --protonupqt
#   --skip-steam
#   -y | --yes

# ===== Colors =====
RED="\033[31m"; BLUE="\033[34m"; RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"

print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   Team-Nocturnal.com \"Gaming GUI Launcher\" by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# =============================
# Config & Defaults
# =============================
ENGINE_DEFAULT="$HOME/scripts/universal_gaming_setup.sh"
ENGINE_ALT="$HOME/Linux-Tools/scripts/gaming/universal_gaming_setup.sh"
LOG_DIR="$HOME/scripts/logs"; mkdir -p "$LOG_DIR"

# Defaults aligned to engine behavior
DISCORD_MODE="auto"          # auto|native|flatpak|none
CLEANUP_DUPES=1              # 1 = cleanup Flatpak dupes (default in engine)
WRITE_MANGOHUD_DEFAULTS=0
WANT_PROTONPLUS=0
WANT_PROTONUPQT=0
SKIP_STEAM=0
ASSUME_YES=0

set -o errexit -o nounset -o pipefail
trap 'echo -e "\n${RED}Error on line ${BASH_LINENO[0]} – continuing (launcher-safe).${RESET}" >&2' ERR

print_banner

# =============================
# Resolve engine path
# =============================
ENGINE="${ENGINE_DEFAULT}"
[[ ! -x "$ENGINE" && -x "$ENGINE_ALT" ]] && ENGINE="$ENGINE_ALT"
if [[ ! -x "$ENGINE" ]]; then
  echo -e "${RED}Engine script not found or not executable.${RESET}"
  echo -e "Expected at: ${BOLD}${ENGINE_DEFAULT}${RESET}"
  echo -e "Or fallback: ${BOLD}${ENGINE_ALT}${RESET}"
  exit 1
fi

# =============================
# Helpers
# =============================
have() { command -v "$1" >/dev/null 2>&1; }

pmgr=""
if   have dnf;     then pmgr="dnf"
elif have apt-get; then pmgr="apt"
elif have pacman;  then pmgr="pacman"
elif have zypper;  then pmgr="zypper"
fi

install_pkg() {
  local pkg="$1"
  case "$pmgr" in
    dnf)    sudo dnf -y install "$pkg" || true ;;
    apt)    sudo apt-get update -y || true; sudo apt-get install -y "$pkg" || true ;;
    pacman) sudo pacman -Sy --noconfirm "$pkg" || true ;;
    zypper) sudo zypper --non-interactive in "$pkg" || true ;;
    *)      return 1 ;;
  esac
}

choose_gui_backend() {
  if [[ -n "${KDE_FULL_SESSION:-}" || "${XDG_CURRENT_DESKTOP:-}" =~ (KDE|Plasma) ]]; then
    have kdialog && { echo "kdialog"; return; }
  fi
  have zenity && { echo "zenity"; return; }
  have yad    && { echo "yad"; return; }
  echo ""
}
ensure_gui_backend() {
  local b; b="$(choose_gui_backend)"
  if [[ -n "$b" ]]; then echo "$b"; return; fi
  if [[ -n "${DISPLAY:-}" ]]; then
    echo -e "${DIM}Attempting to install zenity...${RESET}"
    install_pkg zenity || true
  fi
  b="$(choose_gui_backend)"; echo "$b"
}

choose_tui_backend() { have whiptail && { echo "whiptail"; return; }; have dialog && { echo "dialog"; return; }; echo ""; }
ensure_tui_backend() {
  local b; b="$(choose_tui_backend)"
  if [[ -n "$b" ]]; then echo "$b"; return; fi
  echo -e "${DIM}Attempting to install whiptail...${RESET}"
  install_pkg whiptail || true
  b="$(choose_tui_backend)"; echo "$b"
}

# =============================
# GUI Flow
# =============================
run_gui_flow() {
  local backend="$1"

  # --- Discord mode (radio) ---
  case "$backend" in
    zenity|yad)
      local dsel
      dsel="$(
        "${backend}" --list --radiolist \
          --title="Discord Mode" --width=520 --height=300 \
          --column="Select" --column="Mode" --column="Description" \
          TRUE "auto"    "Prefer native; fall back to Flatpak" \
          FALSE "native" "Install native package" \
          FALSE "flatpak" "Install Flatpak package" \
          FALSE "none"    "Do not install Discord" \
          2>/dev/null
      )" || return 1
      [[ -n "$dsel" ]] && DISCORD_MODE="$dsel"
      ;;
    kdialog)
      local dsel_k
      dsel_k="$(
        kdialog --radiolist "Choose Discord mode" \
          "auto" "Prefer native; fallback Flatpak" on \
          "native" "Install native package" off \
          "flatpak" "Install Flatpak package" off \
          "none" "Do not install Discord" off
      )" || return 1
      [[ -n "$dsel_k" ]] && DISCORD_MODE="$dsel_k"
      ;;
  esac

  # --- Checkboxes ---
  case "$backend" in
    zenity|yad)
      # Selected column must be TRUE/FALSE. Start with sensible defaults.
      local sel="$(
        "${backend}" --list --checklist \
          --title="Options" --width=640 --height=420 \
          --column="Select" --column="Option" --column="Description" \
          TRUE  "cleanup-flatpak-dupes" "Remove Flatpak dupes when native installed" \
          FALSE "mangohud-defaults"     "Write default MangoHud config" \
          FALSE "protonplus"            "Install ProtonPlus (repo/COPR)" \
          FALSE "protonupqt"            "Install ProtonUp-Qt (fallback tool)" \
          FALSE "skip-steam"            "Skip Steam install" \
          FALSE "yes"                   "Assume yes to prompts (-y)" \
          2>/dev/null
      )" || true

      # Parse | separated list
      if [[ -n "$sel" ]]; then
        CLEANUP_DUPES=0; WRITE_MANGOHUD_DEFAULTS=0; WANT_PROTONPLUS=0; WANT_PROTONUPQT=0; SKIP_STEAM=0; ASSUME_YES=0
        IFS="|" read -r -a arr <<<"$sel"
        for item in "${arr[@]}"; do
          case "$item" in
            cleanup-flatpak-dupes) CLEANUP_DUPES=1 ;;
            mangohud-defaults)     WRITE_MANGOHUD_DEFAULTS=1 ;;
            protonplus)            WANT_PROTONPLUS=1 ;;
            protonupqt)            WANT_PROTONUPQT=1 ;;
            skip-steam)            SKIP_STEAM=1 ;;
            yes)                   ASSUME_YES=1 ;;
          esac
        done
      else
        # If user canceled checklist, keep defaults (CLEANUP_DUPES=1, others 0)
        :
      fi
      ;;
    kdialog)
      # Simple yes/no prompts for each toggle
      CLEANUP_DUPES=1
      kdialog --yesno "Write default MangoHud config?" && WRITE_MANGOHUD_DEFAULTS=1 || WRITE_MANGOHUD_DEFAULTS=0
      kdialog --yesno "Install ProtonPlus?" && WANT_PROTONPLUS=1 || WANT_PROTONPLUS=0
      kdialog --yesno "Install ProtonUp-Qt?" && WANT_PROTONUPQT=1 || WANT_PROTONUPQT=0
      kdialog --yesno "Skip Steam install?" && SKIP_STEAM=1 || SKIP_STEAM=0
      kdialog --yesno "Assume yes to prompts (-y)?" && ASSUME_YES=1 || ASSUME_YES=0
      ;;
  esac

  # Build flags
  local flags=()
  case "$DISCORD_MODE" in
    auto|native|flatpak) flags+=( "--discord=${DISCORD_MODE}" ) ;;
    none)                flags+=( "--discord=none" ) ;;
  esac
  [[ "$CLEANUP_DUPES" -eq 0 ]] && flags+=( "--no-cleanup-flatpak-dupes" )
  [[ "$WRITE_MANGOHUD_DEFAULTS" -eq 1 ]] && flags+=( "--mangohud-defaults" )
  [[ "$WANT_PROTONPLUS" -eq 1 ]] && flags+=( "--protonplus" )
  [[ "$WANT_PROTONUPQT" -eq 1 ]] && flags+=( "--protonupqt" )
  [[ "$SKIP_STEAM" -eq 1 ]] && flags+=( "--skip-steam" )  # case-insensitive in engine, but keep as given
  [[ "$ASSUME_YES" -eq 1 ]] && flags+=( "-y" )

  # Confirm
  local summary
  summary="Engine: ${ENGINE}\n\nFlags:\n$(printf '  %q\n' "${flags[@]}")\n\nProceed?"
  case "$backend" in
    zenity|yad) "${backend}" --question --title="Confirm" --width=520 --text="$summary" 2>/dev/null || return 1 ;;
    kdialog)    kdialog --yesno "$summary" || return 1 ;;
  esac

  run_engine "${flags[@]}"
}

# =============================
# TUI Flow
# =============================
run_tui_flow() {
  local backend="$1"
  local h=18 w=70

  # Discord mode
  local dsel=""
  if [[ "$backend" = "whiptail" ]]; then
    dsel="$(
      whiptail --title "Discord Mode" --radiolist "Choose mode" $h $w 4 \
        "auto" "Prefer native; fallback Flatpak" ON \
        "native" "Install native package" OFF \
        "flatpak" "Install Flatpak package" OFF \
        "none" "Do not install Discord" OFF 3>&1 1>&2 2>&3
    )" || return 1
  else
    dsel="$(
      dialog --stdout --title "Discord Mode" --radiolist "Choose mode" $h $w 4 \
        "auto" "Prefer native; fallback Flatpak" on \
        "native" "Install native package" off \
        "flatpak" "Install Flatpak package" off \
        "none" "Do not install Discord" off
    )" || return 1
  fi
  [[ -n "$dsel" ]] && DISCORD_MODE="$dsel"

  # Checkboxes
  local toggle_items=(
    "cleanup-flatpak-dupes" "Remove Flatpak dupes when native installed" "ON"
    "mangohud-defaults"     "Write default MangoHud config"              "OFF"
    "protonplus"            "Install ProtonPlus (repo/COPR)"             "OFF"
    "protonupqt"            "Install ProtonUp-Qt (fallback tool)"        "OFF"
    "skip-steam"            "Skip Steam install"                          "OFF"
    "yes"                   "Assume yes to prompts (-y)"                  "OFF"
  )
  local toggles_str=""
  if [[ "$backend" = "whiptail" ]]; then
    toggles_str="$(
      whiptail --title "Options" --checklist "Enable options" $h $w 6 \
        "${toggle_items[@]}" 3>&1 1>&2 2>&3
    )" || true
  else
    toggles_str="$(
      dialog --stdout --title "Options" --checklist "Enable options" $h $w 6 \
        "${toggle_items[@]}"
    )" || true
  fi
  # Parse selection
  CLEANUP_DUPES=0; WRITE_MANGOHUD_DEFAULTS=0; WANT_PROTONPLUS=0; WANT_PROTONUPQT=0; SKIP_STEAM=0; ASSUME_YES=0
  # shellcheck disable=SC2206
  local arr=($toggles_str)
  for item in "${arr[@]}"; do
    case "${item//\"/}" in
      cleanup-flatpak-dupes) CLEANUP_DUPES=1 ;;
      mangohud-defaults)     WRITE_MANGOHUD_DEFAULTS=1 ;;
      protonplus)            WANT_PROTONPLUS=1 ;;
      protonupqt)            WANT_PROTONUPQT=1 ;;
      skip-steam)            SKIP_STEAM=1 ;;
      yes)                   ASSUME_YES=1 ;;
    esac
  done

  # Build flags
  local flags=()
  case "$DISCORD_MODE" in
    auto|native|flatpak) flags+=( "--discord=${DISCORD_MODE}" ) ;;
    none)                flags+=( "--discord=none" ) ;;
  esac
  [[ "$CLEANUP_DUPES" -eq 0 ]] && flags+=( "--no-cleanup-flatpak-dupes" )
  [[ "$WRITE_MANGOHUD_DEFAULTS" -eq 1 ]] && flags+=( "--mangohud-defaults" )
  [[ "$WANT_PROTONPLUS" -eq 1 ]] && flags+=( "--protonplus" )
  [[ "$WANT_PROTONUPQT" -eq 1 ]] && flags+=( "--protonupqt" )
  [[ "$SKIP_STEAM" -eq 1 ]] && flags+=( "--skip-steam" )
  [[ "$ASSUME_YES" -eq 1 ]] && flags+=( "-y" )

  # Confirm & run
  local summary
  summary="Engine: ${ENGINE}\n\nFlags:\n$(printf '  %q\n' "${flags[@]}")\n\nProceed?"
  if [[ "$backend" = "whiptail" ]]; then
    whiptail --title "Confirm" --yesno "$summary" 18 80 || return 1
  else
    dialog --stdout --title "Confirm" --yesno "$summary" 18 80 || return 1
  fi
  run_engine "${flags[@]}"
}

# =============================
# Engine Runner
# =============================
run_engine() {
  local flags=( "$@" )
  local ts logf rc
  ts="$(date +%Y%m%d_%H%M%S)"
  logf="${LOG_DIR}/gaming_gui_${ts}.log"

  echo -e "${BOLD}Running:${RESET} ${ENGINE} ${flags[*]}"
  echo -e "${DIM}Logging to: ${logf}${RESET}\n"

  command -v sudo >/dev/null 2>&1 && sudo -v || true

  set +o errexit
  "${ENGINE}" "${flags[@]}" 2>&1 | tee -a "$logf"
  rc="${PIPESTATUS[0]}"
  set -o errexit

  if [[ "$rc" -eq 0 ]]; then
    echo -e "\n${BOLD}Done.${RESET} Exit code: 0"
  else
    echo -e "\n${RED}Engine finished with errors (code ${rc}).${RESET}"
    echo -e "See log: ${logf}"
  fi
}

# =============================
# CLI: force --gui / --tui
# =============================
MODE_AUTO=1; MODE=""
if [[ "${1:-}" == "--gui" ]]; then MODE_AUTO=0; MODE="gui"; shift; fi
if [[ "${1:-}" == "--tui" ]]; then MODE_AUTO=0; MODE="tui"; shift; fi

# =============================
# Entry
# =============================
if [[ "${MODE_AUTO}" -eq 1 ]]; then
  if [[ -n "${DISPLAY:-}" ]]; then
    backend="$(ensure_gui_backend)"
    if [[ -n "$backend" ]]; then
      run_gui_flow "$backend" || { echo -e "${RED}GUI canceled or failed.${RESET}"; exit 1; }
      exit 0
    fi
  fi
  backend="$(ensure_tui_backend)"
  if [[ -n "$backend" ]]; then
    run_tui_flow "$backend" || { echo -e "${RED}TUI canceled or failed.${RESET}"; exit 1; }
    exit 0
  fi

  # Last-resort plain prompts
  echo -e "${DIM}No GUI/TUI helpers available; using plain prompts...${RESET}"
  read -rp "Discord mode [auto/native/flatpak/none] (default: auto): " d
  DISCORD_MODE="${d:-auto}"

  flags=()
  case "$DISCORD_MODE" in
    auto|native|flatpak) flags+=( "--discord=${DISCORD_MODE}" ) ;;
    none)                flags+=( "--discord=none" ) ;;
  esac

  read -rp "Cleanup Flatpak dupes when native present? [Y/n]: " ans
  [[ -z "$ans" || "${ans,,}" == y* ]] || flags+=( "--no-cleanup-flatpak-dupes" )
  read -rp "Write default MangoHud config? [y/N]: " ans
  [[ "${ans,,}" == y* ]] && flags+=( "--mangohud-defaults" )
  read -rp "Install ProtonPlus? [y/N]: " ans
  [[ "${ans,,}" == y* ]] && flags+=( "--protonplus" )
  read -rp "Install ProtonUp-Qt? [y/N]: " ans
  [[ "${ans,,}" == y* ]] && flags+=( "--protonupqt" )
  read -rp "Skip Steam install? [y/N]: " ans
  [[ "${ans,,}" == y* ]] && flags+=( "--skip-steam" )
  read -rp "Assume yes to prompts (-y)? [y/N]: " ans
  [[ "${ans,,}" == y* ]] && flags+=( "-y" )

  echo -e "\nAbout to run:\n  ${ENGINE} ${flags[*]}"
  read -rp "Proceed? [Y/n]: " ok
  if [[ -z "${ok}" || "${ok,,}" == y* ]]; then
    run_engine "${flags[@]}"
  else
    echo "Canceled."
  fi
  exit 0
else
  case "$MODE" in
    gui)
      backend="$(ensure_gui_backend)"
      [[ -z "$backend" ]] && { echo -e "${RED}No GUI backend available. Try --tui instead.${RESET}"; exit 1; }
      run_gui_flow "$backend"
      ;;
    tui)
      backend="$(ensure_tui_backend)"
      [[ -z "$backend" ]] && { echo -e "${RED}No TUI backend available.${RESET}"; exit 1; }
      run_tui_flow "$backend"
      ;;
  esac
fi
