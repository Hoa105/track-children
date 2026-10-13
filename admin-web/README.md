# Admin Web

React + Vite, CSS thuần (`src/styles.css`).

```powershell
npm install
npm run dev      # http://localhost:5173
```

Dev server proxy `/api/backend` → backend (`BACKEND_URL`, mặc định `http://localhost:8000`)
và `/api/ai` → AI service (`AI_SERVICE_URL`, mặc định `http://localhost:8001`).

## Cấu trúc

```text
src/
├── app/
│   ├── App.jsx           # Khung trang, sidebar, router theo hash (#/users)
│   └── navigation.js     # Menu: đường dẫn, quyền, bảng DB, chức năng cần có
├── core/                 # api.js, auth.jsx + authApi.js (đăng nhập), session.js (vai trò & quyền), useHashRoute.js
├── shared/               # Icon, component UI dùng chung
└── features/<feature>/   # Mỗi màn hình một thư mục
```

- Đăng nhập: `#/login`, quên mật khẩu `#/forgot-password`, kích hoạt lời mời `#/invite?token=…`,
  đặt lại mật khẩu `#/reset-password?token=…`. Không có trang tự đăng ký — admin được mời.
  Xác thực hiện là mock (`core/authApi.js`), hợp đồng API thật ở `docs/api/README.md`.
  Tài khoản mock: `lan@trackchildren.vn` / `MatKhau@2026`.
- Mục menu chỉ hiển thị khi admin có `permission` tương ứng (mã trong `admin.permissions`).
- Mục chưa có màn riêng dùng `features/modules/ModulePage.jsx`, hiển thị bảng DB và danh sách
  chức năng lấy từ `navigation.js`. Dựng màn thật thì thêm component vào `pages` trong `App.jsx`.
- Các màn hiện dùng dữ liệu mẫu (có banner "Dữ liệu mẫu") cho tới khi backend có API `/admin/*`.
  API quản trị của AI service (kho tri thức, tiêu chí đề xuất, giám sát chatbot) đi qua backend.
