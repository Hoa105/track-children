# Kế hoạch kiểm thử Mobile Auth

Ngày: 17/10/2026. Trạng thái: kế hoạch dựa trên contract nháp, **chưa chạy test auth**.

Cập nhật triển khai: mã auth và kiểm thử tự động đã được thực hiện. Xem
[kết quả kiểm thử](mobile-auth-test-results.md) để phân biệt phần đã chạy và phần
provider/thiết bị/staging còn cần nghiệm thu. Nội dung bên dưới giữ vai trò kế hoạch gốc.

Nguồn yêu cầu: [OpenAPI JSON](mobile-auth.openapi.json), [mô tả nghiệp vụ](mobile-auth.md),
schema `backend/migrations/001`–`006` và các migration auth sẽ bổ sung.
Hiện backend chỉ có test `/health`; tài liệu này không phải báo cáo tính năng đã chạy được.

## 1. Mục tiêu và phạm vi

Xác nhận đăng ký → xác thực OTP → đăng nhập → làm mới token → đăng xuất hoạt động
đúng contract, dữ liệu được ghi nhất quán và không truy cập được bằng phiên đã mất hiệu lực.

Bao phủ 8 endpoint: legal-documents, register, register/verify, register/resend,
login, refresh, logout, me. Bao gồm trạng thái tài khoản, consent, giới hạn thử,
nhiều thiết bị, request đồng thời và các tác động từ khôi phục/xóa tài khoản.

Không kiểm thử chức năng OAuth, quên/đổi mật khẩu, API admin hoặc chức năng hồ sơ trẻ
trong đợt này. Chỉ kiểm tra chúng ở ranh giới liên quan như token admin bị từ chối
và session bị xóa khi job recovery/anonymize chạy.

Ưu tiên:

- **P0:** chặn phát hành nếu sai; cấp quyền, thu hồi phiên, OTP, toàn vẹn dữ liệu.
- **P1:** phải hoàn tất trước nghiệm thu; validation, rate limit, lỗi dịch vụ, mobile.
- **P2:** kiểm tra bổ sung; khả năng sử dụng và tải đo đạc.

## 2. Môi trường và dữ liệu chuẩn bị

- Backend test trỏ tới PostgreSQL riêng, chạy đủ migrations hiện hành và migration
  auth bổ sung. Không dùng SQLite thay thế cho integration test vì có citext,
  schema, trigger, inet, khóa và hàm PostgreSQL.
- Chặn chạy bộ test làm sạch dữ liệu nếu URL không thuộc database test được cho phép.
  Không dùng tài khoản hoặc SĐT thật trong fixtures.
- SMS provider giả ghi nhận yêu cầu gửi trong test harness; có thể giả lập thành công,
  timeout, từ chối. Lấy OTP từ harness, không thêm API công khai trả OTP.
- Clock có thể điều khiển và đồng bộ giữa API/DB; không sleep 5 phút để chờ OTP hết hạn.
  Kiểm tra riêng các truy vấn dùng thời gian DB nếu clock ứng dụng đã được giả lập.
- Reset quota, clock, SMS và dữ liệu giữa test; không để ca này làm khóa tài khoản ca sau.
- Ca song song dùng kết nối DB độc lập, barrier và commit thật. Không bọc toàn bộ ca
  trong một transaction rollback khiến request khác không thấy dữ liệu fixture.
- Chuẩn bị hai worker dùng cùng DB/kho rate limit để xác minh giới hạn dùng chung.

| Fixture | Dữ liệu cần có |
|---|---|
| A | User active, đã xác minh SĐT, chưa xác minh email |
| B | User pending, mật khẩu đã biết và OTP còn hạn |
| C | User locked |
| D | User pending_deletion, request pending, scheduled_at ở tương lai |
| E | Các biến thể xóa: processing, tới hạn, thiếu scheduled_at, thiếu request |
| F | User đã anonymize, không còn email/SĐT/username |
| G | Hai user khác nhau để kiểm tra không truy cập chéo |
| S1/S2 | Hai phiên của cùng user trên hai thiết bị |
| L | Điều khoản terms/privacy/data_policy: bản cũ, hiện hành, tương lai; ai_training riêng |
| O | OTP đúng/sai/hết hạn/đã dùng/hết lượt/bị thay thế |

