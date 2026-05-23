#!/usr/bin/env bash
#
# Happ Desktop uninstaller (user install in ~/.local)

set -Eeuo pipefail

INSTALLER_VERSION="1.0.2"
PREFIX="${HOME}/.local"
BIN_PATH="${PREFIX}/bin/happ"
DESKTOP_PATH="${PREFIX}/share/applications/happ.desktop"
ICON_PATH="${PREFIX}/share/icons/hicolor/256x256/apps/happ.png"
MARKER_DIR="${PREFIX}/share/happ-installer"
HAPP_OPT_DIR="${PREFIX}/opt/happ"

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  C_GREEN='\033[0;32m'
  C_BLUE='\033[0;34m'
  C_RESET='\033[0m'
else
  C_GREEN='' C_BLUE='' C_RESET=''
fi

info() { echo -e "${C_BLUE}==>${C_RESET} $*"; }
ok()   { echo -e "${C_GREEN}==>${C_RESET} $*"; }

echo -e "${C_BLUE}=== Happ Desktop Uninstaller v${INSTALLER_VERSION} ===${C_RESET}"
echo

removed=0

if [[ -f "${BIN_PATH}" || -L "${BIN_PATH}" ]]; then
  rm -f "${BIN_PATH}"
  removed=1
  info "Removed ${BIN_PATH}"
fi

if [[ -d "${HAPP_OPT_DIR}" ]]; then
  rm -rf "${HAPP_OPT_DIR}"
  removed=1
  info "Removed ${HAPP_OPT_DIR}"
  rmdir "${PREFIX}/opt" 2>/dev/null || true
fi

if [[ -f "${DESKTOP_PATH}" ]]; then
  if command -v xdg-desktop-menu >/dev/null 2>&1; then
    xdg-desktop-menu uninstall --novendor happ.desktop 2>/dev/null || true
  fi
  rm -f "${DESKTOP_PATH}"
  removed=1
  info "Removed ${DESKTOP_PATH}"
fi

while IFS= read -r -d '' icon_file; do
  rm -f "${icon_file}"
  removed=1
  info "Removed ${icon_file}"
done < <(find "${PREFIX}/share/icons" -type f -name 'happ.png' -print0 2>/dev/null)

if command -v xdg-icon-resource >/dev/null 2>&1; then
  xdg-icon-resource uninstall --novendor --size 256 happ 2>/dev/null || true
  xdg-icon-resource forceupdate 2>/dev/null || true
fi

if [[ -d "${MARKER_DIR}" ]]; then
  rm -rf "${MARKER_DIR}"
  removed=1
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${PREFIX}/share/applications" 2>/dev/null || true
fi

if [[ "${removed}" -eq 0 ]]; then
  echo "Nothing to remove — Happ does not appear to be installed in ${PREFIX}"
  exit 0
fi

ok "Happ removed successfully"
