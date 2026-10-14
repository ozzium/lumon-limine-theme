#!/usr/bin/env bash
# ==============================================================================
# LUMON INDUSTRIES TERMINAL - LIMINE BOOTLOADER THEME INSTALLER
# Inspired by Severance (Macrodata Refinement Division)
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
THEME_NAME="lumon-limine-theme"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
BOOT_DIR=""
VARIANT="default" # "default" (terminal frame) or "login" (index.html screen)
DRY_RUN=0

# Colors for terminal output
CYAN='\033[38;2;143;226;255m'
NAVY='\033[38;2;9;33;58m'
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

print_banner() {
  clear 2>/dev/null || true
  echo -e "${CYAN}"
  echo '  ╔═══════════════════════════════════════════════════════════════════════════╗'
  echo '  ║   ██╗     ██╗   ██╗███╗   ███╗ ██████╗ ███╗   ██╗                         ║'
  echo '  ║   ██║     ██║   ██║████╗ ████║██╔═══██╗████╗  ██║                         ║'
  echo '  ║   ██║     ██║   ██║██╔████╔██║██║   ██║██╔██╗ ██║  INDUSTRIES             ║'
  echo '  ║   ██║     ██║   ██║██║╚██╔╝██║██║   ██║██║╚██╗██║                         ║'
  echo '  ║   ███████╗╚██████╔╝██║ ╚═╝ ██║╚██████╔╝██║ ╚████║  TERMINAL BOOT SYSTEM   ║'
  echo '  ║   ╚══════╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝                         ║'
  echo '  ║            MACRODATA REFINEMENT DIVISION  •  TERMINAL 04                  ║'
  echo '  ╚═══════════════════════════════════════════════════════════════════════════╝'
  echo -e "${RESET}"
  echo -e "${DIM}  \"The work is mysterious and important.\" — Kier Egan${RESET}\n"
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}[!] Root privileges required to access /boot.${RESET}"
    echo -e "${CYAN}[*] Elevating using sudo...${RESET}\n"
    exec sudo bash "$0" "$@"
  fi
}

find_limine_conf() {
  local candidates=(
    "/boot/limine.conf"
    "/boot/limine/limine.conf"
    "/boot/efi/limine.conf"
    "/boot/efi/limine/limine.conf"
    "/efi/limine.conf"
    "/efi/limine/limine.conf"
  )

  for path in "${candidates[@]}"; do
    if [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  # Fallback to searching /boot and /efi
  local found
  found=$(find /boot /efi -type f -name "limine.conf" 2>/dev/null | head -n 1 || true)
  if [[ -n "$found" ]]; then
    echo "$found"
    return 0
  fi

  return 1
}

usage() {
  cat <<EOF
Usage: sudo ./install.sh [OPTIONS]

Options:
  --variant <default|login>  Choose wallpaper variant:
                               'default' : Lumon terminal framed layout (Recommended)
                               'login'   : Direct index.html login terminal screenshot
  --boot-dir <PATH>          Explicitly specify path to directory containing limine.conf
  --dry-run                  Test installation steps without writing changes
  -h, --help                 Show this help message
EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant)
      VARIANT="$2"
      shift 2
      ;;
    --boot-dir)
      BOOT_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

check_root
print_banner

# Locate configuration
if [[ -n "$BOOT_DIR" && -f "$BOOT_DIR/limine.conf" ]]; then
  CONF_PATH="$BOOT_DIR/limine.conf"
else
  CONF_PATH=$(find_limine_conf || true)
fi

if [[ -z "$CONF_PATH" || ! -f "$CONF_PATH" ]]; then
  echo -e "${RED}[ERROR] limine.conf could not be found.${RESET}"
  echo "Please specify its location manually with: sudo $0 --boot-dir <directory>"
  exit 1
fi

BOOT_ROOT="$(dirname "$CONF_PATH")"
echo -e "${CYAN}[*] Target limine.conf:${RESET} $CONF_PATH"
echo -e "${CYAN}[*] Boot root directory:${RESET} $BOOT_ROOT"

# Select wallpaper source
WALLPAPER_SRC="$SCRIPT_DIR/wallpaper.png"
if [[ "$VARIANT" == "login" ]]; then
  WALLPAPER_SRC="$SCRIPT_DIR/wallpaper_login.png"
fi

if [[ ! -f "$WALLPAPER_SRC" ]]; then
  echo -e "${RED}[ERROR] Wallpaper file missing: $WALLPAPER_SRC${RESET}"
  exit 1
fi

DEST_THEME_DIR="$BOOT_ROOT/$THEME_NAME"
DEST_WALLPAPER="$DEST_THEME_DIR/wallpaper.png"

echo -e "${CYAN}[*] Selected variant:${RESET} $VARIANT ($(basename "$WALLPAPER_SRC"))"

