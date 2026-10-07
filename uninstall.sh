#!/bin/bash
# synology-auto-mount uninstaller for macOS.
set -euo pipefail

LABEL="dev.mahingbun.synology-automount"
SCRIPT_PATH="$HOME/.local/bin/synology-automount.sh"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_PATH="$HOME/Library/Logs/synology-automount.log"

# Recover install parameters (for the optional keychain cleanup).
NAS_HOST=""; NAS_USER=""; NAS_SHARE=""
if [[ -f "$SCRIPT_PATH" ]]; then
    NAS_HOST=$(grep '^NAS_HOST=' "$SCRIPT_PATH" | cut -d'"' -f2 || true)
    NAS_SHARE=$(grep '^NAS_SHARE=' "$SCRIPT_PATH" | cut -d'"' -f2 || true)
    NAS_USER=$(grep '^NAS_USER=' "$SCRIPT_PATH" | cut -d'"' -f2 || true)
fi

launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
rm -f "$PLIST_PATH" "$SCRIPT_PATH"
echo "Removed LaunchAgent and watchdog script."

if [[ -n "${NAS_SHARE}" ]] && mount | grep -q " on /Volumes/${NAS_SHARE} (smbfs"; then
    read -rp "Unmount /Volumes/${NAS_SHARE} now? [y/N] " yn
    [[ "${yn:-n}" == "y" ]] && { diskutil unmount force "/Volumes/${NAS_SHARE}" >/dev/null 2>&1 || true; echo "Unmounted."; }
fi

if [[ -n "${NAS_HOST}" && -n "${NAS_USER}" ]]; then
    read -rp "Delete the keychain entry for ${NAS_USER}@${NAS_HOST}? [y/N] " yn
    if [[ "${yn:-n}" == "y" ]]; then
        security delete-internet-password -s "$NAS_HOST" -a "$NAS_USER" 2>/dev/null \
            && echo "Keychain entry deleted." \
            || echo "No keychain entry found (or already deleted)."
    fi
fi

rm -f "$LOG_PATH"
echo "Uninstall complete."
