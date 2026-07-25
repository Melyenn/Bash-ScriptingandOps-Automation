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
