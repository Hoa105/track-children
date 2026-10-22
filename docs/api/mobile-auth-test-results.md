# Kết quả triển khai và kiểm thử Mobile Auth

Ngày chạy: 17/10/2026. Phiên bản: working tree hiện tại, contract `1.0.0`.
Kế hoạch gốc: [mobile-auth-test-plan.md](mobile-auth-test-plan.md).

## 1. Kết quả đã chạy

| Kiểm tra | Kết quả |
|---|---|
| `python -m pytest backend/tests -q` với PostgreSQL test thật | **74 passed**, 82,67 giây |
| `flutter test` toàn bộ mobile | **163 passed, 1 skipped**, khoảng 73 giây |
| Live Flutter HTTP smoke bật riêng | **1 passed**, khoảng 20 giây |
| OpenAPI 3.1 JSON validation | Passed |
| Flutter analyze trên 10 file/thư mục mã và test auth thay đổi | No issues found |
| Python compileall | Passed |
| `git diff --check` | Passed; Git chỉ thông báo chuyển LF/CRLF cho plugin registrant |

Một test live được skip có chủ đích trong lệnh Flutter thông thường vì cần server
test chạy riêng; chính test đó đã được bật và chạy thành công ở dòng live smoke.

Môi trường: Windows, Python 3.12.10, Flutter SDK cài sẵn của dự án, PostgreSQL 16
trong container riêng `track-children-auth-test`, cổng localhost 55439. Database
`track_children_auth_test` tách khỏi database ứng dụng. Đã kiểm tra migration đầy đủ
và upgrade `001`–`006` có tài khoản/phiên cũ lên `007` trong một DB test tạm riêng.

Test Python dùng SMS fake, clock điều khiển được và kết nối PostgreSQL thật.
Flutter unit/widget test dùng HTTP mock và secure storage giả. Riêng live smoke dùng
HTTP thật đến FastAPI và PostgreSQL thật, SMS được ghi vào file fixture riêng; secure
storage vẫn giả lập vì chạy trong Flutter test runner, không phải thiết bị vật lý.
Phân tích toàn dự án trước đó còn cảnh báo có sẵn ở `child_sharing_screen.dart`
(Radio deprecated và optional parameter chưa dùng); không sửa màn chia sẻ trong task auth.

## 2. Những phần đã triển khai

- 8 endpoint: điều khoản, register, verify, resend, login, refresh, logout, me.
- Argon2id cho mật khẩu; JWT access 15 phút; refresh secret chỉ lưu hash.
- OTP 6 chữ số, HMAC phía server, hạn 5 phút, tối đa 5 lần sai và cooldown/quota dùng chung.
- Challenge đăng ký riêng, có hạn 30 phút; không ghi đè tài khoản pending khi register lại.
- Rotation và lịch sử refresh; reuse thu hồi phiên; logout theo phiên, không ảnh hưởng
  phiên thiết bị khác. Dependency dùng lại được tại `app.shared.access.require_user`.
- Trạng thái pending/active/locked/pending_deletion/deleted; đăng nhập hợp lệ hủy
  yêu cầu xóa còn chờ trong một transaction, không khôi phục tài khoản đã anonymize.
- Migration `007`, importer điều khoản đã duyệt, SMS HTTPS webhook adapter và CLI
  dọn dữ liệu auth hết hạn.
- Mobile gọi API thay cho auth DemoStore, hiển thị điều khoản/OTP thật từ challenge,
  gửi lại OTP, tiếp tục đăng ký pending, nhớ đăng nhập, refresh một lần dùng chung,
  logout offline có thông báo đúng giới hạn.

## 3. Đối chiếu với kế hoạch

| Nhóm ca | Bằng chứng tự động hóa |
|---|---|
| Smoke P0 xuyên suốt | `test_smoke_two_devices`; `auth_live_test.dart` chạy riêng |
| Contract/validation | `test_auth_contract.py`; `test_actual_response_schemas`; JSON hỏng/sai kiểu và biên độ dài trong `test_boundaries.py` |
| Điều khoản/consent | `test_consent_and_legal_versions`, `test_consent_duplicates_and_unknown`; rollback khi thiếu consent |
| Đăng ký/chuẩn hóa/trùng dữ liệu | `test_normalization_conflict_consent`, `test_validation`, `test_length_boundaries`, `test_concurrent_register` |
| OTP/challenge/resend/quota | Các test OTP trong `test_auth.py`, `test_boundaries.py`; UI test sai mã → resend → xác thực bằng ID mới |
| Rollback transaction | `test_registration_rolls_back_after_insert`, `test_verify_rolls_back_activation_and_attempts_on_db_error`, `test_login_cancel_deletion_rollback` |
| Login/khóa tạm/trạng thái | `test_pending_login_continues_and_sms_failure`, `test_account_state`, `test_password_lockout`, `test_login_limits_unknown_identity_and_unlock` |
| Quota nhiều process | `test_shared_quota_across_processes`; thêm `test_ip_limit_shared_clients` |
| Session/JWT/refresh/logout | `test_smoke_two_devices`, `test_reuse_and_logout_idempotent`, `test_absolute_session_expiry`, `test_jwt_claims_and_session_binding` |
| Recovery/anonymize/hủy xóa | `test_lifecycle.py`, các test pending deletion trong `test_auth.py` và `test_boundaries.py` |
| RACE-01 đến RACE-06 | Các test concurrent register/verify/refresh, verify-resend, refresh-logout và login-anonymize |
| RACE-07 | Cả refresh và login đồng thời recovery đã chạy; không giữ lại phiên hợp lệ từ liên hệ cũ |
| RACE-08 | Hai resend cùng mốc cooldown: một thành công, một 429; chỉ một OTP còn hiệu lực |
| Push SES-15 | Kiểm tra DB liên kết session và logout không vô hiệu token của phiên khác; chưa kiểm thử worker gửi FCM thực tế |
| Mobile auth/cache | `auth_service_test.dart`, `auth_widgets_test.dart`, test login/signup trong `widget_test.dart` |
| Hồi quy tính năng mobile | Toàn bộ `flutter test`: tăng trưởng, nhật ký, tiêm chủng, mọc răng, chia sẻ, giao diện... |

