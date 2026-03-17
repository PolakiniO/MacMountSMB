# MacMountSMB - macOS SMB Auto-Mount Utility

A user-scope macOS utility that keeps an SMB share connected after sleep/wake and transient network drops.

This project uses a **LaunchAgent** plus a generated shell script that periodically checks whether your share is mounted and reconnects only when needed.

## Why this exists

macOS can silently drop SMB mounts after sleep, Wi‑Fi roaming, or VPN/network changes. Finder can reconnect in some cases, but behavior can be inconsistent.

This utility gives you a small, transparent, and local setup that:

- Runs in your own user session (no sudo, no system daemons).
- Reconnects only if the target share is missing.
- Uses `open "smb://..."` so Finder/Keychain handle credentials.

## Supported environment

- macOS with `launchd` / `launchctl` (standard on macOS)
- SMB share reachable from your machine
- A user account with access to `~/Library/LaunchAgents`

## Repository layout

- `install.sh` – real installer (interactive + flag-based modes)
- `uninstall.sh` – safe uninstaller
- `scripts/mountsmb.sh` – template example script (kept for manual/template workflow)
- `scripts/install-example.sh` – template copy helper (legacy/template flow)
- `launchd/com.example.mountsmb.plist` – template LaunchAgent plist

## Quick start (recommended)

Run the installer from the repository root:

```bash
./install.sh
```

If you do not pass all required flags, the installer prompts for the missing values.

Generated runtime files are installed in user-safe locations:

- Runtime script: `~/Library/Application Support/mountsmb/mountsmb-<label>.sh`
- LaunchAgent plist: `~/Library/LaunchAgents/<label>.plist`
- Logs: `~/Library/Application Support/mountsmb/logs/<label>.out.log` and `.err.log`

## Interactive install example

```bash
./install.sh
```

You will be prompted for:

- SMB server or IP
- SMB share name
- LaunchAgent label
- Check interval (seconds)
- Whether to auto-load the LaunchAgent
- Whether to overwrite existing generated files

## Flag-based install example

Fully non-interactive install + load:

```bash
./install.sh \
  --server SERVER_OR_IP \
  --share SHARE_NAME \
  --label com.example.mountsmb \
  --interval 300 \
  --load \
  --force
```

Or use an SMB URL shortcut:

```bash
./install.sh --smb-url "smb://SERVER_OR_IP/SHARE_NAME" --label com.example.mountsmb --interval 300 --load
```

### Installer flags

- `--server <server-or-ip>`
- `--share <share-name>`
- `--label <launchd-label>`
- `--interval <seconds>`
- `--smb-url <smb://server/share>`
- `--load`
- `--force`
- `--help`

## What the installer generates

### Runtime mount script

The generated script:

- Builds `smb://SERVER/SHARE`
- Checks existing mounts via `/sbin/mount`
- Uses a generated fixed-string mount check derived from your server/share inputs
- Calls `open "smb://SERVER/SHARE"` only if not mounted

You do **not** need to hand-edit `MOUNT_MATCH_REGEX`.

### LaunchAgent plist

The generated plist:

- Uses your requested label
- Runs on load and at your requested interval
- Points to your generated runtime script
- Writes logs to your user application-support directory

## Loading behavior

If you choose load during install (or pass `--load`), installer attempts:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<label>.plist
```

If you install without load, the installer prints the exact manual load command.

## Uninstall

Interactive/safe uninstall:

```bash
./uninstall.sh --label com.example.mountsmb
```

Force uninstall without prompt:

```bash
./uninstall.sh --label com.example.mountsmb --force
```

`uninstall.sh` will:

- Attempt to unload the LaunchAgent (`launchctl bootout`)
- Remove the generated plist
- Remove the generated runtime script
- Remove installer metadata/log files for that label

## Credentials and Keychain

This project does **not** store SMB credentials in repository files.

Authentication is delegated to Finder/Keychain when macOS opens the SMB URL. The first successful interactive connection can store credentials in your user keychain, after which reconnects can happen without repeated prompts.

## Troubleshooting

Check LaunchAgent status:

```bash
launchctl print gui/$(id -u)/<label>
```

Trigger a run immediately:

```bash
launchctl kickstart -k gui/$(id -u)/<label>
```

View logs:

```bash
cat "$HOME/Library/Application Support/mountsmb/logs/<label>.out.log"
cat "$HOME/Library/Application Support/mountsmb/logs/<label>.err.log"
```

If reconnects fail:

- Confirm `smb://SERVER/SHARE` is correct
- Ensure the share is reachable on your current network
- Verify credentials are saved and valid in Keychain
- Run the generated runtime script manually to inspect immediate behavior

## Safety and privacy notes

- User scope only: installs into your home directory.
- No `sudo` required.
- No system-wide LaunchDaemons are created.
- Existing generated files are not overwritten unless you confirm or pass `--force`.
- Keep personal hosts/IPs/usernames out of committed files.

## Template workflow (still available)

The original template-based approach is still present:

- `scripts/mountsmb.sh`
- `launchd/com.example.mountsmb.plist`
- `scripts/install-example.sh`

Use these if you prefer manual editing and custom deployment.

## License

MIT. See [LICENSE](LICENSE).
