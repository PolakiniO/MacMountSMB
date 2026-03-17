# macOS SMB Auto-Mount

Lightweight `launchd`-based template for reconnecting an SMB share on macOS after login, wake, or temporary network loss.

## Why This Exists

macOS can drop SMB mounts after sleep or network interruptions. Finder reconnect behavior is inconsistent, and login items alone are usually not enough for a reliable remount workflow.

This repository provides a small shell script and a LaunchAgent template that periodically checks whether an SMB share is mounted and reopens it only when needed.

## Features

- Uses `launchd`, the native macOS job scheduler
- Checks mount state before reconnecting
- Avoids hardcoded credentials in the repository
- Keeps logs in `/tmp` for simple troubleshooting
- Ships as editable templates for personal deployment

## Repository Structure

- `scripts/mountsmb.sh`
  Example shell script that checks whether the SMB share is already mounted.
- `launchd/com.example.mountsmb.plist`
  Example LaunchAgent template that runs the script every 5 minutes.
- `scripts/install-example.sh`
  Optional helper script that copies the LaunchAgent template into `~/Library/LaunchAgents`.

## Configuration

Before using this project, edit the placeholders in the template files.

In `scripts/mountsmb.sh`, update:

- `SMB_URL`
  Example: `smb://SERVER_OR_IP/SHARE_NAME`
- `MOUNT_MATCH_REGEX`
  Must match the SMB source shown by `/sbin/mount` after the share is connected
- `OPEN_DELAY_SECONDS`
  Optional startup delay before opening the SMB URL

In `launchd/com.example.mountsmb.plist`, update:

- `Label`
  Replace `com.example.mountsmb` with your own reverse-DNS style identifier
- `ProgramArguments`
  Replace `/Users/YOUR_USERNAME/path/to/mountsmb.sh` with the real path to your deployed script

## Installation And Setup

> Safety note: This setup only creates a user LaunchAgent (in `~/Library/LaunchAgents`) and does not require root access or modify system-wide launchd configuration.

1. Review and edit the placeholders in:
   - `scripts/mountsmb.sh`
   - `launchd/com.example.mountsmb.plist`
2. Copy the script to a location you control, for example:
   ```bash
   mkdir -p ~/bin
   cp scripts/mountsmb.sh ~/bin/mountsmb.sh
   chmod +x ~/bin/mountsmb.sh
   ```
3. Update the plist so `ProgramArguments` points to your deployed script path.
4. Mount the SMB share once manually in Finder or with:
   ```bash
   open "smb://SERVER_OR_IP/SHARE_NAME"
   ```
5. Save credentials to Keychain when prompted.
6. Copy the LaunchAgent into place:
   ```bash
   mkdir -p ~/Library/LaunchAgents
   cp launchd/com.example.mountsmb.plist ~/Library/LaunchAgents/
   ```
7. Load the LaunchAgent:
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.mountsmb.plist
   ```

## Usage And Testing

- Trigger the job manually:
  ```bash
  launchctl kickstart -k gui/$(id -u)/com.example.mountsmb
  ```
- Check whether the share is mounted:
  ```bash
  /sbin/mount | grep smbfs
  ```
- Unmount a share for testing if needed (**force unmount can interrupt open file operations**):
  ```bash
  diskutil unmount force /Volumes/SHARE_NAME
  ```

Note: macOS may mount the share under a different folder name than expected. The script intentionally checks the SMB source reported by `mount`, not only the local volume directory.


## Uninstall

To disable and remove the user LaunchAgent:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.example.mountsmb.plist
rm ~/Library/LaunchAgents/com.example.mountsmb.plist
```

## Troubleshooting

- Review logs:
  ```bash
  cat /tmp/mountsmb.out
  cat /tmp/mountsmb.err
  ```
- Inspect LaunchAgent state:
  ```bash
  launchctl print gui/$(id -u)/com.example.mountsmb
  ```
- Confirm your `MOUNT_MATCH_REGEX` matches the actual output from:
  ```bash
  /sbin/mount
  ```
- If the job loads but the share does not open, verify that:
  - the SMB URL is valid
  - credentials were saved in Keychain
  - the deployed script path in the plist is correct

## Security And Privacy

Do not commit passwords, Keychain exports, private hostnames, internal IP addresses, or personal usernames into this repository. Keep deployment-specific copies local and leave the tracked templates generic.

## License

MIT. See [LICENSE](LICENSE).
