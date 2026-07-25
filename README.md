# Web01 Ops Automation — Bash Scripting & Operations Toolkit

---

## Thông tin sinh viên & Môi trường

- **Họ và tên:** Mai Thị Kim Duyên
- **Mã sinh viên:** 23127185
- **Host / OS:** `web01` (CentOS Stream 9 / Linux VM)
- **Repository:** `Bash-ScriptingandOps-Automation`

---

## Cấu trúc thư mục dự án

```text
Bash-ScriptingandOps-Automation/
├── health-check.sh             # Task 1: Kịch bản kiểm tra sức khỏe hệ thống & gửi cảnh báo
├── backup.sh                   # Task 2 & 3: Kịch bản sao lưu dữ liệu tự động & bẫy lỗi ERR/EXIT
├── backup-error.sh             # Task 3: Kịch bản giả lập lỗi để kiểm thử bẫy lỗi ERR
├── restore-test.sh             # Task 2: Kịch bản khôi phục & xác minh tính toàn vẹn (md5sum)
├── lib/
│   └── alert.sh                # Thư viện dùng chung gửi email cảnh báo (msmtp / mail / fallback log)
├── cron/
│   └── crontab                 # File cấu hình lịch chạy tự động Cron (Task 4)
├── examples/
│   ├── monitoring.env.example  # File cấu hình mẫu cho health-check.sh
│   └── backup.env.example      # File cấu hình mẫu cho backup.sh
├── img/                        # Hình ảnh bằng chứng nghiệm thu cho báo cáo
├── REPORT.md                   # Báo cáo chi tiết kết quả nghiệm thu từng Task
└── README.md                   # Hướng dẫn cài đặt và thực thi hệ thống
```

---

## Hướng dẫn cài đặt & Thiết lập môi trường

### 1. Chuẩn bị Web Endpoint (`myweb`)

Tạo thư mục dữ liệu web và dịch vụ `systemd` tên `myweb` chạy trên cổng `8080`:

```bash
# 1. Tạo thư mục dữ liệu mẫu
mkdir -p ~/web01-data && echo "hello from web01" > ~/web01-data/index.html

# 2. Khai báo service myweb trong systemd
sudo bash -c "cat > /etc/systemd/system/myweb.service <<EOF
[Unit]
Description=My Web Server (python3 http.server)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/web01-data
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

# 3. Kích hoạt và khởi chạy dịch vụ
sudo systemctl daemon-reload
sudo systemctl enable --now myweb

# 4. Kiểm tra trạng thái
sudo systemctl status myweb
```

---

### 2. Thiết lập File Cấu hình Hệ thống (`/etc/*.env`)

Sao chép các file cấu hình mẫu vào `/etc/` và cấp quyền bảo mật `600`:

```bash
# 1. Cấu hình giám sát (/etc/monitoring.env)
sudo cp examples/monitoring.env.example /etc/monitoring.env
sudo chown root:root /etc/monitoring.env
sudo chmod 600 /etc/monitoring.env

# 2. Cấu hình sao lưu (/etc/backup.env)
sudo cp examples/backup.env.example /etc/backup.env
sudo chown root:root /etc/backup.env
sudo chmod 600 /etc/backup.env
```

*Lưu ý:* Điều chỉnh thông số email `ALERT_TO` trong các file `/etc/*.env` tương ứng với địa chỉ nhận cảnh báo thực tế.

---

### 3. Tạo thư mục lưu trữ Backup (`DEST`)

```bash
sudo mkdir -p /srv/backup-target
sudo chown -R $USER:$USER /srv/backup-target
```

---

## Hướng dẫn Sử dụng & Thực thi các Kịch bản

### 1. Cấp quyền thực thi cho các script

```bash
chmod +x *.sh
```

---

### 2. Kiểm tra sức khỏe hệ thống (`health-check.sh`)

Kịch bản kiểm tra Disk Usage, Free RAM, Systemd Services (`sshd`, `crond`, `myweb`), và Web Endpoint (`http://localhost:8080`).

```bash
# Chạy trực tiếp (sử dụng cấu hình mặc định /etc/monitoring.env)
./health-check.sh

# Kiểm tra mã thoát (0 nghĩa là hệ thống bình thường, im lặng không phát lỗi)
echo $?
```

---

### 3. Thực hiện sao lưu dữ liệu (`backup.sh`)

Kịch bản nén thư mục dữ liệu `$DATA_DIR`, đính kèm mã hăm `manifest.txt` (`md5sum`), chuyển bản sao lưu sang `$DEST` và xoay vòng xóa bản sao lưu cũ quá `$RETAIN_DAYS` ngày.

```bash
# Thực hiện sao lưu
./backup.sh

# Kiểm tra mã thoát (0 = thành công)
echo $?

# Kiểm tra bản sao lưu đã được tạo trong thư mục đích
ls -lh /srv/backup-target
```

---

### 4. Kiểm tra khôi phục & Xác minh tính toàn vẹn (`restore-test.sh`)

Giải nén bản sao lưu mới nhất tại `/srv/backup-target` vào thư mục tạm và đối chiếu lại bảng mã `md5sum` trong `manifest.txt`.

```bash
# Kiểm tra khôi phục bản sao lưu tại /srv/backup-target
./restore-test.sh /srv/backup-target
```

---

### 5. Kiểm thử bẫy lỗi (`trap ERR` & `trap cleanup EXIT`)

Sử dụng script `backup-error.sh` hoặc chèn lệnh lỗi để xác nhận hệ thống kích hoạt email cảnh báo sự cố kèm số dòng, câu lệnh lỗi và mã thoát:

```bash
# Chạy script thử nghiệm lỗi
./backup-error.sh

#Kiểm tra alert.log hoặc Gmail
```

---

### 6. Rà soát cú pháp tĩnh (`shellcheck`)

Đảm bảo toàn bộ các tệp `.sh` đạt chuẩn cú pháp Bash và không chứa lỗi:

```bash
shellcheck health-check.sh backup.sh backup-error.sh restore-test.sh lib/alert.sh
```

---

## Cấu hình Tự động hóa với Cron (`cron`)

### 1. Tạo các file log hệ thống

```bash
sudo touch /var/log/web01-health.log /var/log/web01-backup.log
sudo chown $USER:$USER /var/log/web01-health.log /var/log/web01-backup.log
```

### 2. Nạp cấu hình Crontab

File `cron/crontab` đã được thiết lập đường dẫn tuyệt đối và biến `PATH` đầy đủ để tránh lỗi môi trường cron:

```bash
# Nạp file crontab
crontab cron/crontab

# Kiểm tra danh sách công việc cron đã được nạp
crontab -l
```

### 3. Kiểm tra nhật ký thực thi Cron

```bash
# Xem log chạy health-check định kỳ
tail -f /var/log/web01-health.log

# Xem log chạy backup định kỳ
tail -f /var/log/web01-backup.log

# Xem nhật ký hệ thống cron (CentOS / RHEL)
sudo journalctl -u crond --since "10 minutes ago"
```

---

## Báo cáo chi tiết

Bằng chứng thực nghiệm, hình ảnh minh họa màn hình nghiệm thu cho cả 4 Task được ghi trong file **[`REPORT.md`](REPORT.md)**.