## 3. Smoke test P0 xuyên suốt

1. GET điều khoản; ghi lại document ID hiện hành.
2. POST register bằng dữ liệu mới và đầy đủ consent → 201, user pending.
3. Lấy OTP từ SMS harness; POST verify → 200, user active, nhận token.
4. GET me bằng access token → đúng user, emailVerifiedAt vẫn null.
5. POST login trên thiết bị thứ hai → tạo phiên độc lập.
6. POST refresh trên phiên đầu → nhận bộ token mới, giữ session ID và hạn phiên.
7. POST logout bằng refresh mới → 204.
8. GET me và refresh bằng token của phiên đầu → bị từ chối; phiên thứ hai vẫn dùng được.

Mỗi bước kiểm tra HTTP, body theo OpenAPI và dữ liệu DB; không chỉ kiểm tra status code.

## 4. Ma trận ca kiểm thử API

Các đường dẫn dưới đây có prefix `/api/v1`. Với lỗi cần kiểm tra code, envelope
`error.code/message/fields/details` và không trả stack trace hoặc lỗi SQL.

### 4.1. Contract và điều khoản

| ID | Ưu tiên | Thao tác/điều kiện | Kết quả mong đợi |
|---|---|---|---|
| CON-01 | P1 | Kiểm tra mọi response mẫu, request hợp lệ và lỗi | Khớp schema OpenAPI; UUID, timestamp, enum và kiểu dữ liệu đúng |
| CON-02 | P1 | JSON hỏng, thiếu body, sai kiểu/thiếu trường bắt buộc | 422 VALIDATION_ERROR theo envelope; không lỗi 500 |
| CON-03 | P0 | Register/verify/login/refresh trả token | Cache-Control: no-store; không có password/OTP/hash trong response |
| LEG-01 | P0 | GET /legal-documents?context=registration với fixture L | 200; chọn bản effectiveAt mới nhất không vượt hiện tại cho mỗi loại |
| LEG-02 | P1 | Có bản tương lai và ai_training | Không trả bản tương lai/ai_training trong context đăng ký |
| LEG-03 | P0 | Thiếu văn bản bắt buộc do cấu hình | 503 LEGAL_DOCUMENTS_UNAVAILABLE; register không tạo user bỏ qua consent |
| LEG-04 | P1 | Thiếu context hoặc context sai | 422 VALIDATION_ERROR |

### 4.2. Đăng ký

| ID | Ưu tiên | Thao tác/điều kiện | Kết quả mong đợi |
|---|---|---|---|
| REG-01 | P0 | Register hợp lệ, SMS thành công | 201 challenge; user pending, consent đúng document ID, OTP register chưa dùng; chưa có session |
| REG-02 | P1 | Tên có khoảng trắng; username uppercase; SĐT Việt Nam 0… | Trim/lowercase đúng; SĐT lưu E.164; không biến đổi password |
| REG-03 | P1 | Tham số hóa fullName 0/1/150/151, username 2/3/30/31 và ký tự cấm, password 5/6/128/129 v? thi?u t?ng nh?m k? t? | Chấp nhận đúng biên theo contract sau chuẩn hóa |
| REG-04 | P1 | Email sai/quá 254; SĐT không hợp lệ; relationship ngoài enum | 422 và fields phù hợp; không ghi dữ liệu |
| REG-05 | P0 | Trùng email khác hoa thường, SĐT tương đương sau chuẩn hóa, username | 409 ACCOUNT_CONFLICT; không cập nhật user cũ |
| REG-06 | P0 | Register lại tài khoản pending với mật khẩu khác | 409; password hash, consent và OTP không bị ghi đè |
| REG-07 | P0 | Thiếu/từ chối/bản cũ của consent bắt buộc | 409 LEGAL_CONSENT_REQUIRED; không có tài khoản đăng ký dở |
| REG-08 | P1 | Document ID lặp, sai UUID hoặc không tồn tại | Lỗi validation/consent đã chốt; không 500, không ghi một phần |
| REG-09 | P0 | Gây lỗi DB ở bước ghi consent/OTP | Rollback user, consent, OTP; không gửi SMS trước commit |
| REG-10 | P1 | SMS timeout/từ chối sau commit | 201 deliveryStatus failed; vẫn có challenge và có thể resend; không trả OTP |
| REG-11 | P1 | Quá quota gửi theo SĐT/IP | 429 RATE_LIMITED + Retry-After; không tạo thêm OTP/SMS vượt quota |

