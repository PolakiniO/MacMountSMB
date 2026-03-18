#!/usr/bin/env bash
set -euo pipefail

APP_NAME="mountsmb"
DEFAULT_INTERVAL=300
APP_SUPPORT_DIR="${HOME}/Library/Application Support/${APP_NAME}"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"

SERVER=""
SHARE=""
LABEL=""
INTERVAL="${DEFAULT_INTERVAL}"
LOAD_AGENT="false"
FORCE="false"
SMB_URL=""

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Installs a per-user SMB auto-mount runtime script and LaunchAgent.

Options:
  --server <server-or-ip>      SMB server host or IP
  --share <share-name>         SMB share name
  --label <launchd-label>      LaunchAgent label (example: com.example.mountsmb)
  --interval <seconds>         Check interval in seconds (default: 300)
  --smb-url <smb://server/share>
                               Optional shortcut that fills --server and --share
  --load                       Bootstrap the LaunchAgent after install
  --force                      Overwrite generated files without confirmation
  --help                       Show this help
USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

is_placeholder() {
  local value
  value="$(printf '%s' "$1" | /usr/bin/tr '[:upper:]' '[:lower:]')"
  case "$value" in
    ""|server_or_ip|share_name|your_username|com.example.mountsmb|changeme|replace_me)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