Bảng trên là phạm vi bằng chứng thực tế, không đồng nghĩa mọi biến thể thủ công
trong kế hoạch đã được chạy. Các test contract kiểm tra schema response đại diện;
không phải mọi tổ hợp response đều đã được validate riêng theo schema.

## 4. Các lỗi đã phát hiện và xử lý

- Map cache của user server bị suy luận thành `Map<dynamic, dynamic>`: khai báo kiểu
  tường minh, test xác nhận không lưu password và không đọc chéo hồ sơ.
- Spinner phía sau dialog điều khoản/OTP làm widget test không settle: loading chỉ
  bật lúc request đang chạy; tắt khi chờ người dùng nhập/xác nhận.
- Các test giao diện còn kỳ vọng login/OTP demo: thay bằng HTTP mock với challenge
  server và xác nhận OTP khác mã demo cũ.
- Test Home không đăng nhập vẫn kỳ vọng số đo mẫu cũ: kiểm tra đúng trạng thái
  chưa có dữ liệu, không hiển thị thông tin trẻ khi chưa chọn tài khoản.
- Test hết hạn dùng `now()` PostgreSQL lẫn clock host gây sai lệch trong môi trường
  Docker: đặt mốc bằng clock ứng dụng tường minh; session created/last-used/expiry
  được tạo từ cùng mốc ứng dụng. Các host triển khai vẫn cần đồng bộ thời gian.

## 5. Phần chưa xác nhận trên môi trường thật

- SMS nhà cung cấp thật: chưa có URL/credential để gửi; adapter HTTP đã có và được
  kiểm tra bằng fake. Cần cấu hình SMS_WEBHOOK_URL/TOKEN và smoke SMS staging.
- Nội dung điều khoản thật: importer đã có, nhưng không tự tạo/chấp nhận nội dung
  pháp lý placeholder cho database ứng dụng. Cần nhập bản terms/privacy/data_policy đã duyệt.
- Android/iOS vật lý: chưa chạy app native, chưa kiểm tra Keychain/Keystore sau
  reinstall/backup và thông báo push trên máy thật.
- Chưa đo tải P2, tỷ lệ phát SMS, độ trễ staging hoặc nghiệm thu trải nghiệm mạng
  yếu ở mọi bước trên thiết bị thật.
- Chưa audit mọi luồng log/telemetry trong triển khai production; mã auth không
  ghi password/OTP/token vào log. Cần giữ nguyên chính sách này ở reverse proxy và SMS adapter.

Vì vậy, phần mã auth và các kiểm thử tự động đã chạy đạt; **chưa tuyên bố đạt toàn bộ
release gate P0/P1 của kế hoạch trên production**. Các hạng mục thiết bị/provider và
các biến thể còn thiếu ở mục 3 cần được thực hiện khi nghiệm thu staging.

## 6. Giới hạn phạm vi và cách chạy lại

Auth không triển khai API dữ liệu trẻ. Dữ liệu tính năng hiện vẫn local theo owner ID;
logout xóa credentials và lựa chọn đang hoạt động, giữ dữ liệu do người dùng tạo để
không mất hồ sơ trước khi có đồng bộ server. Tài khoản khác không đọc/chọn được hồ sơ đó.
Đổi mật khẩu/cập nhật liên hệ trên tài khoản server chưa có API trong phiên bản này;
mobile hiển thị chưa hỗ trợ thay vì giả vờ lưu thay đổi vào dữ liệu demo.

Hướng dẫn cấu hình, test runner và live smoke: [backend/README.md](../../backend/README.md).
Test tích hợp sẽ reset dữ liệu trong DB `_test`; không trỏ vào database ứng dụng.
Không chạy bộ test reset DB đồng thời với live smoke. Chưa deploy hoặc migrate
database ứng dụng trong lượt triển khai này.
Server live test và container PostgreSQL test đã được dừng sau kiểm thử;
`scripts/test-auth.ps1` có thể khởi động lại container cho lần chạy tiếp theo.
