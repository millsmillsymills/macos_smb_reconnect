# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Single-file Bash script (`smb_reconnect.sh`) that auto-reconnects macOS SMB mounts via `mount_smbfs`. Designed to run unattended on a 15-minute launchd/cron schedule.

## Linting and Formatting

```bash
shellcheck smb_reconnect.sh
shfmt -i 0 -d smb_reconnect.sh   # tabs, diff mode
shfmt -i 0 -w smb_reconnect.sh   # tabs, write mode
```

Both must pass with zero warnings before committing.

## Architecture

The script has three phases:

1. **Config loading** (`load_env`) -- Parses `.env` with an allowlisted `case` statement (no `source`/`eval`). Enforces `chmod 600` on the file. Accepts `SMB_USER`, `SMB_PASS`, `SMB_SERVER`, `SMB_DRIVES`.
2. **Credential encoding** (`urlencode`) -- Percent-encodes credentials for the SMB URL. ASCII-only; multi-byte UTF-8 is not supported.
3. **Mount loop** -- For each drive in `SMB_DRIVES`: checks `mount | grep -F` for existing mount, then calls `mount_smbfs` with encoded credentials. Drive names are validated against `^[a-zA-Z0-9._-]+$`.

## Security Constraints

- `.env` must be mode `600` -- the script refuses to run otherwise
- No `source`, `eval`, or `xargs` on untrusted input -- all parsing is pure bash
- `mount_smbfs` exposes credentials in process args (known limitation; Keychain integration is the long-term fix)
- Drive names are strictly validated to prevent path traversal
- Logs never include passwords -- only server/drive names

## macOS-Specific

- `stat -f '%Lp'` for permission checks (BSD stat, not GNU)
- `mount_smbfs` for SMB mounts (not `mount -t cifs`)
- `logger -t` for syslog; view with `log show --predicate 'eventMessage contains "smb_reconnect"'`