### 4.3. Xác thực và gửi lại OTP

| ID | Ưu tiên | Thao tác/điều kiện | Kết quả mong đợi |
|---|---|---|---|
| OTP-01 | P0 | Verify đúng challenge và mã | 200 AuthResult; used_at và phone_verified_at được đặt; active; đúng một session |
| OTP-02 | P0 | OTP đúng nhưng registrationToken sai/hết hạn/thuộc user khác | 401 REGISTRATION_CHALLENGE_INVALID; không tăng attempts của user bị nhắm tới |
| OTP-03 | P0 | Mã sai lần 1–5 | Tăng attempts được commit; attemptsRemaining đúng; không cấp phiên |
| OTP-04 | P0 | Tiếp tục verify sau khi hết 5 lượt | 429 OTP_ATTEMPTS_EXCEEDED; mã đúng cũng không vượt qua giới hạn |
| OTP-05 | P0 | OTP tại thời điểm expiresAt hoặc sau đó | 410 OTP_EXPIRED; không kích hoạt |
| OTP-06 | P0 | Verify lại sau thành công | Không tạo phiên thứ hai; trả lỗi theo thứ tự kiểm tra challenge đã chốt |
| OTP-07 | P1 | Mã không đủ 6 chữ số, có chữ, gửi kiểu number | 422; giữ nguyên số 0 đầu khi gửi chuỗi |
| OTP-08 | P0 | Trộn verificationId user B với token user A; mã purpose khác register | Bị từ chối, không cập nhật user hoặc OTP khác |
| OTP-09 | P1 | Resend hợp lệ sau cooldown | 200 ID mới, mã cũ hết hiệu lực, attempts mới 0, không gia hạn registrationToken |
| OTP-10 | P1 | Resend trước cooldown/qua quota | 429 + Retry-After; không gửi SMS hoặc reset attempts |
| OTP-11 | P1 | SMS resend thất bại | deliveryStatus failed; mã cũ vẫn mất hiệu lực; gửi lỗi vẫn tính quota |
| OTP-12 | P0 | Resend sau token hết 30 phút hoặc user không còn pending | Không tạo OTP/phiên; lỗi challenge/account phù hợp |
| OTP-13 | P0 | Gây lỗi DB khi tạo session sau khi mã đúng | Rollback kích hoạt, used_at và session; có thể thử lại an toàn |

### 4.4. Đăng nhập và trạng thái tài khoản

| ID | Ưu tiên | Thao tác/điều kiện | Kết quả mong đợi |
|---|---|---|---|
| LOG-01 | P0 | Active + đúng email/password | 200 AuthResult, last_login_at cập nhật, hash refresh và device đúng |
| LOG-02 | P0 | Email không tồn tại hoặc sai password | Cùng 401 INVALID_CREDENTIALS và message; không lộ user/status |
| LOG-03 | P0 | Pending + đúng password | 403 VERIFICATION_REQUIRED, details.registration hợp lệ; chưa có session |
| LOG-04 | P0 | Login pending lặp trong cooldown | deliveryStatus deferred; không đổi mã/reset attempts; token challenge cũ bị vô hiệu |
| LOG-05 | P0 | Locked + đúng password | 403 ACCOUNT_LOCKED; không có session |
| LOG-06 | P0 | Deleted/identifier cũ sau anonymize | Không đăng nhập/khôi phục được; không lỗi do hash !deleted |
| LOG-07 | P1 | rememberMe false/true/bỏ qua | Hạn tuyệt đối 24 giờ/30 ngày/30 ngày, tính bằng clock test |
| LOG-08 | P1 | Sai password đạt ngưỡng, thử trong/sau 15 phút | 429 khi khóa tạm; Retry-After đúng; hết hạn cho thử lại |
| LOG-09 | P1 | Thử identifier không tồn tại theo cùng ngưỡng | Phản hồi giới hạn nhất quán, không tạo kênh dò tồn tại |
| LOG-10 | P1 | Vượt 30 lần/IP/phút qua hai worker | 429 RATE_LIMITED; bộ đếm dùng chung |
| DEL-01 | P0 | Fixture D + đúng password | Request cancelled, cancelled_at cập nhật, user active, AuthResult.deletionRequestCancelled true |
| DEL-02 | P0 | Fixture D + password sai | Không hủy xóa, không thay trạng thái |
| DEL-03 | P0 | Fixture E + đúng password | 403 ACCOUNT_DELETION_IN_PROGRESS; không cấp phiên/hủy request |
| DEL-04 | P0 | Gây lỗi tạo session trong luồng hủy xóa | Rollback hủy request và đổi trạng thái user |

