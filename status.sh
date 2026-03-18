#!/usr/bin/env bash
set -euo pipefail

APP_NAME="mountsmb"
APP_SUPPORT_DIR="${HOME}/Library/Application Support/${APP_NAME}"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"

LABEL=""

usage() {
  cat <<'USAGE'
Usage: ./status.sh [options]

Shows the current MacMountSMB configuration and runtime status for one label.

Options:
  --label <launchd-label>   LaunchAgent label to inspect
  --help                    Show this help
USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

resolve_label() {
  if [[ -n "$LABEL" ]]; then
    return
  fi

  local latest_meta
  latest_meta=$(find "$APP_SUPPORT_DIR" -maxdepth 1 -name 'install-meta-*.conf' -type f -print 2>/dev/null | sort | tail -n1 || true)
  if [[ -n "$latest_meta" ]]; then
    # shellcheck disable=SC1090
    source "$latest_meta"
    LABEL="${LABEL:-}"
  fi
}

format_epoch_utc() {
  local epoch="$1"
  if [[ -z "$epoch" || ! "$epoch" =~ ^[0-9]+$ ]]; then
    echo "unknown"
    return
  fi
  date -u -r "$epoch" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "unknown"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      [[ $# -ge 2 ]] || fail "Missing value for --label"
      LABEL="$2"
      shift 2
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

resolve_label
[[ -n "$LABEL" ]] || fail "Could not determine label. Pass --label explicitly."

META_PATH="${APP_SUPPORT_DIR}/install-meta-${LABEL}.conf"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"

[[ -f "$META_PATH" ]] || fail "No installation metadata found for label ${LABEL}."
# shellcheck disable=SC1090
source "$META_PATH"

RUN_COUNT=0
LAST_RUN_EPOCH=""
LAST_RUN_AT="never"
LAST_RESULT="never-run"
LAST_DETAILS="No recorded runs yet."

if [[ -n "${STATE_PATH:-}" && -f "$STATE_PATH" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_PATH"
fi

AGENT_STATUS="not loaded"
LAUNCHCTL_SUMMARY="launchctl not available"
if command -v launchctl >/dev/null 2>&1; then
  if launchctl print "gui/$(id -u)/${LABEL}" >/tmp/mountsmb-status-launchctl.$$ 2>&1; then
    AGENT_STATUS="loaded"
    LAUNCHCTL_SUMMARY=$(sed -n '1,12p' /tmp/mountsmb-status-launchctl.$$)
  else
    LAUNCHCTL_SUMMARY=$(cat /tmp/mountsmb-status-launchctl.$$)
  fi
  rm -f /tmp/mountsmb-status-launchctl.$$
fi

NEXT_RUN="unknown"
if [[ "$AGENT_STATUS" == "loaded" && "${INTERVAL:-}" =~ ^[0-9]+$ && "${LAST_RUN_EPOCH:-}" =~ ^[0-9]+$ ]]; then
  NEXT_RUN=$(format_epoch_utc "$((LAST_RUN_EPOCH + INTERVAL))")
fi

OUT_LOG_TAIL="(log file not found)"
ERR_LOG_TAIL="(log file not found)"
if [[ -f "$LOG_OUT" ]]; then
  OUT_LOG_TAIL=$(tail -n 5 "$LOG_OUT")
fi
if [[ -f "$LOG_ERR" ]]; then
  ERR_LOG_TAIL=$(tail -n 5 "$LOG_ERR")
fi

cat <<STATUS
MacMountSMB status
==================
Label:              ${LABEL}
Configured share:   smb://${SERVER}/${SHARE}
Check interval:     ${INTERVAL} seconds
Runtime script:     ${SCRIPT_PATH}
LaunchAgent plist:  ${PLIST_PATH}
State file:         ${STATE_PATH}
Stdout log:         ${LOG_OUT}
Stderr log:         ${LOG_ERR}

LaunchAgent
-----------
Status:             ${AGENT_STATUS}

Run history
-----------
Run count:          ${RUN_COUNT}
Last run:           ${LAST_RUN_AT}
Last run (UTC):     $(format_epoch_utc "${LAST_RUN_EPOCH:-}")
Last result:        ${LAST_RESULT}
Last details:       ${LAST_DETAILS}
Next run (estimate): ${NEXT_RUN}

launchctl summary
-----------------
${LAUNCHCTL_SUMMARY}

stdout log tail
---------------
${OUT_LOG_TAIL}

stderr log tail
---------------
${ERR_LOG_TAIL}
STATUS
