#!/usr/bin/env bash
# ==============================================================================
# LUMON INDUSTRIES TERMINAL - LIMINE BOOTLOADER THEME UNINSTALLER
# ==============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"

CYAN='\033[38;2;143;226;255m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

if [[ $EUID -ne 0 ]]; then
  echo -e "${YELLOW}[!] Root privileges required to access /boot.${RESET}"
  exec sudo bash "$0" "$@"
fi

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
  find /boot /efi -type f -name "limine.conf" 2>/dev/null | head -n 1 || true
}

CONF_PATH=$(find_limine_conf)
if [[ -z "$CONF_PATH" || ! -f "$CONF_PATH" ]]; then
  echo -e "${RED}[ERROR] limine.conf could not be found.${RESET}"
  exit 1
fi

BOOT_ROOT="$(dirname "$CONF_PATH")"
THEME_DIR="$BOOT_ROOT/lumon-limine-theme"

echo -e "${CYAN}[*] Target config:${RESET} $CONF_PATH"

# Check for recent backup
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/limine.conf.bak_* 2>/dev/null | head -n 1 || true)

if [[ -n "$LATEST_BACKUP" && -f "$LATEST_BACKUP" ]]; then
  echo -e "${YELLOW}[?] Found backup: $LATEST_BACKUP${RESET}"
  read -rp "Restore this backup directly? [Y/n]: " choice
  choice=${choice:-Y}
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    cp "$LATEST_BACKUP" "$CONF_PATH"
    echo -e "${GREEN}[+] Restored backup to $CONF_PATH${RESET}"
  else
    # Strip managed block
    TMP=$(mktemp)
    awk '
      /# BEGIN lumon-limine-theme/ { in_block=1; next }
      /# END lumon-limine-theme/ { in_block=0; next }
      !in_block { print }
    ' "$CONF_PATH" > "$TMP"
    mv "$TMP" "$CONF_PATH"
    echo -e "${GREEN}[+] Removed Lumon theme block from $CONF_PATH${RESET}"
  fi
else
  TMP=$(mktemp)
  awk '
    /# BEGIN lumon-limine-theme/ { in_block=1; next }
    /# END lumon-limine-theme/ { in_block=0; next }
    !in_block { print }
  ' "$CONF_PATH" > "$TMP"
  mv "$TMP" "$CONF_PATH"
  echo -e "${GREEN}[+] Removed Lumon theme block from $CONF_PATH${RESET}"
fi

# Remove copied theme assets
if [[ -d "$THEME_DIR" ]]; then
  rm -rf "$THEME_DIR"
  echo -e "${GREEN}[+] Removed theme directory:${RESET} $THEME_DIR"
fi

# Re-enroll config if required
if command -v limine-enroll-config >/dev/null 2>&1; then
  limine-enroll-config || true
  echo -e "${GREEN}[+] Limine config re-enrolled.${RESET}"
fi

echo -e "${GREEN}[+] Lumon Limine theme uninstalled successfully.${RESET}\n"
