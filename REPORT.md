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
  sudo bash -c 'cat << EOF > /etc/systemd/system/myweb.service
  [Unit]
  Description=My Web Server (python3 http.server)
  After=network.target

  [Service]
  Type=simple
  User='$USER'
  WorkingDirectory='$HOME'/web01-data
  ExecStart=/usr/bin/python3 -m http.server 8080
  Restart=always

  [Install]
  WantedBy=multi-user.target
  EOF'
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
