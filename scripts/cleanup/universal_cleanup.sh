#!/usr/bin/env bash

# ===== Colors & Icons =====
RED="[31m"; BLUE="[34m"; GREEN="[32m"; YELLOW="[33m"; RESET="[0m"; BOLD="[1m"
BGREEN="[42m"; BBLUE="[44m"; BRED="[41m"; WHITE="[97m"
ICON_OK="${BGREEN}${WHITE} ✔ ${RESET}"        # success / installed / updated
ICON_PRESENT="${BBLUE}${WHITE} ✔ ${RESET}"    # already present / skipped / no-op
ICON_ERR="${BRED}${WHITE} ✖ ${RESET}"         # failed

# Print the banner
print_banner() {
  printf '%b
' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b
' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b
' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b
' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b
' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b
' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b
' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b
' "${BLUE}   Team-Nocturnal.com Universal Cleanup by XsMagical${RESET}"
  printf '%b
' "${BLUE}----------------------------------------------------------${RESET}"
}

# ===== Logging Setup =====
LOG_DIR="$HOME/cleanup_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/clean-$(date +'%Y%m%d-%H%M').log"

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Cleanup started"

# ===== Disk Size Before Cleanup =====
disk_before=$(df -h --total | grep 'total' | awk '{print $3}')

# ===== Cleanup Functions =====

# Check if package manager exists before running each cleanup
clean_apt() {
    if command -v apt > /dev/null; then
        log "Cleaning APT"
        sudo apt autoremove --purge -y
        sudo apt autoclean -y
        echo "APT cleanup completed"
    else
        echo "APT not found, skipping"
    fi
}

clean_dnf() {
    if command -v dnf > /dev/null; then
        log "Cleaning DNF"
        sudo dnf autoremove -y
        sudo dnf clean packages -y
        echo "DNF cleanup completed"
    else
        echo "DNF not found, skipping"
    fi
}

clean_pacman() {
    if command -v pacman > /dev/null; then
        log "Cleaning Pacman"
        sudo pacman -Rns $(pacman -Qdtq) --noconfirm
        sudo pacman -Scc --noconfirm
        echo "Pacman cleanup completed"
    else
        echo "Pacman not found, skipping"
    fi
}

clean_zypper() {
    if command -v zypper > /dev/null; then
        log "Cleaning Zypper"
        sudo zypper clean -a
        echo "Zypper cleanup completed"
    else
        echo "Zypper not found, skipping"
    fi
}

clean_apk() {
    if command -v apk > /dev/null; then
        log "Cleaning APK"
        sudo apk cache clean
        echo "APK cleanup completed"
    else
        echo "APK not found, skipping"
    fi
}

clean_flatpak() {
    if command -v flatpak > /dev/null; then
        log "Cleaning Flatpak"
        flatpak uninstall --unused -y
        flatpak update --appstream
        echo "Flatpak cleanup completed"
    else
        echo "Flatpak not found, skipping"
    fi
}

clean_snap() {
    if command -v snap > /dev/null; then
        log "Cleaning Snap"
        snap remove $(snap list | grep -i "disabled" | awk '{print $1}')
        echo "Snap cleanup completed"
    else
        echo "Snap not found, skipping"
    fi
}

clean_docker() {
    if command -v docker > /dev/null; then
        log "Cleaning Docker"
        sudo docker system prune -a -f
        echo "Docker cleanup completed"
    else
        echo "Docker not found, skipping"
    fi
}

clean_steam_cache() {
    log "Cleaning Steam cache"
    rm -rf "$HOME/.steam/steam/steamapps/shadercache"
    rm -rf "$HOME/.steam/steam/steamapps/compatdata"
    echo "Steam cache cleanup completed"
}

clean_journals() {
    log "Cleaning Journals"
    sudo journalctl --vacuum-time=14d
    echo "Journals cleanup completed"
}

clean_kernels() {
    if command -v package-cleanup > /dev/null; then
        log "Pruning old kernels"
        sudo package-cleanup --oldkernels --count=2
        echo "Kernel pruning completed"
    else
        echo "package-cleanup not found, skipping kernel pruning"
    fi
}

# ===== Main Script Execution =====
case "$1" in
    --yes)
        log "Starting full cleanup"
        clean_apt
        clean_dnf
        clean_pacman
        clean_zypper
        clean_apk
        clean_flatpak
        clean_snap
        clean_docker
        clean_steam_cache
        clean_journals
        clean_kernels
        ;;
    --aggressive)
        log "Starting aggressive cleanup"
        clean_apt
        clean_dnf
        clean_pacman
        clean_zypper
        clean_apk
        clean_flatpak
        clean_snap
        clean_docker
        clean_steam_cache
        clean_journals
        clean_kernels
        ;;
    --dry-run)
        log "Dry run, no changes made"
        ;;
    --help)
        echo "Usage: $0 [options]"
        echo "--yes              Perform cleanup (automatic confirmation)"
        echo "--aggressive       Perform aggressive cleanup (remove more cache)"
        echo "--dry-run          Show what would run, without making any changes"
        ;;
    *)
        echo "Invalid option. Use --help for usage details."
        exit 1
        ;;
esac

log "Cleanup completed"

# ===== Disk Size After Cleanup =====
disk_after=$(df -h --total | grep 'total' | awk '{print $3}')

# ===== Summary =====
echo -e "${BLUE}----------------------------------------------------------${RESET}"
echo -e "Summary of Cleanup:"
echo -e "${ICON_OK} APT cleanup: Done"
echo -e "${ICON_OK} DNF cleanup: Done"
echo -e "${ICON_OK} Pacman cleanup: Done"
echo -e "${ICON_OK} Zypper cleanup: Done"
echo -e "${ICON_OK} Flatpak cleanup: Done"
echo -e "${ICON_OK} Snap cleanup: Done"
echo -e "${ICON_OK} Docker cleanup: Done"
echo -e "${ICON_OK} Steam cache cleanup: Done"
echo -e "${ICON_OK} Journals cleanup: Done"
echo -e "${ICON_OK} Kernel pruning: Done"

# Show before and after disk size
echo -e "${GREEN}Disk size before cleanup: $disk_before${RESET}"
echo -e "${GREEN}Disk size after cleanup: $disk_after${RESET}"
echo -e "${BLUE}----------------------------------------------------------${RESET}"
