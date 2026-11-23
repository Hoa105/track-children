# Hướng Dẫn Triển Khai Hệ Thống Track Children (Live 24/24)

> Tài liệu hướng dẫn thiết lập tên miền, hạ tầng mạng, Cloudflare Tunnel và khởi chạy toàn bộ hệ thống cho thành viên trong nhóm.

---

## 1. Kiến Trúc Triển Khai (Deployment Architecture)

Hệ thống hoạt động theo mô hình Hybrid: **Chạy dịch vụ Docker cục bộ** kết hợp **Cloudflare Tunnel** để mở cổng Internet công khai an toàn có chứng chỉ SSL (HTTPS) miễn phí.

```text
[ Internet / Mobile App / Web Browser ]
                  │
                  ▼ (HTTPS / 443)
       ┌──────────────────────────┐
       │   Cloudflare Edge DNS    │  trackchildren.tech
       └──────────┬───────────────┘
                  │
                  ▼ (Encrypted Cloudflare Tunnel)
       ┌──────────────────────────┐
       │   cloudflared (Service)  │  (Chạy ngầm trên máy chủ/PC)
       └──────────┬───────────────┘
                  │ (Localhost Routing)
      ┌───────────┼───────────┐
      ▼           ▼           ▼
   Backend      Admin       MinIO
  (Port 8000) (Port 5173) (Port 9000)
      │
   Postgres (Port 5433)
   AI-Service (Port 8001)
```

### Các Endpoint Công Khai (Public URLs)

| Dịch vụ | Tên miền công khai | Cổng nội bộ | Mô tả |
| :--- | :--- | :--- | :--- |
| **Backend API** | `https://api.trackchildren.tech` | `http://localhost:8000` | FastAPI Backend & WHO Anthro R Engine |
| **Admin Web** | `https://admin.trackchildren.tech` | `http://localhost:5173` | Giao diện quản trị React |
| **MinIO Storage** | `https://media.trackchildren.tech` | `http://localhost:9000` | S3 API tải/lưu ảnh & video nhật ký |

---

## 2. Chuẩn Bị Môi Trường (Prerequisites)

Các thành viên cần cài đặt trước:
1. **Git**
2. **Docker Desktop** (bật WSL2 trên Windows)
3. **Flutter SDK** (nếu tham gia build ứng dụng Mobile)
4. Công cụ **`cloudflared`** của Cloudflare

---

## 3. Các Bước Cài Đặt và Khởi Chạy

### Bước 1: Khởi động hệ thống Docker

1. Clone mã nguồn về máy:
   ```bash
   git clone <repo-url>
   cd track-children
   ```

2. Kiểm tra file cấu hình `.env` tại thư mục gốc:
   Đảm bảo các biến sau đã được cấu hình:
   ```env
   CORS_ORIGINS='["http://localhost:5173","http://localhost:5174","http://127.0.0.1:5174","https://admin.trackchildren.tech"]'
   MINIO_PUBLIC_URL=https://media.trackchildren.tech
   APP_ENV=local
   AUTH_V2_ENABLED=true
   DEV_AUTH=true
   AUTH_OTP_PREVIEW=true
   GEMINI_API_KEY=<khoa-gemini-cua-ban>
   AI_SERVICE_TOKEN=secret_token_for_belonkhon
   LLM_PROVIDER=gemini
   ```

3. Khởi động tất cả các container:
   ```powershell
   docker compose up -d
   ```

4. Chạy migration cơ sở dữ liệu:
   ```powershell
   python scripts/migrate_system.py --target all
   ```

---

### Bước 2: Cài Đặt Cloudflare Tunnel (`cloudflared`)

1. Tải công cụ `cloudflared`:
   * Tải file [cloudflared-windows-amd64.exe](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe).
   * Đổi tên thành `cloudflared.exe` và lưu vào thư mục `D:\cloudflared` (hoặc thư mục tuỳ chọn).

2. Mở PowerShell tại thư mục chứa `cloudflared.exe` và đăng nhập:
   ```powershell
   .\cloudflared.exe tunnel login
   ```
   * Trình duyệt sẽ tự động mở trang Cloudflare. Đăng nhập và chọn tên miền `trackchildren.tech` để ủy quyền.

