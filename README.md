# macos_smb_reconnect

Bash script for macOS that automatically reconnects pre-defined SMB mounts when they drop.

## Setup

1. Copy `.env.example` to `.env` and fill in your credentials:

   ```bash
   cp .env.example .env
   ```

   ```
   SMB_USER=your_username
   SMB_PASS=your_password
   SMB_SERVER=your_server
   SMB_DRIVES=drive_1,drive_2,drive_3
   ```

2. Set `.env` permissions to owner-only (the script enforces this):

   ```bash
   chmod 600 .env
   ```

3. Make the script executable:

   ```bash
   chmod +x smb_reconnect.sh
   ```

## Scheduling

### launchd (recommended for macOS)

Create `~/Library/LaunchAgents/com.user.smb-reconnect.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.smb-reconnect</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/smb_reconnect.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>
</dict>
</plist>
```

Load with:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.smb-reconnect.plist
```

Unload with:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.smb-reconnect.plist
```

### crontab (alternative)

```bash
crontab -e
# Add: */15 * * * * /path/to/smb_reconnect.sh
```

## Logging

The script logs to the system log via `logger`. View logs with:

```bash
log show --predicate 'eventMessage contains "smb_reconnect"' --last 1h
```

## Security

- Never commit your `.env` file (it's in `.gitignore`)
- The `.env` file should be readable only by your user: `chmod 600 .env`
- For enhanced security, consider storing credentials in macOS Keychain and retrieving them with the `security` CLI
