# API xác thực phụ huynh

Trạng thái: **đã triển khai backend và tích hợp auth mobile**. Ngày cập nhật: 17/10/2026.
Kết quả và giới hạn kiểm thử xem [báo cáo kiểm thử](mobile-auth-test-results.md).

Tài liệu mô tả đăng ký bằng email/mật khẩu, xác thực SĐT bằng SMS OTP,
đăng nhập, làm mới phiên và đăng xuất cho app `mobile`.
Không áp dụng cho admin. Đăng nhập mạng xã hội, quên/đổi mật khẩu và khôi phục
liên hệ qua admin nằm ngoài phiên bản này.

## 1. Quy ước

- Base path: `/api/v1`.
- Request và response JSON dùng `camelCase`; DB dùng `snake_case`.
- Header cho request có body: `Content-Type: application/json`.
- API cần xác thực: `Authorization: Bearer <accessToken>`.
- ID là UUID; thời gian là ISO 8601 UTC, ví dụ `2026-10-17T03:00:00Z`.
- Token trả trong JSON dành cho mobile, không dùng cookie refresh của admin.
- Response chứa token có `Cache-Control: no-store`.
- Không trả `passwordHash`, hash OTP hoặc hash refresh token.

Các thời hạn/giới hạn đang áp dụng trong phiên bản này (hằng số trong service):

| Tham số | Giá trị |
|---|---|
| Access token | 15 phút |
| Phiên với `rememberMe = false` | 24 giờ |
| Phiên với `rememberMe = true` | 30 ngày |
| OTP đăng ký | 6 chữ số, hiệu lực 5 phút |
| Số lần thử mỗi OTP | 5 |
| Khoảng cách gửi OTP | 60 giây |
| Giới hạn gửi OTP | 5 lần/SĐT/giờ và 20 lần/IP/giờ |
| Khóa đăng nhập tạm | 5 lần sai mật khẩu liên tiếp → 15 phút |
| Giới hạn gọi login theo IP | 30 lần/phút |

Hạn phiên là tuyệt đối, refresh không kéo dài vượt hạn ban đầu. Mở lại app
với `rememberMe = false` không tự khôi phục phiên; mobile không lưu refresh token
bền vững trong trường hợp này.

## 2. Danh sách endpoint

| Method | Path | Xác thực | Thành công |
|---|---|---|---|
| GET | `/legal-documents?context=registration` | Không | 200 |
| POST | `/auth/register` | Không | 201 |
| POST | `/auth/register/verify` | Không, dùng challenge | 200 |
| POST | `/auth/register/resend` | Không, dùng challenge | 200 |
| POST | `/auth/login` | Không | 200 |
| POST | `/auth/refresh` | Refresh token | 200 |
| POST | `/auth/logout` | Refresh token | 204 |
| GET | `/auth/me` | Access token | 200 |

## 3. Các đối tượng dùng chung

### User

```json
{
  "id": "51a482a0-1234-4567-8123-123456789abc",
  "email": "lan@example.com",
  "phone": "+84912345678",
  "username": "me_lan",
  "fullName": "Nguyễn Thị Lan",
  "relationship": "mother",
  "avatarUrl": null,
  "status": "active",
  "emailVerifiedAt": null,
  "phoneVerifiedAt": "2026-10-17T03:00:00Z"
}
```

`relationship`: `mother | father | guardian`, ánh xạ từ `ParentRole` của mobile.
Đây không phải quyền admin hay quyền sở hữu hồ sơ trẻ. Xác thực SĐT không xác thực email.

### Device

```json
{
  "deviceId": "app-installation-uuid",
  "deviceName": "Samsung Galaxy A55",
  "platform": "android"
}
```

`deviceId`: 1–100 ký tự, ID cài đặt do app tạo; không dùng làm bằng chứng xác thực.
`deviceName`: tùy chọn, tối đa 100 ký tự. `platform`: `android | ios | web`.
IP do server lấy từ request/proxy tin cậy, không nhận trong body.

### AuthResult