### 4.5. Refresh, logout và me

| ID | Ưu tiên | Thao tác/điều kiện | Kết quả mong đợi |
|---|---|---|---|
| SES-01 | P0 | Refresh token hiện hành | 200 token mới; hash cũ vào lịch sử; cùng sid và sessionExpiresAt |
| SES-02 | P0 | Refresh bằng token đã xoay | 401 REFRESH_TOKEN_REUSED; cả phiên bị thu hồi; token mới cũng mất quyền |
| SES-03 | P0 | Token ngẫu nhiên/phiên hết hạn/bị thu hồi | 401 code tương ứng; không tạo/khôi phục phiên |
| SES-04 | P0 | User chuyển locked/pending_deletion/deleted trước refresh | Không cấp token, không tự hủy xóa; phiên tồn tại nhưng user không active trả 403 |
| SES-05 | P0 | Refresh gần hạn phiên | Access token không vượt hạn phiên; không kéo dài sessionExpiresAt |
| SES-06 | P0 | Logout bằng refresh hiện hành hoặc lịch sử | 204, thu hồi đúng phiên, access token cũ không dùng được ngay |
| SES-07 | P1 | Logout lặp/token lạ/hết hạn/đã thu hồi | 204 không body; thiếu token/sai kiểu trả 422 |
| SES-08 | P0 | Logout S1, còn S2 cùng user | S1 mất quyền; S2 vẫn me/refresh thành công |
| SES-09 | P0 | GET me với token hợp lệ | 200 đúng user; không lấy user ID do client chỉ định |
| SES-10 | P0 | Thiếu/sai chữ ký, issuer/audience, token admin, token hết hạn | 401 và WWW-Authenticate: Bearer; không trả thông tin user |
| SES-11 | P0 | JWT sub/sid không khớp, session mất/thu hồi/hết hạn | Bị từ chối dù chữ ký JWT đúng |
| SES-12 | P0 | User không active trong khi JWT và session còn hạn | 403 ACCOUNT_UNAVAILABLE; không truy cập dữ liệu |
| SES-13 | P0 | Chạy apply_due_contact_changes() cho fixture hợp lệ | Mọi phiên cũ mất quyền; verified_at liên hệ mới null |
| SES-14 | P0 | Chạy anonymize_user() với user không sở hữu trẻ | Không còn session/OTP/challenge/token history liên quan; consent giữ theo chính sách |
| SES-15 | P0 | FCM token chuyển liên kết từ S1 sang S2 rồi logout S1 | Không vô hiệu push S2; logout S2 ngừng push; worker bỏ qua phiên mất hiệu lực |

## 5. Transaction và request đồng thời

| ID | Ưu tiên | Tình huống có barrier | Bất biến cần kiểm tra |
|---|---|---|---|
| RACE-01 | P0 | Hai register cùng email/SĐT/username | Một user được tạo; request còn lại 409, không 500 hoặc consent mồ côi |
| RACE-02 | P0 | Hai verify cùng OTP | Tối đa một lần kích hoạt và một session; request còn lại bị từ chối |
| RACE-03 | P0 | Verify đồng thời resend | Trạng thái tương ứng một thứ tự tuần tự hợp lệ; không dùng OTP đã bị thay thế |
| RACE-04 | P0 | Hai refresh cùng token | Một request thành công, một reuse; cuối cùng phiên bị thu hồi theo contract |
| RACE-05 | P0 | Refresh đồng thời logout | Không còn phiên sử dụng được sau logout; token trả về nếu có cũng bị từ chối |
| RACE-06 | P0 | Login hủy xóa đồng thời anonymize job | Chỉ hủy xóa hợp lệ trước hạn hoặc xóa hoàn tất; không cấp phiên cho user deleted |
| RACE-07 | P0 | Login/refresh đồng thời job đổi liên hệ | Không có phiên hợp lệ dựa trên thông tin cũ sau khi job áp dụng |
| RACE-08 | P1 | Hai worker resend tại cùng mốc cooldown | Không vượt quota; không có hai OTP cùng hiệu lực cho cùng mục đích/target |

