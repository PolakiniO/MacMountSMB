#!/bin/zsh

set -eu

# Example SMB auto-mount script for macOS.
# Replace the values below with your own server and share details before use.

SMB_URL="smb://SERVER_OR_IP/SHARE_NAME"

# Match the SMB source shown by `mount` after authentication, for example:
# '^//.*@SERVER_OR_IP/SHARE_NAME on /Volumes/'
MOUNT_MATCH_REGEX='^//.*@SERVER_OR_IP/SHARE_NAME on /Volumes/'

# Optional delay to give networking and login services time to settle.
OPEN_DELAY_SECONDS=5

if /sbin/mount | /usr/bin/grep -qE "$MOUNT_MATCH_REGEX"; then
  exit 0
fi

/bin/sleep "$OPEN_DELAY_SECONDS"
/usr/bin/open "$SMB_URL"