confirm() {
  local prompt="$1"
  local default_answer="$2"
  local reply=""

  if [[ ! -t 0 ]]; then
    [[ "$default_answer" == "y" ]]
    return
  fi

  while true; do
    if [[ "$default_answer" == "y" ]]; then
      read -r -p "$prompt [Y/n]: " reply
      reply="${reply:-Y}"
    else
      read -r -p "$prompt [y/N]: " reply
      reply="${reply:-N}"
    fi

    case "$(printf '%s' "$reply" | /usr/bin/tr '[:upper:]' '[:lower:]')" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

parse_smb_url() {
  local url="$1"
  [[ "$url" =~ ^smb://([^/]+)/(.+)$ ]] || fail "--smb-url must look like smb://SERVER/SHARE"
  SERVER="${BASH_REMATCH[1]}"
  SHARE="${BASH_REMATCH[2]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      [[ $# -ge 2 ]] || fail "Missing value for --server"
      SERVER="$2"
      shift 2
      ;;
    --share)
      [[ $# -ge 2 ]] || fail "Missing value for --share"
      SHARE="$2"
      shift 2
      ;;
    --label)
      [[ $# -ge 2 ]] || fail "Missing value for --label"
      LABEL="$2"
      shift 2
      ;;
    --interval)
      [[ $# -ge 2 ]] || fail "Missing value for --interval"
      INTERVAL="$2"
      shift 2
      ;;
    --smb-url)
      [[ $# -ge 2 ]] || fail "Missing value for --smb-url"
      SMB_URL="$2"
      shift 2
      ;;
    --load)
      LOAD_AGENT="true"
      shift
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
      fail "Unknown option: $1 (try --help)"
      ;;
  esac
done

if [[ -n "$SMB_URL" ]]; then
  parse_smb_url "$SMB_URL"
fi

if [[ -z "$SERVER" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "SMB server or IP: " SERVER
  else
    fail "Missing --server in non-interactive mode"
  fi
fi

if [[ -z "$SHARE" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "SMB share name: " SHARE
  else
    fail "Missing --share in non-interactive mode"
  fi
fi

if [[ -z "$LABEL" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "LaunchAgent label (example: com.example.mountsmb): " LABEL
  else
    fail "Missing --label in non-interactive mode"
  fi
fi

if [[ -z "$INTERVAL" || ! "$INTERVAL" =~ ^[0-9]+$ || "$INTERVAL" -lt 10 ]]; then
  if [[ -t 0 ]]; then
    while true; do
      read -r -p "Check interval in seconds (>=10) [${DEFAULT_INTERVAL}]: " INTERVAL
      INTERVAL="${INTERVAL:-$DEFAULT_INTERVAL}"
      [[ "$INTERVAL" =~ ^[0-9]+$ && "$INTERVAL" -ge 10 ]] && break
      echo "Please enter an integer >= 10."
    done
  else
    fail "--interval must be an integer >= 10"
  fi
fi

if is_placeholder "$SERVER" || is_placeholder "$SHARE" || is_placeholder "$LABEL"; then
  fail "Placeholder-like values detected. Provide real server/share/label values."
fi

if [[ "$LOAD_AGENT" != "true" && -t 0 ]]; then
  if confirm "Load LaunchAgent now after installation?" "y"; then
    LOAD_AGENT="true"
  fi
fi

mkdir -p "$APP_SUPPORT_DIR" "$LAUNCH_AGENTS_DIR" "$APP_SUPPORT_DIR/logs" "$APP_SUPPORT_DIR/state"

echo "Preparing installation for label: ${LABEL}"
echo "Target SMB share: smb://${SERVER}/${SHARE}"

SCRIPT_PATH="${APP_SUPPORT_DIR}/mountsmb-${LABEL}.sh"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"
LOG_OUT="${APP_SUPPORT_DIR}/logs/${LABEL}.out.log"
LOG_ERR="${APP_SUPPORT_DIR}/logs/${LABEL}.err.log"
META_PATH="${APP_SUPPORT_DIR}/install-meta-${LABEL}.conf"
STATE_PATH="${APP_SUPPORT_DIR}/state/${LABEL}.state"

if [[ -e "$SCRIPT_PATH" || -e "$PLIST_PATH" ]]; then
  if [[ "$FORCE" != "true" ]]; then
    if [[ -t 0 ]]; then
      if ! confirm "Generated files already exist for label ${LABEL}. Overwrite?" "n"; then
        echo "Install cancelled."
        exit 1
      fi
    else
      fail "Generated files already exist. Re-run with --force to overwrite."
    fi
  fi
fi

cat > "$SCRIPT_PATH" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail

SMB_SERVER=$(printf '%q' "$SERVER")
SMB_SHARE=$(printf '%q' "$SHARE")
SMB_URL="smb://\${SMB_SERVER}/\${SMB_SHARE}"
MOUNT_NEEDLE="@\${SMB_SERVER}/\${SMB_SHARE} on /Volumes/"
OPEN_DELAY_SECONDS=3
STATE_PATH=$(printf '%q' "$STATE_PATH")

record_state() {
  local result="\$1"
  local details="\$2"
  local now_epoch now_iso run_count tmp_state

  now_epoch="\$(date +%s)"
  now_iso="\$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  run_count=1

  if [[ -f "\$STATE_PATH" ]]; then
    # shellcheck disable=SC1090
    source "\$STATE_PATH"
    if [[ "\${RUN_COUNT:-}" =~ ^[0-9]+$ ]]; then
      run_count=\$((RUN_COUNT + 1))
    fi
  fi

  tmp_state="\${STATE_PATH}.tmp"
  cat > "\$tmp_state" <<STATE
RUN_COUNT=\${run_count}
LAST_RUN_EPOCH=\${now_epoch}
LAST_RUN_AT=\${now_iso}
LAST_RESULT=\${result}
LAST_DETAILS=\$(printf '%q' "\$details")
STATE
  mv "\$tmp_state" "\$STATE_PATH"
}

if /sbin/mount | /usr/bin/grep -Fq "\${MOUNT_NEEDLE}"; then
  record_state "already-mounted" "Share already mounted; no reconnect needed."
  exit 0
fi

/bin/sleep "\${OPEN_DELAY_SECONDS}"
/usr/bin/open "\${SMB_URL}"
record_state "reconnect-triggered" "Share missing; requested macOS to open \${SMB_URL}."
SCRIPT
chmod 700 "$SCRIPT_PATH"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SCRIPT_PATH}</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>${INTERVAL}</integer>

  <key>StandardOutPath</key>
  <string>${LOG_OUT}</string>

  <key>StandardErrorPath</key>
  <string>${LOG_ERR}</string>
</dict>
</plist>
PLIST

cat > "$META_PATH" <<META
LABEL=$(printf '%q' "$LABEL")
SERVER=$(printf '%q' "$SERVER")
SHARE=$(printf '%q' "$SHARE")
INTERVAL=$(printf '%q' "$INTERVAL")
SCRIPT_PATH=$(printf '%q' "$SCRIPT_PATH")
PLIST_PATH=$(printf '%q' "$PLIST_PATH")
LOG_OUT=$(printf '%q' "$LOG_OUT")
LOG_ERR=$(printf '%q' "$LOG_ERR")
STATE_PATH=$(printf '%q' "$STATE_PATH")
META
chmod 600 "$META_PATH"

if [[ "$LOAD_AGENT" == "true" ]]; then
  if command -v launchctl >/dev/null 2>&1; then
    launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
    if launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"; then
      echo "LaunchAgent loaded: ${LABEL}"
    else
      echo "Install succeeded but loading failed. Try manually:" >&2
      echo "launchctl bootstrap gui/$(id -u) \"${PLIST_PATH}\"" >&2
    fi
  else
    echo "Install succeeded, but launchctl is unavailable in this environment." >&2
  fi
else
  echo "Install succeeded (files only)."
  echo "Load manually with: launchctl bootstrap gui/$(id -u) \"${PLIST_PATH}\""
fi

echo ""
echo "✅ Setup complete for ${LABEL}."
echo "From now on, launchd will run this helper every ${INTERVAL} seconds to keep the share mounted when needed."
echo "If the share is not mounted, macOS will attempt to open smb://${SERVER}/${SHARE}."
echo "Runtime script: ${SCRIPT_PATH}"
echo "LaunchAgent plist: ${PLIST_PATH}"
echo "State file: ${STATE_PATH}"
echo "Logs: ${LOG_OUT}, ${LOG_ERR}"
echo "Check status with: ./status.sh --label ${LABEL}"
