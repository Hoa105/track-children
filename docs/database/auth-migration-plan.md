# Auth — migration 009 đã gộp

SQL nguồn: [009_auth_database_simplification.sql](../../backend/migrations/009_auth_database_simplification.sql), theo [đặc tả](../../AUTH-DATABASE-CHANGE-SPEC.md).

## Chuỗi khởi tạo

Chạy các migration 001–008, rồi 009. Hai file 007 dùng version theo tên đầy đủ nên vẫn là hai migration riêng. Không còn file 010. 009 hiện tạo thẳng cấu trúc auth đích, không qua bước archive trung gian. Đây là gom lịch sử trong giai đoạn phát triển theo yêu cầu người dùng.

009 reset dữ liệu auth cũ, nhưng chặn và rollback nếu có bản ghi nghiệp vụ tham chiếu tài khoản. Giữ các bảng nghiệp vụ và đích FK bằng ALTER các bảng tài khoản. Không dùng DROP CASCADE để ép xóa nghiệp vụ. Phải sao lưu trước khi chạy.

## Kết quả cấu trúc

- account.users: 16 cột theo đặc tả, không username hoặc cột hồ sơ cũ; consented_at NOT NULL.
- account.user_sessions: 8 cột; remember_me mặc định true.
- admin.admin_users: 8 cột; is_active mặc định true, không RBAC.
- admin.admin_sessions: 6 cột; index toàn bộ admin_user_id.
- account.auth_codes: 12 cột; CHECK XOR, purpose/channel/counter và hai partial index.

Không còn auth_legacy, các bảng auth cũ hoặc registration_challenges/refresh_token_history/auth_rate_limits. Hàm ẩn danh hóa và hủy yêu cầu xóa dùng thiết kế mới. Ngoại lệ để xóa thông tin cá nhân: status=deleted được phép không còn email/phone; user sống phải có ít nhất một liên hệ. Không có pending_deletion trên user; yêu cầu và thời gian chờ xóa nằm trong data_deletion_requests.

Backend được cập nhật sau theo lựa chọn của người dùng; các truy vấn SQL cũ chưa tương thích schema mới.

## Seed

Hàm account.seed_local_auth_samples(text) nằm trong 009, không tự chạy khi migrate. Lệnh `python -m app.seed.local_auth` yêu cầu APP_ENV=local, băm mật khẩu bằng Argon2 rồi tạo 10 tài khoản giả tên tiếng Việt với 5 quan hệ. Mẫu active có consent và mốc xác minh email giả lập; không có username. Gọi lại không ghi đè tài khoản đã tồn tại. Không nạp mẫu trong đợt gom migration.

## DB đã chạy 009 và 010 cũ

track_children đã có schema cuối cùng từ lần chạy 010 trước đó. Không chạy lại 009 mới: sau khi kiểm tra schema tương đương, chỉ giữ ledger version 009_auth_database_simplification và bỏ version 010_auth_exact_design_reset trong cùng transaction. Sao lưu ledger trước khi sửa. Không đổi dữ liệu/schema trong bước gộp ledger.

Đã hoàn tất đối chiếu cột/kiểu/default/constraint/index và ba hàm lifecycle/seed với DB được tạo từ chuỗi mới. Đã gộp ledger trên track_children, giữ 009 và bỏ 010; không chạy reset và không thay dữ liệu. Bản sao ledger cũ: `.auth-test-logs/backups/auth-ledger-before-squash.json`. Kết quả kiểm thử: **4 passed**; danh mục 82 bảng và 129 FK khớp ma trận.

DB chỉ chạy 009 cũ mà chưa chạy 010 không tương đương với 009 mới: cần nâng cấp riêng hoặc tạo lại DB phát triển sau backup; không xóa ledger để ép chạy lại reset.

## Kiểm thử và backup

4 test PostgreSQL kiểm tra: tạo mới từ 001–008 rồi 009; cấu trúc đúng đặc tả/default/UNIQUE; seed lặp và ẩn danh hóa; chặn reset nếu có FK nghiệp vụ; CHECK XOR và consent NOT NULL. Tất cả dùng DB tạm có hậu tố _test.

```powershell
$env:AUTH_TEST_DATABASE_URL = 'postgresql://auth_test:auth_test_local@127.0.0.1:55439/track_children_auth_test'
python -m pytest backend/tests/database/test_auth_schema_upgrade.py -q
```

Backup trước reset thật vẫn giữ tên lịch sử: `.auth-test-logs/backups/track_children_before_auth010_20261023T092350Z.dump`. Đã phục hồi thử và xác nhận giữ dữ liệu 59 bảng nghiệp vụ. Tài liệu trước gom được lưu local tại `.auth-test-logs/backups/auth-migration-plan-before-consolidation.md`.

Runner: `./scripts/migrate.ps1 -Target backend`. Không chạy lại reset trên DB đã có dữ liệu mới.

## Dọn tài nguyên thử nghiệm

Đã xóa container `track-children-auth-test` kèm volume riêng, hai database phục hồi thử `auth009_restore_20261023_test` và `auth010_restore_20261023_test`, các script dùng một lần/SMS thử trong `.auth-test-logs` và cache pytest. Giữ nguyên database ứng dụng, container AI, mã nguồn/test và `.auth-test-logs/backups`.

URL kiểm thử ở trên chỉ dùng được sau khi tạo lại PostgreSQL test riêng. Ví dụ:

```powershell
docker run --detach --name track-children-auth-test --publish 127.0.0.1:55439:5432 --env POSTGRES_USER=auth_test --env POSTGRES_PASSWORD=auth_test_local --env POSTGRES_DB=track_children_auth_test postgres:16
```

Đợi PostgreSQL sẵn sàng trước khi chạy pytest. Không đổi URL test sang database ứng dụng để thay thế tài nguyên test đã dọn.