if [[ $DRY_RUN -eq 1 ]]; then
  echo -e "${YELLOW}[DRY-RUN] Would create directory: $DEST_THEME_DIR${RESET}"
  echo -e "${YELLOW}[DRY-RUN] Would copy wallpaper to: $DEST_WALLPAPER${RESET}"
  echo -e "${YELLOW}[DRY-RUN] Would modify: $CONF_PATH${RESET}"
  exit 0
fi

# 1. Create backup
mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
BACKUP_PATH="$BACKUP_DIR/limine.conf.bak_$TIMESTAMP"
cp "$CONF_PATH" "$BACKUP_PATH"
echo -e "${GREEN}[+] Backup created:${RESET} $BACKUP_PATH"

# 2. Copy theme files
mkdir -p "$DEST_THEME_DIR"
cp "$WALLPAPER_SRC" "$DEST_WALLPAPER"
if [[ -f "$SCRIPT_DIR/VT323-Regular.ttf" ]]; then
  cp "$SCRIPT_DIR/VT323-Regular.ttf" "$DEST_THEME_DIR/"
fi
echo -e "${GREEN}[+] Theme assets copied to:${RESET} $DEST_THEME_DIR"

# Compute path relative to boot root for limine.conf
REL_WALLPAPER="boot():/$THEME_NAME/wallpaper.png"

# 3. Read base theme configuration
THEME_CONTENT=$(cat <<EOF
# BEGIN lumon-limine-theme
interface_resolution: 1920x1080
interface_branding: "LUMON INDUSTRIES // MACRODATA REFINEMENT DIVISION"
interface_branding_color: 8fe2ff
interface_help_color: 51869e
interface_help_color_bright: 8fe2ff
interface_help_hidden: no
wallpaper: $REL_WALLPAPER
wallpaper_style: stretched
term_margin: 240
term_margin_gradient: 16
term_background: 9909213a
term_background_bright: 1f4068
term_foreground: 8fe2ff
term_foreground_bright: c7f3ff
term_palette: 09213a;e06c75;98c379;e5c07b;61afef;c678dd;8fe2ff;abb2bf
term_palette_bright: 1e3a5f;ff7b86;b2e596;f6d68d;7dc5fd;db8aef;c7f3ff;ffffff
timeout: 10
default_entry: 1
remember_last_entry: yes
# END lumon-limine-theme
EOF
)

# 4. Update limine.conf
# Remove existing lumon theme block if present
TMP_CONF=$(mktemp)
awk '
  /# BEGIN lumon-limine-theme/ { in_block=1; next }
  /# END lumon-limine-theme/ { in_block=0; next }
  !in_block { print }
' "$CONF_PATH" > "$TMP_CONF"

# Strip conflicting standalone appearance lines from top of file to prevent overrides
# (Limine takes the last declared or conflicts if duplicate)
# We will inject the theme at the very top of limine.conf before any boot entries
FIRST_ENTRY_LINE=$(grep -n -E "^/|^[[:space:]]*:[[:space:]]*" "$TMP_CONF" | head -n 1 | cut -d: -f1 || true)

TMP_OUT=$(mktemp)
if [[ -n "$FIRST_ENTRY_LINE" && "$FIRST_ENTRY_LINE" -gt 1 ]]; then
  # Split header and entries
  head -n "$((FIRST_ENTRY_LINE - 1))" "$TMP_CONF" | grep -v -E "^(interface_resolution|interface_branding|interface_branding_color|interface_help_color|interface_help_color_bright|interface_help_hidden|wallpaper|wallpaper_style|term_margin|term_margin_gradient|term_background|term_background_bright|term_foreground|term_foreground_bright|term_palette|term_palette_bright):" > "$TMP_OUT" || true
  echo "$THEME_CONTENT" >> "$TMP_OUT"
  tail -n "+$FIRST_ENTRY_LINE" "$TMP_CONF" >> "$TMP_OUT"
else
  echo "$THEME_CONTENT" > "$TMP_OUT"
  cat "$TMP_CONF" >> "$TMP_OUT"
fi

mv "$TMP_OUT" "$CONF_PATH"
rm -f "$TMP_CONF"
echo -e "${GREEN}[+] limine.conf successfully updated with Lumon theme!${RESET}"

# 5. Check if Omarchy/Arch requires limine-enroll-config
if command -v limine-enroll-config >/dev/null 2>&1; then
  echo -e "${CYAN}[*] Running limine-enroll-config to sync integrity checksums...${RESET}"
  limine-enroll-config || true
  echo -e "${GREEN}[+] Limine config enrolled successfully.${RESET}"
fi

echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}LUMON INDUSTRIES LIMINE THEME SUCCESSFULLY INSTALLED!${RESET}"
echo -e "You can reboot your workstation to experience the new Macrodata Refinement terminal."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${RESET}\n"
