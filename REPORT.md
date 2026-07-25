# Bài tập tuần 5: BASH SCRIPTING & OPS AUTOMATION

- **Họ và tên:** Mai Thị Kim Duyên  
- **Mã sinh viên:** 23127185  
- **Host / OS:** `web01` (CentOS Stream 9)  

---

## 1. Môi trường thực thi

### 1.1. Cấu hình Web Endpoint
- Tạo thư mục dữ liệu `~/web01-data` và nội dung trang web:
  ```bash
  mkdir -p ~/web01-data && echo "hello from web01" > ~/web01-data/index.html
  ```
- Khai báo dịch vụ Systemd `myweb`:
  ```bash
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
  ```
- Nạp lại cấu hình và bật dịch vụ `myweb`:
  ```bash
  sudo systemctl daemon-reload
  sudo systemctl enable --now myweb
  ```
- Kiểm tra trạng thái của dịch vụ `myweb`:
  ```bash
  sudo systemctl status myweb
  ```
> **Ghi chú**: Lí do sử dụng Systemd thay cho việc chạy trực tiếp command `python3 -m http.server 8080 &` là để đảm bảo dịch vụ luôn hoạt động ổn định, tự khởi động lại khi gặp lỗi và có thể quản lý dễ dàng thông qua các câu lệnh `systemctl`.

![cấu hình web endpoint](img/cauhinhwebendpoint.png)

### 1.2. Cấu hình Email Alert Transport
- **Giải pháp lựa chọn:** Cấu hình động kết hợp (Hybrid approach) được viết trong thư viện dùng chung `lib/alert.sh`.
- **Cơ chế hoạt động:** 
  - Ưu tiên dùng `msmtp` hoặc `mail` gửi mail thật nếu máy chủ đã cấu hình.
  - Tự động chuyển hướng ghi log dạng raw email vào `~/alerts.log` nếu không có công cụ gửi mail.

---

## Task 1 — Health-check with email alerting

### Tóm tắt giải pháp
Tệp `health-check.sh` đọc cấu hình từ `/etc/monitoring.env`, kiểm tra lần lượt:
1. Dung lượng ổ cứng root `%` so với `DISK_THRESHOLD`.
2. Dung lượng RAM trống `%` so với `RAM_MIN_FREE`.
3. Trạng thái của các dịch vụ trong danh sách `SERVICES` (`systemctl is-active`).
4. Phản hồi từ HTTP endpoint (`curl -sf --max-time 5`).

Các vi phạm được gom vào mảng `ALERTS=()`. Cuối kịch bản, nếu `ALERTS` có phần tử, hàm `send_alert()` gửi **đúng 1 email** danh sách tất cả cảnh báo.

### Lệnh thực thi

- **Cấp quyền thực thi và chạy kịch bản:**
  ```bash
  chmod +x health-check.sh
  ./health-check.sh
  ```
- **Kiểm tra trạng thái sau khi chạy (Exit Code):**
  ```bash
  echo "Exit code: $?"
  # Output: 0 (Hệ thống bình thường, không phát hiện lỗi)
  ```

### Bằng chứng nghiệm thu

Kiểm tra khi hệ thống bình thường: Giả sử DISK_THRESHOLD = 85. (DISK_THRESHOLD là ngưỡng cảnh báo, khi dung lượng ổ cứng vượt ngưỡng này thì sẽ gửi cảnh báo)
![Kiểm tra khi hệ thống bình thường 1](img/1-1.png)

Kiểm tra khi hệ thống không bình thường: Giả sử tắt HTTP endpoint.
![Tắt HTTP endpoint](img/1-2.png)
![Cảnh báo trên gmail khi tắt HTTP endpoint](img/1-3.png)
Kiểm tra khi hệ thống không bình thường: Giả sử giảm DISK_THRESHOLD xuống 1%.
![Cảnh báo trên gmail khi giảm DISK_THRESHOLD](img/1-4.png)

