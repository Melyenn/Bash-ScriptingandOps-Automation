#!/usr/bin/env bash
# Shared Alert Helper Function

send_alert() {
    local subject="$1"
    local body="$2"
    local recipient="${3:-${ALERT_TO:-root@localhost}}"

    local hostname
    hostname="$(hostname)"

    local mail_content
    mail_content="Subject: [${hostname}] ${subject}
To: ${recipient}
Date: $(date -R)

${body}"

    # Case 1: If msmtp or mail commands exist, attempt to send real email
    if command -v msmtp >/dev/null 2>&1; then
        echo "$mail_content" | msmtp "$recipient" 2>/dev/null || {
            echo "--- ALERT MAIL (msmtp fallback) ---" >> "${HOME}/alerts.log"
            echo "$mail_content" >> "${HOME}/alerts.log"
        }
    elif command -v mail >/dev/null 2>&1; then
        echo "$body" | mail -s "[${hostname}] ${subject}" "$recipient" 2>/dev/null || {
            echo "--- ALERT MAIL (mail fallback) ---" >> "${HOME}/alerts.log"
            echo "$mail_content" >> "${HOME}/alerts.log"
        }
    else
        # Case 2: No mail utilities installed, directly write to local alerts.log file
        echo "--- ALERT LOG (No mailer installed) ---" >> "${HOME}/alerts.log"
        echo "$mail_content" >> "${HOME}/alerts.log"
    fi
}
