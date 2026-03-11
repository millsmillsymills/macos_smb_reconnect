#!/bin/bash
set -euo pipefail

LOG_TAG="smb_reconnect"

# Percent-encode special characters for SMB URLs (RFC 3986)
urlencode() {
	local string="$1"
	local length=${#string}
	local encoded=""
	local c
	for ((i = 0; i < length; i++)); do
		c="${string:i:1}"
		case "$c" in
		[a-zA-Z0-9.~_-]) encoded+="$c" ;;
		*) encoded+=$(printf '%%%02X' "'$c") ;;
		esac
	done
	printf '%s' "$encoded"
}

# Safe .env parser: only allows known variables, no arbitrary code execution
load_env() {
	local env_file="$1"
	if [[ ! -f "$env_file" ]]; then
		return 1
	fi

	local perms
	perms="$(stat -f '%Lp' "$env_file")"
	if [[ "$perms" != "600" ]]; then
		logger -t "${LOG_TAG}" "ERROR: ${env_file} has permissions ${perms}, expected 600"
		exit 1
	fi

	while IFS='=' read -r key value || [[ -n "$key" ]]; do
		# Skip blank lines and comments
		[[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
		# Trim leading/trailing whitespace (pure bash, no xargs)
		key="${key#"${key%%[![:space:]]*}"}"
		key="${key%"${key##*[![:space:]]}"}"
		value="${value#"${value%%[![:space:]]*}"}"
		value="${value%"${value##*[![:space:]]}"}"
		# Strip matching surrounding quotes from value
		if [[ "$value" =~ ^\"(.*)\"$ ]]; then
			value="${BASH_REMATCH[1]}"
		elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
			value="${BASH_REMATCH[1]}"
		fi
		case "$key" in
		SMB_USER) SMB_USER="$value" ;;
		SMB_PASS) SMB_PASS="$value" ;;
		SMB_SERVER) SMB_SERVER="$value" ;;
		SMB_DRIVES) SMB_DRIVES="$value" ;;
		*) logger -t "${LOG_TAG}" "WARNING: Ignoring unknown .env key: ${key}" ;;
		esac
	done <"$env_file"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
load_env "${SCRIPT_DIR}/.env" || true

if [[ -z "${SMB_USER:-}" || -z "${SMB_PASS:-}" || -z "${SMB_SERVER:-}" ]]; then
	logger -t "${LOG_TAG}" "ERROR: SMB_USER, SMB_PASS, and SMB_SERVER must be set in environment or .env file"
	exit 1
fi

if [[ -z "${SMB_DRIVES:-}" ]]; then
	logger -t "${LOG_TAG}" "ERROR: SMB_DRIVES must be set in environment or .env file (comma-separated)"
	exit 1
fi

IFS=',' read -ra network_drives <<<"${SMB_DRIVES}"

encoded_user="$(urlencode "$SMB_USER")"
encoded_pass="$(urlencode "$SMB_PASS")"

for drive in "${network_drives[@]}"; do
	# Trim whitespace from drive name (pure bash)
	drive="${drive#"${drive%%[![:space:]]*}"}"
	drive="${drive%"${drive##*[![:space:]]}"}"

	# Validate drive name: alphanumeric, dots, hyphens, underscores only
	if [[ ! "$drive" =~ ^[a-zA-Z0-9._-]+$ ]]; then
		logger -t "${LOG_TAG}" "ERROR: Invalid drive name: ${drive}"
		continue
	fi

	if mount | grep -Fq " on /Volumes/${drive} "; then
		logger -t "${LOG_TAG}" "Already mounted: ${drive}"
		continue
	fi

	mkdir -p "/Volumes/${drive}"

	# Note: credentials briefly visible in process args (known limitation without Keychain)
	if mount_smbfs "//${encoded_user}:${encoded_pass}@${SMB_SERVER}/${drive}" "/Volumes/${drive}"; then
		if mount | grep -Fq " on /Volumes/${drive} "; then
			logger -t "${LOG_TAG}" "Mounted: ${drive}"
		else
			logger -t "${LOG_TAG}" "WARNING: mount_smbfs returned success but ${drive} not found in mount table"
		fi
	else
		logger -t "${LOG_TAG}" "ERROR: Failed to mount smb://${SMB_SERVER}/${drive}"
	fi
done
