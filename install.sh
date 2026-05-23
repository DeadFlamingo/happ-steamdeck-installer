#!/usr/bin/env bash
#
# Happ Desktop Installer
# https://github.com/DeadFlamingo/happ-steamdeck-installer
#
# Supported systems:
#   - SteamOS / Steam Deck
#   - Bazzite, ChimeraOS, Nobara
#   - Arch Linux and other rolling distros
#   - Immutable / read-only root filesystems (no sudo required)
#
# Installs Happ Desktop into ~/.local (XDG user prefix).

set -Eeuo pipefail

INSTALLER_VERSION="1.0.0"
UPSTREAM_REPO="Happ-proxy/happ-desktop"
LATEST_API="https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest"

PREFIX="${HOME}/.local"
BIN_DIR="${PREFIX}/bin"
APP_DIR="${PREFIX}/share/applications"
ICON_DIR="${PREFIX}/share/icons/hicolor/256x256/apps"
MARKER_FILE="${PREFIX}/share/happ-installer/installed.json"

TMP_DIR=""
STAGING_DIR=""

# --- output helpers ----------------------------------------------------------

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  C_GREEN='\033[0;32m'
  C_BLUE='\033[0;34m'
  C_YELLOW='\033[1;33m'
  C_RED='\033[0;31m'
  C_RESET='\033[0m'
else
  C_GREEN='' C_BLUE='' C_YELLOW='' C_RED='' C_RESET=''
fi

info()  { echo -e "${C_BLUE}==>${C_RESET} $*"; }
ok()    { echo -e "${C_GREEN}==>${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}warning:${C_RESET} $*" >&2; }
error() { echo -e "${C_RED}error:${C_RESET} $*" >&2; }

die() {
  error "$1"
  exit "${2:-1}"
}

# --- cleanup -----------------------------------------------------------------

cleanup() {
  local code=$?
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
  if [[ -n "${STAGING_DIR}" && -d "${STAGING_DIR}" ]]; then
    rm -rf "${STAGING_DIR}"
  fi
  return "${code}"
}

trap cleanup EXIT

# --- dependencies ------------------------------------------------------------

require_cmd() {
  local cmd=$1
  local hint=${2:-}
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    die "Required command not found: ${cmd}${hint:+ (${hint})}"
  fi
}

check_tar_zstd() {
  if tar --help 2>&1 | grep -q -- '--zstd'; then
    TAR_EXTRACT=(tar --zstd -xf)
    return 0
  fi
  if command -v bsdtar >/dev/null 2>&1; then
    TAR_EXTRACT=(bsdtar -xf)
    return 0
  fi
  die "Need GNU tar with zstd support or bsdtar to extract .pkg.tar.zst"
}

# --- architecture ------------------------------------------------------------

detect_arch() {
  local machine
  machine="$(uname -m)"
  case "${machine}" in
    x86_64|amd64)
      echo "x64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      die "Unsupported CPU architecture: ${machine} (supported: x86_64, aarch64)"
      ;;
  esac
}

# --- GitHub API (jq or python3) ----------------------------------------------

fetch_latest_json() {
  local json
  json="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: happ-steamdeck-installer/${INSTALLER_VERSION}" \
    "${LATEST_API}")" || die "Failed to fetch latest release from GitHub API"
  echo "${json}"
}

json_get_asset() {
  local json=$1
  local arch=$2
  local field=$3
  local pkg_name="Happ.linux.${arch}.pkg.tar.zst"

  if command -v jq >/dev/null 2>&1; then
    case "${field}" in
      url)
        echo "${json}" | jq -r --arg n "${pkg_name}" \
          '.assets[] | select(.name == $n) | .browser_download_url'
        ;;
      version)
        echo "${json}" | jq -r '.tag_name'
        ;;
    esac
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    local py_tmp
    py_tmp="$(mktemp "${TMPDIR:-/tmp}/happ-json.XXXXXX")"
    printf '%s' "${json}" > "${py_tmp}"
    python3 - "${py_tmp}" "${pkg_name}" "${field}" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
name = sys.argv[2]
field = sys.argv[3]
asset = next((a for a in data.get("assets", []) if a.get("name") == name), None)
if asset is None:
    sys.exit(1)
if field == "url":
    print(asset["browser_download_url"])
elif field == "version":
    print(data["tag_name"])
PY
    local py_status=$?
    rm -f "${py_tmp}"
    return "${py_status}"
  fi

  die "Install jq or python3 to read GitHub release metadata"
}

# --- install steps -----------------------------------------------------------