Không dùng retry mù để che lỗi deadlock. Kiểm tra kết quả DB sau khi cả request
commit; transaction lỗi phải rollback và trả lỗi được kiểm soát.

## 6. Kiểm tra bảo mật và dữ liệu

- P0: password không lưu/ghi log dạng rõ; xác minh được bằng bộ hash đã chọn.
  OTP và refresh/registration token chỉ lưu dạng hash phù hợp, không xuất hiện trong
  access log, error log, telemetry hoặc snapshot CI.
- P0: registration token chỉ cho verify/resend đúng user/target, không dùng như Bearer
  gọi me; refresh token cũng không thay thế access token.
- P0: thông tin SQL injection được coi là dữ liệu; không bypass xác thực hoặc gây
  lộ truy vấn. Không cấp phiên từ tham số client tự gửi như status/userId/verifiedAt.
- P1: quota không reset khi đổi worker, login pending lại hoặc resend SMS thất bại.
- P1: dữ liệu IP lấy từ kết nối/proxy đã cấu hình tin cậy; body hoặc header proxy
  từ client không tin cậy không ghi đè tùy ý.
- P1: consent lưu đúng phiên bản và timestamp; thiếu consent rollback toàn bộ đăng ký.
- P1: dữ liệu thời gian UTC và mốc bằng hạn được xử lý nhất quán; kiểm tra đúng
  `now >= expires_at` là hết hạn ở OTP, challenge và session.

## 7. Kiểm thử tích hợp mobile

Chạy sau khi backend và mobile đã nối API, dùng tài khoản test và SMS harness/staging.

| ID | Ưu tiên | Kịch bản | Kết quả mong đợi |
|---|---|---|---|
| MOB-01 | P1 | Đăng ký đủ trường + điều khoản thực tế | Gọi register rồi verify; bỏ OTP 123456 và auth DemoStore |
| MOB-02 | P1 | Sai OTP, hết hạn, gửi lại, SMS failed/deferred | Hiển thị đúng lỗi/cooldown, giữ challenge phù hợp, không điều hướng sớm |
| MOB-03 | P1 | Đóng app giữa đăng ký, đăng nhập lại pending | Nhận challenge mới và tiếp tục được, không ghi đè password |
| MOB-04 | P0 | Login thành công rồi mở lại app, rememberMe true | Refresh token ở kho an toàn; xác thực lại phiên trước khi vào dữ liệu riêng |
| MOB-05 | P1 | rememberMe false rồi đóng/mở app | Không lưu refresh bền vững, yêu cầu đăng nhập lại |
| MOB-06 | P0 | Nhiều API cùng gặp access token hết hạn | Một request refresh dùng chung; thay token atomically, không tự gây reuse |
| MOB-07 | P0 | Logout rồi đăng nhập tài khoản khác | Không còn cache/thông tin trẻ của tài khoản trước; push gắn đúng phiên |
| MOB-08 | P1 | Mất mạng lúc login/verify/logout/refresh | Thông báo và loading kết thúc; không báo thu hồi server thành công khi logout offline |
| MOB-09 | P1 | Mất response refresh sau server commit | Xử lý yêu cầu đăng nhập lại an toàn; không loop refresh vô hạn |
| MOB-10 | P1 | Username/password không đúng biên contract | Validator đồng bộ; role ánh xạ relationship; password không lưu preferences |

## 8. Tổ chức thực hiện và tự động hóa

1. **Review contract:** giải quyết các điểm ở mục 10; thống nhất mã lỗi và schema.
2. **Nền tảng:** chuẩn bị PostgreSQL test, migration, clock, SMS fake, fixture và quota.
3. **Backend integration:** thực hiện smoke + ca API/DB P0, sau đó P1; dùng pytest
   và HTTP client hiện có. Kiểm thử qua route thật, không mock repository ở integration.
