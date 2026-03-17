#!/bin/zsh

set -eu

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}
SOURCE_PLIST="${REPO_ROOT}/launchd/com.example.mountsmb.plist"
TARGET_DIR="${HOME}/Library/LaunchAgents"
TARGET_PLIST="${TARGET_DIR}/com.example.mountsmb.plist"
FORCE_OVERWRITE=0

if [[ $# -gt 1 ]]; then
    echo "Usage: zsh scripts/install-example.sh [--force]" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    case "$1" in
        --force)
            FORCE_OVERWRITE=1
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: zsh scripts/install-example.sh [--force]" >&2
            exit 1
            ;;
    esac
fi

cat <<'EOF'
Example installer for the macOS SMB Auto-Mount templates.

Before continuing, make sure you have edited all placeholder values in:
- scripts/mountsmb.sh
- launchd/com.example.mountsmb.plist

This script only copies the plist template into ~/Library/LaunchAgents.
It does not load the agent, modify system files, or overwrite your shell script.
EOF

if /bin/grep -R -n -E 'YOUR_USERNAME|SERVER_OR_IP|SHARE_NAME|com\.example\.mountsmb' \
    "${REPO_ROOT}/scripts/mountsmb.sh" "${SOURCE_PLIST}" >/dev/null 2>&1; then
    echo "Placeholders are still present. Edit the templates before using this installer." >&2
    exit 1
fi

/bin/mkdir -p "${TARGET_DIR}"

if [[ -e "${TARGET_PLIST}" && "${FORCE_OVERWRITE}" -ne 1 ]]; then
    cat <<EOF >&2
LaunchAgent already exists:
  ${TARGET_PLIST}

Nothing was changed.
Review the existing file before replacing it.
If you really want to overwrite it with the example template, run:
  zsh scripts/install-example.sh --force
EOF
    exit 1
fi

/bin/cp "${SOURCE_PLIST}" "${TARGET_PLIST}"

cat <<EOF
Installed:
  ${TARGET_PLIST}

Next steps:
1. Confirm the copied plist points to your real script path.
2. Confirm the plist Label matches the label you plan to use with launchctl.
3. Create the log directory if needed:
   mkdir -p "${HOME}/Library/Logs"
4. Load it manually with:
   launchctl bootstrap gui/\$(id -u) "${TARGET_PLIST}"
5. Test it with the same label value from the plist, for example:
   launchctl kickstart -k gui/\$(id -u)/com.example.mountsmb
EOF