3. Tạo file cấu hình `config.yml`:
   Tạo file `config.yml` đặt tại thư mục chứa `cloudflared.exe` hoặc tại `C:\Users\<Tên-User>\.cloudflared\config.yml` với nội dung:

   ```yaml
   tunnel: trackchildren-tunnel
   credentials-file: C:\Users\<Tên-User>\.cloudflared\<TUNNEL_ID>.json

   ingress:
     - hostname: api.trackchildren.tech
       service: http://localhost:8000
     - hostname: admin.trackchildren.tech
       service: http://localhost:5173
     - hostname: media.trackchildren.tech
       service: http://localhost:9000
     - service: http_status:404
   ```

4. Gắn các DNS route (chỉ cần chạy một lần đầu):
   ```powershell
   .\cloudflared.exe tunnel route dns trackchildren-tunnel api.trackchildren.tech
   .\cloudflared.exe tunnel route dns trackchildren-tunnel admin.trackchildren.tech
   .\cloudflared.exe tunnel route dns trackchildren-tunnel media.trackchildren.tech
   ```

---

### Bước 3: Chạy Cloudflare Tunnel Ngầm 24/24

Để không phải mở cửa sổ PowerShell liên tục:
1. Mở PowerShell với quyền **Run as Administrator**.
2. Chạy 2 lệnh sau để cài đặt và kích hoạt dịch vụ chạy ngầm của Windows:
   ```powershell
   cd D:\cloudflared
   .\cloudflared.exe service install
   Start-Service cloudflared
   ```
*(Từ lúc này, máy tính khởi động lại thì đường hầm cũng sẽ tự động bật theo).*

---

### Bước 4: Thiết Lập Máy Tính Để Chạy 24/24 (Không Sleep khi gập nắp)

Nếu chạy trên Laptop:
1. Nhấn `Windows`, mở **Control Panel** $\rightarrow$ **Power Options**.
2. Chọn **"Choose what closing the lid does"**.
3. Tại dòng **When I close the lid**:
   * Cột **Plugged in** (Khi cắm sạc): Chọn **Do nothing** (Không làm gì cả).
   * Nhấn **Save changes**.
4. Vào Windows **Settings** $\rightarrow$ **Power & sleep**: Đặt *"When plugged in, PC goes to sleep after"* thành **Never**.

---

### Bước 5: Kiểm Tra Kết Quả Hoạt Động (Healthcheck)

Mở trình duyệt hoặc điện thoại (dùng 4G) truy cập vào:
* **API Health:** [https://api.trackchildren.tech/health](https://api.trackchildren.tech/health)
  * Kết quả chuẩn: `{"status":"ok","growth_engine":"ready"}`
* **Admin Web:** [https://admin.trackchildren.tech](https://admin.trackchildren.tech)

---

## 4. Hướng Dẫn Build Ứng Dụng Mobile (Flutter APK)

Để build file APK cho phụ huynh / giáo viên cài đặt trực tiếp lên điện thoại Android:

### Trong Git Bash / Terminal:
```bash
./scripts/build-mobile -ApiBaseUrl https://api.trackchildren.tech/api/v1 -NoInstall
```

### Hoặc bằng PowerShell:
```powershell
.\scripts\build-mobile.ps1 -ApiBaseUrl https://api.trackchildren.tech/api/v1 -NoInstall
```

* **Vị trí file APK sau khi build:**
  📂 `mobile/build/app/outputs/flutter-apk/app-debug.apk`

Chỉ cần copy file `app-debug.apk` này gửi qua Zalo/Drive là cài đặt được lên mọi điện thoại Android và tự động kết nối vào server live `https://api.trackchildren.tech`.

---

## 5. Xử Lý Sự Cố Thường Gặp (Troubleshooting)

1. **Truy cập `https://api.trackchildren.tech` báo lỗi 502 Bad Gateway:**
   * Nguyên nhân: Dịch vụ Backend chưa được bật ở cổng `8000`.
   * Khắc phục: Kiểm tra Docker `docker compose ps` xem container `backend` đã ở trạng thái `running` hay chưa.

2. **Mobile app báo lỗi CORS hoặc không tải được ảnh/video:**
   * Kiểm tra biến `CORS_ORIGINS` và `MINIO_PUBLIC_URL=https://media.trackchildren.tech` trong `.env`.

3. **Cloudflare Tunnel bị ngắt kết nối:**
   * Mở PowerShell chạy: `Restart-Service cloudflared` hoặc kiểm tra log tại `D:\cloudflared`.
