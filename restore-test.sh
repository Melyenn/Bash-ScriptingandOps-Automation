#!/usr/bin/env bash
set -euo pipefail

# Restore Test Script - Verifies Backup Manifest Integrity
# Usage: ./restore-test.sh [backup_dir_or_file] [config_file]

CONFIG_FILE="${2:-/etc/backup.env}"

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

BACKUP_SOURCE="${1:-${DEST:-/srv/backup-target}}"

# Determine target archive
if [[ -d "$BACKUP_SOURCE" ]]; then
    LATEST_ARCHIVE=$(find "$BACKUP_SOURCE" -type f -name "backup_*.tar.gz" | sort | tail -n 1)
    if [[ -z "$LATEST_ARCHIVE" ]]; then
        echo "Error: No backup archive found in '$BACKUP_SOURCE'." >&2
        exit 1
    fi
elif [[ -f "$BACKUP_SOURCE" ]]; then
    LATEST_ARCHIVE="$BACKUP_SOURCE"
else
    echo "Error: Backup source '$BACKUP_SOURCE' is invalid." >&2
    exit 1
fi

echo "[INFO] Testing restore on archive: ${LATEST_ARCHIVE}"

# Throwaway temporary directory
TEST_DIR=$(mktemp -d /tmp/web01_restore_test.XXXXXX)

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Extract archive
tar -xzf "$LATEST_ARCHIVE" -C "$TEST_DIR"

if [[ ! -f "${TEST_DIR}/manifest.txt" ]]; then
    echo "[FAIL] Manifest file (manifest.txt) not found in archive!" >&2
    exit 1
fi

echo "[INFO] Verifying manifest checksums..."
(
    cd "$TEST_DIR"
    if md5sum -c manifest.txt; then
        TOTAL_FILES=$(wc -l < manifest.txt)
        echo "[SUCCESS] Restore test PASSED! All ${TOTAL_FILES} files matched the manifest checksums."
    else
        echo "[FAIL] Manifest verification FAILED! Corrupted or missing files detected." >&2
        exit 1
    fi
)

exit 0
