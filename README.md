# MacMountSMB - macOS SMB Auto-Mount Utility

> Automatically reconnect SMB network drives on macOS.

Keep SMB shares mounted on macOS across sleep/wake, Wi‑Fi changes, and transient network drops.

MacMountSMB is a user-scope utility that uses a LaunchAgent and a generated shell script to reconnect SMB shares only when needed.

> No sudo required. No system daemons. Fully reversible.

## Why this exists

macOS can silently drop SMB mounts after sleep, Wi‑Fi roaming, or VPN/network changes. Finder can reconnect in some cases, but behavior can be inconsistent.

This project provides a small, transparent setup that runs in your user session and avoids system-wide changes.

## What this does

MacMountSMB performs lightweight, periodic SMB mount health checks in your user session.

- Uses `launchd` to run a recurring check for your target share.
- Reconnects automatically only when the SMB share is missing.
- Uses the system SMB handler (`open "smb://..."`) and Finder/Keychain for authentication.

## Key features

- User-scope only (no `sudo`, no system daemons).
- Reconnects only when the target share is missing.
- Uses `open "smb://..."` so Finder/Keychain handle authentication.
- Supports interactive install, flag-based install, and template/manual workflows.
- Safe uninstall flow for generated artifacts.

## Requirements

- macOS with `launchd` / `launchctl` (standard on macOS)
- SMB share reachable from your machine
- A user account with access to `~/Library/LaunchAgents`

## Quick start

From the repository root:

```bash
./install.sh
```

If required inputs are missing, the installer prompts for them.

## Installation

### Interactive

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

### Non-interactive (flags)

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

Using an SMB URL shortcut:

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

## What gets created

Generated runtime files are installed in user-safe locations:

- Runtime script: `~/Library/Application Support/mountsmb/mountsmb-<label>.sh`
- LaunchAgent plist: `~/Library/LaunchAgents/<label>.plist`
- Logs: `~/Library/Application Support/mountsmb/logs/<label>.out.log` and `.err.log`

The generated runtime script:

- Builds `smb://SERVER/SHARE`
- Checks existing mounts via `/sbin/mount`
- Uses a generated fixed-string mount check derived from your server/share inputs
- Calls `open "smb://SERVER/SHARE"` only if not mounted

You do **not** need to hand-edit `MOUNT_MATCH_REGEX`.

The generated LaunchAgent plist:

- Uses your requested label
- Runs on load and at your requested interval
- Points to your generated runtime script
- Writes logs to your user application-support directory

## How it works

- `install.sh` collects values (interactive or via flags).
- It generates a runtime script and a LaunchAgent plist.
- The LaunchAgent runs on load and at your chosen interval.
- The runtime script checks existing mounts and reconnects only if the share is missing.
- If you pass `--load` (or choose load interactively), the installer attempts:

  ```bash
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<label>.plist
  ```

- If you install without load, the installer prints the exact manual load command.

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

## Credentials and security notes

- This project does **not** store SMB credentials in repository files.
- Authentication is delegated to Finder/Keychain when macOS opens the SMB URL.
- The first successful interactive connection can store credentials in your user keychain, after which reconnects can happen without repeated prompts.
- User scope only: installs into your home directory.
- No `sudo` required.
- No system-wide LaunchDaemons are created.
- Existing generated files are not overwritten unless you confirm or pass `--force`.
- Keep personal hosts/IPs/usernames out of committed files.

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

## Repository structure

- `install.sh` – installer (interactive + flag-based modes)
- `uninstall.sh` – safe uninstaller
- `scripts/mountsmb.sh` – template example script (manual/template workflow)
- `scripts/install-example.sh` – template copy helper (legacy/template flow)
- `launchd/com.example.mountsmb.plist` – template LaunchAgent plist

## Template / advanced usage

The template-based manual workflow is still available when you want full control over naming, locations, or mount logic.

### 1) Copy templates into your own paths

```bash
mkdir -p "$HOME/.local/mountsmb" "$HOME/Library/LaunchAgents"
cp scripts/mountsmb.sh "$HOME/.local/mountsmb/work-share.sh"
cp launchd/com.example.mountsmb.plist "$HOME/Library/LaunchAgents/com.acme.work-share.mountsmb.plist"
```

### 2) Edit your mount script

Open `~/.local/mountsmb/work-share.sh` and set your target SMB URL and match logic.

Example customization:

```bash
SMB_URL="smb://fileserver.local/Engineering"
MOUNT_MATCH_REGEX='//[^@]+@fileserver\.local/Engineering on '
```

Then make the script executable:

```bash
chmod +x "$HOME/.local/mountsmb/work-share.sh"
```

### 3) Edit your LaunchAgent plist

Update at least these keys in `~/Library/LaunchAgents/com.acme.work-share.mountsmb.plist`:

- `Label` (must be unique, e.g. `com.acme.work-share.mountsmb`)
- `ProgramArguments` (point to your custom script path)
- `StartInterval` (example: `120` for every 2 minutes)
- `StandardOutPath` and `StandardErrorPath` (optional but strongly recommended)

### 4) Validate and load

```bash
plutil -lint "$HOME/Library/LaunchAgents/com.acme.work-share.mountsmb.plist"
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/com.acme.work-share.mountsmb.plist"
launchctl kickstart -k gui/$(id -u)/com.acme.work-share.mountsmb
```

### 5) Verify behavior

```bash
launchctl print gui/$(id -u)/com.acme.work-share.mountsmb
tail -f "$HOME/Library/Application Support/mountsmb/logs/com.acme.work-share.mountsmb.out.log"
```

Custom deployment examples:

- **Fast retry for unstable Wi‑Fi**: set `StartInterval` to `45` (more frequent checks).
- **Quiet office profile**: set `StartInterval` to `300` (lower background activity).
- **Multiple shares**: use one script + one LaunchAgent plist per share (for example `com.acme.mountsmb.design` and `com.acme.mountsmb.finance`) to isolate failures and tune intervals/logs per share.

## License

MIT. See [LICENSE](LICENSE).