4. **Concurrency:** chạy với kết nối độc lập và hai worker; kiểm tra bất biến DB.
5. **Mobile/staging:** chạy kịch bản tích hợp, sau đó một smoke SMS thật bằng tài khoản
   test được phép; không dùng SMS thật trong CI.
6. **Báo cáo:** ghi kết quả theo ID, lỗi còn mở, phiên bản contract/backend/mobile và môi trường.

Cấu trúc test gợi ý khi bắt đầu triển khai:

```text
backend/tests/auth/
  conftest.py
  test_legal_documents.py
  test_registration.py
  test_verification.py
  test_login.py
  test_sessions.py
  test_concurrency.py
  test_account_lifecycle.py
```

CI mỗi thay đổi auth: kiểm tra JSON/OpenAPI, migration trên DB mới, smoke và integration
P0/P1 đã tự động hóa. Chạy concurrency khi thay đổi session/OTP/lifecycle. Không lấy
test DemoStore hiện tại làm bằng chứng backend auth đã hoạt động.

Đo tải P2 trên staging riêng: login/refresh ở mức 1, 10, 50 request đồng thời;
ghi p50/p95, tỷ lệ lỗi, kết nối DB và CPU hash mật khẩu. Dùng nhiều tài khoản/IP test
được cấu hình để tách giới hạn nghiệp vụ khỏi năng lực xử lý; không tắt rate limit
trên môi trường thật. Chốt ngân sách latency trước khi dùng kết quả làm release gate.

## 9. Điều kiện bắt đầu và nghiệm thu

**Bắt đầu chạy:** API/migration auth đã có, OpenAPI được chốt cho vòng test, DB test
độc lập và SMS fake/clock hoạt động. Ca có phụ thuộc chưa làm được đánh dấu Blocked,
không đánh dấu Passed dựa trên mock khác với implementation.

**Nghiệm thu:**

- 100% ca P0 và P1 trong phạm vi được thực thi và đạt; không còn lỗi cấp quyền,
  mất dữ liệu, truy cập chéo hoặc bypass OTP/rate limit.
- Smoke xuyên suốt và ca concurrency đạt trên PostgreSQL; không có dữ liệu mồ côi.
- Request/response thực tế khớp OpenAPI; migration chạy được trên DB mới và DB đã có dữ liệu.
- Mobile hoàn tất các ca tích hợp sau khi chuyển khỏi auth demo.
- Các ca P2 chưa chạy, giới hạn provider và ngoại lệ được ghi rõ trong báo cáo.

Mẫu kết quả: `ID | Passed/Failed/Blocked/Not run | build/commit | bằng chứng | issue`.
Bằng chứng gồm status/code và truy vấn kiểm tra đã che dữ liệu nhạy cảm; không đính kèm token thật.

## 10. Các điểm contract cần chốt trước khi viết assertion

1. Verify thành công vô hiệu challenge; request lặp sẽ là
   REGISTRATION_CHALLENGE_INVALID hay OTP_ALREADY_USED? Chốt thứ tự kiểm tra;
   dù chọn mã nào vẫn phải không tạo phiên thứ hai.
2. Lần nhập OTP sai thứ 5 trả 400 attemptsRemaining=0 hay 429 ngay? Các lần sau
   bắt buộc 429. Hiện tài liệu chưa xác định ranh giới lần thứ 5.
3. Document ID trùng/không tồn tại trả 422 hay 409 LEGAL_CONSENT_REQUIRED?
   Phân biệt cấu trúc request sai với phiên bản consent không hợp lệ.
4. Quy tắc reset failed_login_attempts sau login thành công/hết khóa tạm và cách
   mô phỏng ngưỡng cho email không tồn tại cần thống nhất.
5. Contract OpenAPI và Markdown cần thống nhất nullable của User và ưu tiên lỗi
   khi session đã bị xóa đồng thời user không active.
6. OTP/challenge/quota phải quy định mốc biên và kiểu thời gian dùng chung giữa
   ứng dụng và DB trước khi chạy test điều khiển clock.

Các điểm này là khoảng trống để review, không tự thay đổi contract trong kế hoạch test.