```json
{
  "tokenType": "Bearer",
  "accessToken": "<access-token>",
  "expiresIn": 900,
  "refreshToken": "<opaque-refresh-token>",
  "sessionExpiresAt": "2026-11-16T03:00:00Z",
  "user": {
    "id": "51a482a0-1234-4567-8123-123456789abc",
    "email": "lan@example.com",
    "phone": "+84912345678",
    "username": "me_lan",
    "fullName": "Nguyễn Thị Lan",
    "relationship": "mother",
    "avatarUrl": null,
    "status": "active",
    "emailVerifiedAt": null,
    "phoneVerifiedAt": "2026-10-17T03:00:00Z"
  },
  "deletionRequestCancelled": false
}
```

`expiresIn` tính bằng giây. `deletionRequestCancelled` chỉ là `true` khi lần đăng nhập
đó đã hủy thành công một yêu cầu xóa tài khoản còn chờ.

### Error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Thông tin chưa hợp lệ.",
    "fields": {
      "username": "Tên người dùng gồm 3–30 ký tự: a-z, 0-9, dấu gạch dưới hoặc dấu chấm."
    },
    "details": {}
  }
}
```

`fields` và `details` luôn là object, có thể rỗng. Mobile xử lý theo `code`,
không phân tích nội dung `message`. Lỗi `429` kèm header `Retry-After` tính bằng giây.
Backend chuẩn hóa cả lỗi validation của FastAPI theo envelope này.

## 4. Lấy điều khoản đăng ký

`GET /api/v1/legal-documents?context=registration`

Response `200`:

```json
{
  "documents": [
    {
      "id": "9d108da0-1234-4567-8123-123456789abc",
      "docType": "terms",
      "version": "1.0",
      "content": "Nội dung điều khoản...",
      "isRequired": true,
      "effectiveAt": "2026-10-01T00:00:00Z"
    }
  ]
}
```

Server chọn bản có `effective_at` mới nhất không vượt thời điểm hiện tại cho từng
loại `terms`, `privacy`, `data_policy`. Đây là quy tắc đề xuất vì DB chưa có cờ
phiên bản hiện hành. Nếu thiếu văn bản bắt buộc do cấu hình hệ thống, trả
`503 LEGAL_DOCUMENTS_UNAVAILABLE`, không cho đăng ký bỏ qua consent.
`ai_training` không thuộc consent đăng ký; cần luồng đồng ý riêng.

## 5. Đăng ký

`POST /api/v1/auth/register`

```json
{
  "fullName": "Nguyễn Thị Lan",
  "username": "me_lan",
  "email": "lan@example.com",
  "phone": "0912345678",
  "password": "MatKhauViDu123!",
  "relationship": "mother",
  "consents": [
    {
      "documentId": "9d108da0-1234-4567-8123-123456789abc",
      "isAccepted": true
    }
  ]
}
```

Ví dụ consent chỉ minh họa một văn bản; request thực tế phải chứa đủ các văn bản
bắt buộc đang hiệu lực từ endpoint điều khoản.

| Trường | Quy tắc |
|---|---|
| `fullName` | Bắt buộc, trim, 1–150 ký tự |
| `username` | Bắt buộc, trim và lowercase, regex `^[a-z0-9_.]{3,30}$`, duy nhất |
| `email` | Bắt buộc, email hợp lệ, trim, tối đa 254 ký tự, duy nhất không phân biệt hoa thường |
| `phone` | Bắt buộc, chuẩn hóa số Việt Nam về E.164; chấp nhận số quốc tế hợp lệ, duy nhất |
| `password` | Bắt buộc, đề xuất 10–128 ký tự; không trim/biến đổi |
| `relationship` | Bắt buộc, enum như User |
| `consents` | Không trùng document ID; chấp nhận đủ phiên bản bắt buộc đang hiệu lực |

`confirmPassword` chỉ kiểm tra trên mobile, không gửi lên API.

Response `201`:

```json
{
  "verificationId": "772f5dd0-1234-4567-8123-123456789abc",
  "registrationToken": "<opaque-registration-token>",
  "targetMasked": "+84******678",
  "expiresAt": "2026-10-17T03:05:00Z",
  "resendAvailableAt": "2026-10-17T03:01:00Z",
  "deliveryStatus": "sent"
}
```

Tạo user `pending`, consent và OTP trong một transaction; gửi SMS sau commit.
`deliveryStatus = sent` nghĩa là nhà cung cấp chấp nhận gửi, không bảo đảm máy đã nhận.
Nếu gửi thất bại, vẫn trả challenge với `deliveryStatus = failed`; mobile giữ màn OTP
và cho gửi lại sau thời gian chờ. Không trả OTP thật trong response/log.

`registrationToken` là secret ngẫu nhiên, có hiệu lực 30 phút và gắn với tài khoản
pending + SĐT đăng ký. Chỉ lưu hash; không dùng UUID công khai như một secret.
Token chỉ cho xác thực/gửi lại OTP, không truy cập dữ liệu người dùng.
Gửi lại OTP không gia hạn token này.

Nếu email/SĐT/username đã tồn tại, kể cả tài khoản pending: `409 ACCOUNT_CONFLICT`,
không ghi đè tài khoản hay mật khẩu. Để tiếp tục trên thiết bị khác, đăng nhập
bằng mật khẩu đã đăng ký để nhận challenge mới theo mục 8.

Lỗi: `422 VALIDATION_ERROR`, `409 ACCOUNT_CONFLICT`,
`409 LEGAL_CONSENT_REQUIRED`, `429 RATE_LIMITED`, `503 LEGAL_DOCUMENTS_UNAVAILABLE`.

## 6. Xác thực OTP đăng ký

`POST /api/v1/auth/register/verify`

```json
{
  "verificationId": "772f5dd0-1234-4567-8123-123456789abc",
  "registrationToken": "<opaque-registration-token>",
  "code": "482901",
  "rememberMe": true,
  "device": {
    "deviceId": "app-installation-uuid",
    "deviceName": "Samsung Galaxy A55",
    "platform": "android"
  }
}
```

`code` là chuỗi đúng 6 chữ số; `rememberMe` mặc định `true`; `device` bắt buộc.
Response `200`: `AuthResult`. Mobile chuyển sang luồng tạo/chọn hồ sơ bé;
API auth không tự tạo hồ sơ trẻ.

Khóa user rồi OTP trong transaction; kiểm tra challenge, target, purpose `register`,
hạn mã và số lần thử. Thành công: đặt `used_at`, `phone_verified_at`, chuyển
`pending → active`, tạo session và vô hiệu các challenge đăng ký còn lại.
Sai mã: tăng và commit `attempts` ngay cả khi response là lỗi.
Request lặp sau khi thành công không tạo thêm phiên: challenge đã bị vô hiệu,
trả `401 REGISTRATION_CHALLENGE_INVALID` trước khi kiểm tra OTP.
Lần sai thứ 5 trả `400 OTP_INVALID`, `attemptsRemaining = 0`; lần tiếp theo trả `429`.

| HTTP | Code | Ý nghĩa |
|---|---|---|
| 401 | `REGISTRATION_CHALLENGE_INVALID` | Secret sai, hết hạn hoặc không khớp challenge |
| 400 | `OTP_INVALID` | Sai mã; `details.attemptsRemaining` cho biết số lần còn lại |
| 410 | `OTP_EXPIRED` | Mã hết hạn hoặc bị thay thế bởi lần gửi lại |
| 409 | `OTP_ALREADY_USED` | Mã đã xác thực thành công |
| 429 | `OTP_ATTEMPTS_EXCEEDED` | Hết lượt của mã này; cần gửi lại |
| 403 | `ACCOUNT_UNAVAILABLE` | Tài khoản không còn đủ điều kiện kích hoạt |

Không trả thông tin OTP trước khi xác nhận registration token hợp lệ.

## 7. Gửi lại OTP

`POST /api/v1/auth/register/resend`

```json
{
  "verificationId": "772f5dd0-1234-4567-8123-123456789abc",
  "registrationToken": "<opaque-registration-token>"
}
```

Response `200`: cùng cấu trúc challenge của register, với `verificationId` mới;
giữ nguyên registration token và hạn 30 phút ban đầu.
Mobile thay verification ID đang giữ, bỏ mã người dùng đã nhập.

Trong transaction: khóa user, kiểm tra cooldown/quota, làm mã cũ hết hạn,
tạo mã mới với `attempts = 0`. Mã mới thay thế mã cũ kể cả khi SMS mới gửi thất bại.
Giới hạn gửi tính cả các lần provider báo lỗi để tránh vòng lặp gửi không kiểm soát.

Lỗi: `401 REGISTRATION_CHALLENGE_INVALID`, `403 ACCOUNT_UNAVAILABLE`,
`429 RATE_LIMITED`. Khi challenge hết hạn, đăng nhập lại để tiếp tục.

## 8. Đăng nhập

`POST /api/v1/auth/login`

```json
{
  "email": "lan@example.com",
  "password": "MatKhauViDu123!",
  "rememberMe": true,
  "device": {
    "deviceId": "app-installation-uuid",
    "platform": "android"
  }
}
```

`rememberMe` mặc định `true`; `device` bắt buộc. Phiên bản đầu chỉ đăng nhập bằng
email, chưa dùng username/SĐT. Response `200`: `AuthResult`.
Email không tồn tại và mật khẩu sai đều trả `401 INVALID_CREDENTIALS` cùng thông báo.

Sau khi kiểm tra đúng mật khẩu:

| Trạng thái DB | Xử lý |
|---|---|
| `pending` | `403 VERIFICATION_REQUIRED`; trả challenge mới trong `error.details.registration` |
| `active` | Tạo session và cập nhật `last_login_at` |
| `locked` | `403 ACCOUNT_LOCKED` |
| `pending_deletion` | Chỉ hủy yêu cầu còn pending và chưa đến `scheduled_at`, rồi cấp phiên |
| `deleted` | Từ chối; tài khoản đã ẩn danh không khôi phục được |

Với `VERIFICATION_REQUIRED`, challenge có cấu trúc như response register, tuân thủ
cooldown/quota. Nếu chưa được gửi SMS, `deliveryStatus = deferred`, kèm
`resendAvailableAt` thực tế; không đổi OTP hoặc reset số lần thử để vượt giới hạn.
Challenge đang được cấp lại có thể tham chiếu OTP hiện hành. Các token đăng ký cũ
bị vô hiệu khi cấp token mới sau lần đăng nhập đúng mật khẩu.

Hủy yêu cầu xóa, đổi trạng thái và tạo session trong cùng transaction, khóa user
trước request xóa. Nếu request đã processing/đến hạn, thiếu `scheduled_at` hoặc
trạng thái không nhất quán: `403 ACCOUNT_DELETION_IN_PROGRESS`, không tự kích hoạt.
Không gọi hàm `admin_cancel_deletion()` bằng danh tính người dùng mobile.

Khóa tạm trả `429 LOGIN_TEMPORARILY_LOCKED` với `Retry-After`; áp dụng cách phản hồi
nhất quán cho identifier không tồn tại để hạn chế dò tài khoản.

## 9. Làm mới phiên

`POST /api/v1/auth/refresh`

```json
{
  "refreshToken": "<current-refresh-token>"
}
```

Response `200`:

```json
{
  "tokenType": "Bearer",
  "accessToken": "<new-access-token>",
  "expiresIn": 900,
  "refreshToken": "<new-refresh-token>",
  "sessionExpiresAt": "2026-11-16T03:00:00Z"
}
```

Mỗi lần thành công xoay refresh token trong transaction, giữ session ID và hạn phiên.
Access token không được có hạn vượt hạn phiên. Mobile thay bộ token atomically,
chỉ cho một request refresh chạy tại một thời điểm.

| HTTP | Code | Ý nghĩa |
|---|---|---|
| 401 | `REFRESH_TOKEN_INVALID` | Token không nhận diện được |
| 401 | `SESSION_EXPIRED` | Phiên hết hạn |
| 401 | `SESSION_REVOKED` | Phiên còn bản ghi nhưng đã bị thu hồi |
| 401 | `REFRESH_TOKEN_REUSED` | Token đã xoay bị dùng lại; thu hồi cả phiên này |
| 403 | `ACCOUNT_UNAVAILABLE` | User không còn active |

Không tự hủy yêu cầu xóa qua refresh. Hai request dùng cùng refresh token:
chỉ một request có thể thành công; request còn lại bị coi là reuse và thu hồi phiên.
Nếu mất response sau khi token đã xoay, client có thể phải đăng nhập lại.
Nếu bản ghi phiên và lịch sử token đã bị xóa, server không còn nhận diện được secret:
refresh trả `REFRESH_TOKEN_INVALID`; `/me` vẫn trả `SESSION_REVOKED` dựa trên sid trong JWT.

## 10. Đăng xuất

`POST /api/v1/auth/logout`

```json
{
  "refreshToken": "<refresh-token-of-current-session>"
}
```

Không yêu cầu access token còn hạn. Refresh token hiện tại hoặc token lịch sử
nhận diện được phiên đều có thể thu hồi phiên đó; không dùng logout để cấp token.
Đặt `revoked_at` nếu chưa thu hồi; response `204`, không có body.
Token không nhận diện được/đã hết hạn/đã thu hồi cũng trả `204`.
Body thiếu hoặc sai kiểu vẫn trả `422 VALIDATION_ERROR`.

Chỉ thu hồi phiên gắn với token gửi lên. Vô hiệu đăng ký push liên kết phiên đó.
Mobile xóa token và lựa chọn tài khoản/trẻ đang hoạt động rồi về màn đăng nhập.
Dữ liệu tính năng đang lưu local được giữ theo chủ sở hữu để tránh mất hồ sơ khi
chưa có API đồng bộ trẻ; tài khoản khác không được đọc dữ liệu đó. Khi offline,
server chỉ được thu hồi khi nhận được request. Không mô tả logout
offline là đã thu hồi thành công trên server.

## 11. Lấy người dùng hiện tại

`GET /api/v1/auth/me`

Response `200`: đối tượng `User` ở mục 3.

Mỗi request được bảo vệ phải kiểm tra chữ ký/issuer/audience/hạn access token,
`sub`, `sid`, session thuộc user, phiên chưa hết hạn/chưa thu hồi và user active.
Không chỉ kiểm tra chữ ký JWT. Token mobile không được dùng cho API admin.

Lỗi: `401 ACCESS_TOKEN_INVALID`, `401 ACCESS_TOKEN_EXPIRED`,
`401 SESSION_EXPIRED`, `401 SESSION_REVOKED`, `403 ACCOUNT_UNAVAILABLE`.
Response `401` của API Bearer kèm `WWW-Authenticate: Bearer`.

## 12. Ánh xạ database và migration cần bổ sung

Nguồn: `backend/migrations/001_initial_schema.sql` đến `006_activity_ai_rubric.sql`.

| Bảng hiện có | Cách dùng |
|---|---|
| `account.users` | Tài khoản pending/active, hash mật khẩu, liên hệ và mốc xác minh |
| `account.verification_codes` | OTP đăng ký, hash mã, hạn dùng, số lần thử, thời điểm dùng |
| `account.user_sessions` | Hash refresh hiện tại, thiết bị, hạn phiên, thu hồi |
| `account.legal_documents` | Phiên bản điều khoản đang hiệu lực |
| `account.user_consents` | Chấp nhận theo document ID, IP và thời điểm |
| `account.device_tokens` | Đăng ký push cần được liên kết đúng phiên |
| `account.data_deletion_requests` | Hủy yêu cầu chờ khi đăng nhập lại hợp lệ |
| `account.contact_change_requests` | Khôi phục liên hệ; chưa xây API trong bản này |

Các bổ sung được triển khai tại `backend/migrations/007_mobile_auth.sql`:

- Thêm `failed_login_attempts`, `locked_until`, `password_changed_at` cho users.
- Thêm `last_used_at` cho user_sessions.
- Thêm bảng challenge đăng ký: user ID, target, hash registration token duy nhất,
  expires_at, revoked_at, created_at; FK user `ON DELETE CASCADE`.
- Thêm bảng lịch sử refresh: session ID, hash token duy nhất, used_at;
  FK session `ON DELETE CASCADE`, giữ đến khi phiên hết hạn để nhận diện reuse.
- Thêm liên kết session cho device_tokens và index tra cứu. Khi đăng ký FCM token
  trên phiên mới phải chuyển liên kết sang phiên mới, tránh logout phiên cũ vô hiệu
  push của phiên mới. Cập nhật luồng push để bỏ qua phiên hết hạn/thu hồi.
- Thêm bộ đếm quota dùng chung giữa các worker (PostgreSQL hoặc kho dùng chung);
  không chỉ đếm trong bộ nhớ process.

Mật khẩu dùng Argon2id. Refresh/registration token là secret ngẫu nhiên, chỉ lưu hash.
OTP ít entropy nên dùng hash có secret phía server (HMAC) và giới hạn số lần thử;
không dùng hash nhanh không có secret làm lớp bảo vệ duy nhất.

`anonymize_user()` hiện xóa sessions/OTP/device tokens: bảng mới phải cascade đúng.
`apply_due_contact_changes()` hiện xóa toàn bộ sessions và đặt liên hệ mới chưa xác minh:
dependency xác thực phải nhận ra phiên đã mất ngay. Luồng OTP khôi phục sau đổi liên hệ
cần purpose mới vì CHECK hiện tại chỉ có register/reset_password/change_email/change_phone;
không dùng OTP register để vượt qua luồng recovery.

## 13. Checklist nghiệm thu và tích hợp mobile

- Đăng ký → OTP đúng → nhận token → `/me` → refresh → logout → `/me` bị từ chối.
- Unique email/phone/username vẫn đúng khi hai request đồng thời; lỗi constraint được
  ánh xạ thành `ACCOUNT_CONFLICT`, không trả lỗi SQL cho client.
- OTP sai/hết hạn/dùng lại/gửi lại, vượt quota và lỗi provider đều có trạng thái rõ ràng.
- Đăng nhập pending tiếp tục được xác thực, không ghi đè mật khẩu qua register.
- Refresh đồng thời/reuse và logout một trong hai thiết bị không cấp nhầm quyền.
- Login hủy xóa được kiểm thử đồng thời với job anonymize; refresh không tự hủy xóa.
- Logout/khôi phục liên hệ/xóa tài khoản khiến phiên cũ mất quyền ngay.
- Mobile thay OTP cố định và lời gọi auth DemoStore; không lưu mật khẩu trong preferences.
- Mobile đồng bộ validator username/mật khẩu, ánh xạ `role → relationship`, hiển thị
  điều khoản thực tế, lưu refresh token trong kho an toàn khi chọn ghi nhớ.
- Khi khởi động, mobile khôi phục phiên theo rememberMe; chỉ chuyển tới màn chính
  khi xác thực phiên thành công, không suy ra đăng nhập từ dữ liệu demo.

## 14. Quyết định triển khai

1. Giữ cả email và SĐT bắt buộc theo UI, xác minh SĐT trước khi kích hoạt.
2. Chỉ đăng nhập bằng email ở phiên bản đầu; username là tên công khai.
3. Mật khẩu tối thiểu 10 ký tự; phiên 24 giờ/30 ngày; access token 15 phút.
4. Đăng nhập đúng mật khẩu tự hủy yêu cầu xóa còn chờ theo migration hiện có.
5. Dùng registration secret riêng và lịch sử refresh để hỗ trợ tiếp tục đăng ký,
   chống gửi OTP trái phép và phát hiện refresh token bị dùng lại.

6. Consent trùng document ID/sai UUID trả `422 VALIDATION_ERROR`; document ID không
   tồn tại hoặc không phải phiên bản hiện hành trả `409 LEGAL_CONSENT_REQUIRED`.
7. Đăng nhập đúng mật khẩu reset bộ đếm sai và khóa tạm; sau khi hết khóa,
   lần thử sai tiếp theo bắt đầu lại từ 1. Quota SMS không reset qua login.
8. Lỗi thiếu cấu hình AUTH_SECRET trả `503 AUTH_NOT_CONFIGURED`; lỗi PostgreSQL
   được kiểm soát trả `503 DATABASE_UNAVAILABLE`. Chưa cấu hình SMS hoặc provider
   lỗi trả challenge với deliveryStatus failed, không có OTP mặc định.
9. Đăng ký thêm giới hạn 20 request/IP/giờ. IP lấy từ kết nối đã được uvicorn
   xử lý theo cấu hình proxy tin cậy, không đọc trực tiếp X-Forwarded-For trong route.
10. `/me` kiểm tra phiên trước trạng thái user: session đã xóa/thu hồi trả 401,
    session còn hiệu lực nhưng user không active trả 403. Các trường contact/profile
    nullable trong User phản ánh dữ liệu được phép null trong DB.
11. Dữ liệu hồ sơ trẻ vẫn là cache local hiện có; auth không triển khai API hồ sơ trẻ.
    Đổi mật khẩu/cập nhật liên hệ chưa có API nên mobile không giả vờ lưu thay đổi
    tài khoản server vào DemoStore.
12. Khi offline logout xóa token/lựa chọn đang hoạt động ngay và thông báo nếu chưa thu hồi được
    phiên server. Push chỉ được vô hiệu nếu device_tokens đã liên kết session;
    API đăng ký FCM/worker gửi push nằm ngoài phạm vi auth hiện tại.