install_binary() {
  local src=$1
  install -Dm755 "${src}" "${BIN_DIR}/happ"
}

install_icon() {
  local src=$1
  mkdir -p "${ICON_DIR}"
  install -Dm644 "${src}" "${ICON_DIR}/happ.png"

  if command -v xdg-icon-resource >/dev/null 2>&1; then
    xdg-icon-resource install --novendor --size 256 "${ICON_DIR}/happ.png" happ 2>/dev/null || true
    xdg-icon-resource forceupdate 2>/dev/null || true
  fi
}

install_desktop_entry() {
  local src=$1
  local dest="${APP_DIR}/happ.desktop"
  local exec_path="${BIN_DIR}/happ"

  mkdir -p "${APP_DIR}"
  sed \
    -e "s|^Exec=.*|Exec=${exec_path}|" \
    -e "s|^Icon=.*|Icon=happ|" \
    "${src}" > "${dest}"

  if command -v xdg-desktop-menu >/dev/null 2>&1; then
    xdg-desktop-menu install --novendor "${dest}" 2>/dev/null || true
  fi

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APP_DIR}" 2>/dev/null || true
  fi
}

write_marker() {
  local version=$1
  mkdir -p "$(dirname "${MARKER_FILE}")"
  cat > "${MARKER_FILE}" <<EOF
{
  "installer_version": "${INSTALLER_VERSION}",
  "happ_version": "${version}",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prefix": "${PREFIX}"
}
EOF
}

main() {
  clear 2>/dev/null || true
  echo -e "${C_BLUE}=== Happ Desktop Installer v${INSTALLER_VERSION} ===${C_RESET}"
  echo

  require_cmd curl
  check_tar_zstd

  local arch pkg_url version archive_name archive_path
  arch="$(detect_arch)"
  archive_name="Happ.linux.${arch}.pkg.tar.zst"

  info "Detecting latest Happ release (${arch})..."
  local latest_json
  latest_json="$(fetch_latest_json)"

  pkg_url="$(json_get_asset "${latest_json}" "${arch}" url)" || true
  version="$(json_get_asset "${latest_json}" "${arch}" version)" || true

  if [[ -z "${pkg_url}" || "${pkg_url}" == "null" ]]; then
    die "Package not found in latest release: ${archive_name}"
  fi

  ok "Latest version: ${version}"

  TMP_DIR="$(mktemp -d "${HOME}/.cache/happ-installer.XXXXXX")"
  STAGING_DIR="${TMP_DIR}/staging"
  archive_path="${TMP_DIR}/${archive_name}"
  mkdir -p "${STAGING_DIR}" "${BIN_DIR}" "${APP_DIR}"

  info "[1/4] Downloading ${archive_name}..."
  curl -fsSL --progress-bar -o "${archive_path}" "${pkg_url}" \
    || die "Download failed"

  info "[2/4] Extracting package..."
  "${TAR_EXTRACT[@]}" "${archive_path}" -C "${STAGING_DIR}"

  local bin_src="${STAGING_DIR}/usr/bin/happ"
  local desktop_src="${STAGING_DIR}/usr/share/applications/happ.desktop"
  local icon_src="${STAGING_DIR}/usr/share/icons/hicolor/256x256/apps/happ.png"

  [[ -f "${bin_src}" ]] || die "Binary not found in package: usr/bin/happ"

  info "[3/4] Installing to ${PREFIX}..."
  install_binary "${bin_src}"

  if [[ -f "${icon_src}" ]]; then
    install_icon "${icon_src}"
  else
    warn "Icon not found in package; launcher may use a generic icon"
  fi

  if [[ -f "${desktop_src}" ]]; then
    install_desktop_entry "${desktop_src}"
  else
    warn "Desktop entry not found in package; create ~/.local/share/applications/happ.desktop manually"
  fi

  write_marker "${version}"

  info "[4/4] Finalizing..."
  ok "Happ ${version} installed successfully"
  echo
  echo "Next steps:"
  echo "  1. Open the application menu and find Happ (often under Internet)."
  echo "  2. Right-click Happ -> Add to Steam."
  echo "  3. Launch Happ from Gaming Mode on Steam Deck."
  echo
  echo "Compatible with SteamOS, Bazzite, ChimeraOS, and other immutable Linux systems."
  echo "No sudo was used. Files are in: ${PREFIX}"
  echo
  echo "To remove: curl -fsSL https://raw.githubusercontent.com/DeadFlamingo/happ-steamdeck-installer/main/uninstall.sh | bash"
}

main "$@"
