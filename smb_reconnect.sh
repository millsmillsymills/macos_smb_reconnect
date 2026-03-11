#!/bin/bash
set -euo pipefail

LOG_TAG="smb_reconnect"

# Load credentials from environment or .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
	# shellcheck source=/dev/null
	source "${SCRIPT_DIR}/.env"
fi

if [[ -z "${SMB_USER:-}" || -z "${SMB_PASS:-}" || -z "${SMB_SERVER:-}" ]]; then
	logger -t "${LOG_TAG}" "ERROR: SMB_USER, SMB_PASS, and SMB_SERVER must be set in environment or .env file"
	exit 1
fi

network_drives=('drive_1' 'drive_2' 'drive_3')

for drive in "${network_drives[@]}"; do
	if mount | grep -q "/Volumes/${drive}"; then
		logger -t "${LOG_TAG}" "Already mounted: ${drive}"
		continue
	fi

	if open "smb://${SMB_USER}:${SMB_PASS}@${SMB_SERVER}/${drive}" 2>/dev/null; then
		# Give Finder a moment to process the mount
		sleep 2
		if mount | grep -q "/Volumes/${drive}"; then
			logger -t "${LOG_TAG}" "Mounted: ${drive}"
		else
			logger -t "${LOG_TAG}" "WARNING: open returned success but ${drive} not found in /Volumes"
		fi
	else
		logger -t "${LOG_TAG}" "ERROR: Failed to open smb://${SMB_SERVER}/${drive}"
	fi
done
