#!/usr/bin/env bash
set -euo pipefail

# Health Check Script
# Usage: ./health-check.sh [config_file]

CONFIG_FILE="${1:-/etc/monitoring.env}"

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file '$CONFIG_FILE' not found." >&2
    exit 1
fi

# Required configuration
: "${ALERT_TO:?ALERT_TO required}"
: "${DISK_THRESHOLD:?DISK_THRESHOLD required}"
: "${RAM_MIN_FREE:?RAM_MIN_FREE required}"
: "${SERVICES:?SERVICES required}"
: "${HEALTH_URL:?HEALTH_URL required}"

# Load alert library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/lib/alert.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/alert.sh"
else
    echo "Error: Alert library '${SCRIPT_DIR}/lib/alert.sh' not found." >&2
    exit 1
fi

ALERTS=()

# -----------------------------------------------------------------------------
# 1. Disk Usage Check
# -----------------------------------------------------------------------------
DISK_USAGE=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')

if (( DISK_USAGE >= DISK_THRESHOLD )); then
    ALERTS+=("Disk usage high: ${DISK_USAGE}% (Threshold: ${DISK_THRESHOLD}%)")
fi

# -----------------------------------------------------------------------------
# 2. Free RAM Check
# -----------------------------------------------------------------------------
RAM_FREE_PCT=$(free | awk '/^Mem:/ {printf "%.0f", ($7/$2)*100}')

if (( RAM_FREE_PCT < RAM_MIN_FREE )); then
    ALERTS+=("Free RAM low: ${RAM_FREE_PCT}% (Minimum required: ${RAM_MIN_FREE}%)")
fi

# -----------------------------------------------------------------------------
# 3. Systemd Services Check
# -----------------------------------------------------------------------------
read -r -a SERVICE_LIST <<< "$SERVICES"

for svc in "${SERVICE_LIST[@]}"; do
    if ! systemctl is-active --quiet "$svc"; then
        ALERTS+=("Service inactive: ${svc}")
    fi
done

# -----------------------------------------------------------------------------
# 4. Web Endpoint Check
# -----------------------------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
    ALERTS+=("curl command not found")
elif ! curl -sf --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
    ALERTS+=("Web endpoint unreachable: ${HEALTH_URL}")
fi

# -----------------------------------------------------------------------------
# Send Alert
# -----------------------------------------------------------------------------
if (( ${#ALERTS[@]} > 0 )); then
    HOSTNAME_STR="$(hostname -f 2>/dev/null || hostname)"
    SUBJECT="SYSTEM ALERT: Issues detected on ${HOSTNAME_STR}"

    printf -v BODY "The health check identified the following issue(s):\n\n"

    for item in "${ALERTS[@]}"; do
        printf -v BODY "%s- %s\n" "$BODY" "$item"
    done

    printf -v BODY "%s\nTime of check: %s\n" "$BODY" "$(date)"

    send_alert "$SUBJECT" "$BODY" "$ALERT_TO"
fi

exit 0