## Task 2 — Automated backup with safe cleanup
### Tóm tắt giải pháp
Tệp `backup.sh`:
1. Nạp biến từ `/etc/backup.env`, kiểm tra tính hợp lệ của biến.
2. Đăng ký `trap cleanup EXIT`: Xóa thư mục tạm `/tmp/web01_backup.XXXXXX` và gửi email báo lỗi nếu exit code khác 0.
3. Tạo file checksum `manifest.txt` chứa `md5sum` của toàn bộ tệp tin trong `$DATA_DIR` (loại trừ `*.log`, `*.tmp`).
4. Đóng gói nén `.tar.gz` chứa dữ liệu và `manifest.txt`.
5. Đưa bản sao lưu sang `$DEST` và xóa bản sao lưu cũ hơn `$RETAIN_DAYS` ngày (`mtime +N`).
6. Kịch bản `restore-test.sh` giải nén bản sao lưu mới nhất vào thư mục tạm và chạy `md5sum -c manifest.txt` để xác minh tính toàn vẹn.

### Lệnh thực thi

- **Cấp quyền thực thi và chạy kịch bản sao lưu (`backup.sh`):**
  ```bash
  chmod +x backup.sh
  ./backup.sh
  ```
- **Kiểm tra trạng thái sau khi sao lưu (Exit Code):**
  ```bash
  echo "Exit code: $?"
  # Output: 0 (Sao lưu thành công, file .tar.gz được tạo tại DEST)
  ```
- **Cấp quyền thực thi và kiểm tra khôi phục dữ liệu (`restore-test.sh`):**
  ```bash
  chmod +x restore-test.sh
  ./restore-test.sh /srv/backup-target
  ```
  
### Bằng chứng nghiệm thu
- Tạo thư mục backup và cấp quyền cho user
  ```bash
  sudo mkdir -p /srv/backup-target
  sudo chown -R $USER:$USER /srv/backup-target
  ```
- **Sao lưu thành công và khôi phục dữ liệu thành công**
![Sao lưu thành công file .tar.gz](img/2-1.png)
![Khôi phục dữ liệu thành công](img/2-2.png)
![Thông báo trên gmail khi backup thành công](img/2-3.png)

- **Giả lập lỗi & kiểm chứng bẫy lỗi `trap cleanup EXIT`**
- **Thực nghiệm:** Đặt `DATA_DIR="/path/not/exist"` trong cấu hình tạm và chạy kịch bản:
![Cảnh báo trên gmail khi DATA_DIR không tồn tại](img/2-4.png)

---

## Task 3 — Error trapping and linting (2.0 pts)

### Tóm tắt giải pháp
1. Tích hợp bẫy `trap 'on_error $LINENO "$BASH_COMMAND" $?' ERR` vào kịch bản `backup.sh`.
2. Hàm `on_error()` trích xuất chính xác **số dòng (line number)**, **câu lệnh bị lỗi (command)**, **exit code** và **hostname** để lưu vào biến `ERROR_REASON` trước khi ngắt kịch bản.
3. Bẫy `trap cleanup EXIT` tiếp nhận thông tin từ `on_error()` để gửi email cảnh báo khẩn cấp và dọn dẹp thư mục tạm `/tmp/web01_backup.XXXXXX`.
4. Rà soát cú pháp toàn bộ các tệp kịch bản (`*.sh`) bằng `shellcheck` và khắc phục triệt để các cảnh báo.

### Lệnh thực thi

- **1. Kiểm tra cú pháp tĩnh bằng ShellCheck (Static Analysis):**
  Rà soát cú pháp toàn bộ các tệp kịch bản để đảm bảo không có cảnh báo/lỗi cú pháp trước khi vận hành:
  ```bash
  shellcheck *.sh
  echo "Exit code: $?"
  ```

- **2. Kiểm thử bẫy lỗi `trap ERR` khi thực thi (Forced Runtime Error):**
  Sau khi mã nguồn đã chuẩn cú pháp, chèn câu lệnh cố tình bị lỗi vào `backup.sh` để kiểm thử bẫy lỗi runtime:
  ```bash
  # 1. Chèn câu lệnh cố tình lỗi vào kịch bản
  sed -i '/# 4. Đóng gói/i tar -czf /tmp/out.tgz /no/such/dir' backup.sh

  # 2. Thực thi kịch bản để kích hoạt trap ERR
  ./backup.sh
  ```

