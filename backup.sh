#!/usr/bin/env bash
set -euo pipefail

# 1. Nạp tệp cấu hình (mặc định /etc/backup.env hoặc từ tham số)
CONFIG_FILE="${1:-/etc/backup.env}"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file '$CONFIG_FILE' not found." >&2
    exit 1
fi

# Ràng buộc các biến bắt buộc
: "${DATA_DIR:?DATA_DIR is required}"
: "${ALERT_TO:?ALERT_TO is required}"
: "${DEST:?DEST is required}"
: "${RETAIN_DAYS:?RETAIN_DAYS is required}"

# Nạp thư viện alert dùng chung (nếu có)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/alert.sh" ]]; then
    source "${SCRIPT_DIR}/lib/alert.sh"
else
    send_alert() {
        local subject="$1"
        local body="$2"
        local recipient="$3"
        local host
        host="$(hostname)"
        echo -e "To: ${recipient}\nSubject: [${host}] ${subject}\n\n${body}" | msmtp "${recipient}" 2>/dev/null || \
        echo -e "[ALERT] ${subject}\n${body}" >> "${HOME}/alerts.log"
    }
fi

# Thư mục làm việc tạm thời
TMP_DIR=$(mktemp -d /tmp/web01_backup.XXXXXX)

# Global variable to store error details (Task 3)
ERROR_REASON="An unexpected error occurred during execution."

# 2. Đăng ký trap cleanup EXIT: Gửi email BACKUP FAILED nếu lỗi và luôn dọn dẹp TMP_DIR
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        local host
        host="$(hostname)"
        local alert_body
        alert_body="BACKUP FAILED REPORT:
----------------------------------------
Host: ${host}
Exit Code: ${exit_code}
Reason/Details: ${ERROR_REASON}
Timestamp: $(date)
----------------------------------------
Temporary directory cleaned: ${TMP_DIR}"

        send_alert "BACKUP FAILED: ${ERROR_REASON}" "$alert_body" "$ALERT_TO"
    fi
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Task 3: Error Handler on ERR (Bắt số dòng, câu lệnh lỗi và exit code)
on_error() {
    local line_no="$1"
    local command="$2"
    local exit_code="$3"
    ERROR_REASON="Command '${command}' failed at line ${line_no} with exit code ${exit_code}."
}
trap 'on_error $LINENO "$BASH_COMMAND" $?' ERR

# Kiểm tra thư mục nguồn tồn tại
if [[ ! -d "$DATA_DIR" ]]; then
    ERROR_REASON="Source directory '$DATA_DIR' does not exist."
    echo "Error: ${ERROR_REASON}" >&2
    exit 1
fi

# Đảm bảo thư mục đích tồn tại (nếu là đường dẫn local)
if [[ "$DEST" != *:* ]]; then
    mkdir -p "$DEST"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ARCHIVE_NAME="backup_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"

# 3. Tạo tệp manifest (mã hăm md5sum của dữ liệu)
MANIFEST_FILE="${TMP_DIR}/manifest.txt"
(
    cd "$DATA_DIR"
    find . -type f ! -name "*.log" ! -name "*.tmp" -exec md5sum {} + > "$MANIFEST_FILE"
)

# 4. Đóng gói nén tar.gz bao gồm dữ liệu và manifest.txt (loại trừ *.log, *.tmp)
tar -czf "$ARCHIVE_PATH" \
    --exclude="*.log" \
    --exclude="*.tmp" \
    -C "$DATA_DIR" . \
    -C "$TMP_DIR" manifest.txt

# 5. Chuyển tệp nén sang nơi lưu trữ DEST (local hoặc remote)
if [[ "$DEST" == *:* ]]; then
    rsync -az "$ARCHIVE_PATH" "$DEST/"
else
    cp "$ARCHIVE_PATH" "${DEST}/${ARCHIVE_NAME}"
fi

# 6. Xoay vòng bản sao lưu cũ hơn RETAIN_DAYS ngày tại DEST
if [[ "$DEST" != *:* ]]; then
    find "$DEST" -type f -name "backup_*.tar.gz" -mtime +"$RETAIN_DAYS" -delete
fi

# 7. Gửi thông báo thành công Backup OK
ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
SUCCESS_MSG="Backup completed successfully.
Archive Name: ${ARCHIVE_NAME}
Archive Size: ${ARCHIVE_SIZE}
Destination: ${DEST}
Timestamp: $(date)"

send_alert "Backup OK" "$SUCCESS_MSG" "$ALERT_TO"

exit 0