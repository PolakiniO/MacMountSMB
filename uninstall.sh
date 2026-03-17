#!/usr/bin/env bash
set -euo pipefail

APP_NAME="mountsmb"
APP_SUPPORT_DIR="${HOME}/Library/Application Support/${APP_NAME}"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"

LABEL=""
FORCE="false"

usage() {
  cat <<'USAGE'
Usage: ./uninstall.sh [options]

Removes a per-user SMB auto-mount install created by install.sh.

Options:
  --label <launchd-label>   LaunchAgent label to remove
  --force                   Remove without confirmation
  --help                    Show this help
USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local reply=""

  if [[ ! -t 0 ]]; then
    return 1
  fi

  while true; do
    read -r -p "$prompt [y/N]: " reply
    reply="${reply:-N}"
    case "${reply,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      [[ $# -ge 2 ]] || fail "Missing value for --label"
      LABEL="$2"
      shift 2
      ;;
    --force)
      FORCE="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

if [[ -z "$LABEL" ]]; then
  latest_meta=$(ls -1t "${APP_SUPPORT_DIR}"/install-meta-*.conf 2>/dev/null | head -n1 || true)
  if [[ -n "$latest_meta" ]]; then
    # shellcheck disable=SC1090
    source "$latest_meta"
    LABEL="${LABEL:-}"
  fi
fi

[[ -n "$LABEL" ]] || fail "Could not determine label. Pass --label explicitly."

SCRIPT_PATH="${APP_SUPPORT_DIR}/mountsmb-${LABEL}.sh"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"
META_PATH="${APP_SUPPORT_DIR}/install-meta-${LABEL}.conf"
LOG_OUT="${APP_SUPPORT_DIR}/logs/${LABEL}.out.log"
LOG_ERR="${APP_SUPPORT_DIR}/logs/${LABEL}.err.log"

if [[ "$FORCE" != "true" ]]; then
  if ! confirm "Remove LaunchAgent ${LABEL} and generated files?"; then
    echo "Uninstall cancelled."
    exit 0
  fi
fi

if command -v launchctl >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
fi

rm -f "$PLIST_PATH" "$SCRIPT_PATH" "$META_PATH" "$LOG_OUT" "$LOG_ERR"

echo "Removed LaunchAgent and generated files for label: ${LABEL}"