### Bằng chứng nghiệm thu

- **Kiểm tra với cú pháp ShellCheck**
![ShellCheck](img/3-1.png)

- **Thực thi kịch bản để kích hoạt trap ERR**
![trap ERR](img/3-2.png)

## Task 4 — Scheduling with cron (1.5 pts)

### Tóm tắt giải pháp
Cấu hình cron job chạy tự động định kỳ:
- `health-check.sh`: Chạy mỗi 5 phút (`*/5 * * * *`).
- `backup.sh`: Chạy hàng ngày lúc 02:00 AM (`0 2 * * *`).

### Lệnh thực thi
- **Quyền tạo file log trong /var/log:**
  ```bash
  sudo touch /var/log/web01-health.log /var/log/web01-backup.log
  sudo chown melyen:melyen /var/log/web01-health.log /var/log/web01-backup.log
  ```

- **Cấu hình và kích hoạt Cron Job:**
  ```bash
  # Nạp cấu hình crontab
  crontab cron/crontab

  # Kiểm tra danh sách cron job đã được nạp
  crontab -l
  ```

- **Kiểm tra trạng thái sau khi cấu hình:**
  ```bash
  # Xem danh sách cron job đang hoạt động
  crontab -l
  # Output: Hiển thị nội dung file cron/crontab đã nạp

  # Kiểm tra xem hệ thống đã kích hoạt Cron chưa (Log hệ thống CentOS 9):
  sudo journalctl -u crond --since "10 minutes ago"
  ```

### Bằng chứng nghiệm thu
- **Kiểm tra danh sách cron job đã được nạp**
![crontab](img/4-1.png)


- **Kiểm tra xem hệ thống đã kích hoạt Cron chưa (Log hệ thống CentOS 9)**
![Kiểm tra hệ thống](img/4-2.png)

- **Log nhật ký thực thi kịch bản tự động theo lịch của Cron Daemon (`/var/log/cron`):**
![Log nhật ký thực thi kịch bản tự động theo lịch của Cron Daemon ](img/4-3.png)

- **Cảnh báo tự động phát sinh gửi qua Email khi dừng dịch vụ `myweb`:**
![Cảnh báo tự động phát sinh gửi qua Email khi dừng dịch vụ myweb](img/4-4.png)

### Giải thích lý thuyết: Tại sao script chạy tay OK nhưng có thể thất bại dưới Cron?

**3 nguyên nhân chính gây lỗi khi chạy qua Cron:**
1. **Cron không biết đường dẫn (`PATH` hạn chế):** Cron không có danh sách các thư mục chứa lệnh như khi gõ tay. Nếu không ghi rõ đường dẫn tuyệt đối hoặc không định nghĩa `PATH` trong crontab, Cron sẽ báo `command not found`.
2. **Cron không nạp cấu hình cá nhân (Non-interactive Shell):** Cron không đọc các file `~/.bashrc` hay `~/.bash_profile`, nên các biến môi trường hay cài đặt riêng của bạn Cron đều không biết.
3. **Cron đứng sai vị trí (Current Working Directory):** Cron mặc định đứng ở thư mục Home (`~`). Nếu script gọi file phụ thuộc bằng đường dẫn tương đối (như `./lib/alert.sh`) mà không xác định vị trí script, Cron sẽ tìm nhầm chỗ và báo lỗi không thấy file.

**Cách khắc phục đã triển khai trong bài làm:**
- Khai báo `PATH` và `SHELL` ngay đầu tệp `cron/crontab`.
- Sử dụng đường dẫn tuyệt đối khi gọi script trong `crontab`.
- Dùng `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` trong code để script tự xác định vị trí của nó và nạp đúng `lib/alert.sh`.
- Cấp quyền thực thi `chmod +x` cho tất cả script.