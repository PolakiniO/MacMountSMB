#!/bin/zsh

set -eu

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}
SOURCE_PLIST="${REPO_ROOT}/launchd/com.example.mountsmb.plist"
TARGET_DIR="${HOME}/Library/LaunchAgents"
TARGET_PLIST="${TARGET_DIR}/com.example.mountsmb.plist"

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
/bin/cp "${SOURCE_PLIST}" "${TARGET_PLIST}"

cat <<EOF
Installed:
  ${TARGET_PLIST}

Next steps:
1. Confirm the copied plist points to your real script path.
2. Load it manually with:
   launchctl bootstrap gui/\$(id -u) "${TARGET_PLIST}"
3. Test it with:
   launchctl kickstart -k gui/\$(id -u)/YOUR_LABEL
EOF
