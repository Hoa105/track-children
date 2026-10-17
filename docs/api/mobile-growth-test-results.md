# Kết quả kiểm thử Theo dõi tăng trưởng

Ngày: 18/10/2026. Nguồn: [contract](mobile-growth.openapi.json),
[kế hoạch 61 ca](mobile-growth-test-plan.md), [hướng dẫn chạy](mobile-growth.md).
Số test tự động không tương đương số ca nghiệp vụ; mỗi ca có thể được kiểm tra
bởi nhiều test hoặc chỉ được xác minh một phần.

## Phần đã triển khai

API đọc lịch sử/tổng quan, upsert chỉ số theo ngày trong transaction, xóa mềm,
audit và phân quyền owner/view/edit. BMI chỉ dùng cặp cùng ngày và làm tròn
ROUND_HALF_UP hai chữ số. Hồ sơ dùng UUID; đổi ngày sinh tính lại tuổi số đo active,
từ chối ngày sinh sau số đo đang tồn tại.

Mobile dùng API khi đăng nhập server: form sửa theo ngày, tư thế đo, xóa trong lịch sử,
giữ form khi lỗi, thử lại, dữ liệu dùng chung với Trang chủ và BMI từ server.
Không tự upload demo; cache tách theo user/child ID, bỏ response của phiên cũ.
Giữ tham chiếu WHO hiện có, không đối chiếu chiều cao/BMI khi tư thế không phù hợp.

## Môi trường

Windows, Python 3.12, Flutter SDK của máy; PostgreSQL 16 trong container riêng
`track-children-growth-test`, localhost 55440, database `track_children_growth_test`.
Chạy migrations `001`–`007`. Fixtures dùng ngày cố định 17/10/2026; test timezone
kiểm tra riêng thời điểm chuyển sang ngày 18/10 tại Việt Nam. Không dùng dữ liệu thật.

Python được chạy với dependency có sẵn trong `.test-deps` qua PYTHONPATH;
môi trường venv thông thường dùng `backend/requirements-dev.txt` thay thế.
Integration fixtures chỉ reset DB có hậu tố `_growth_test`.

## Kết quả tự động

Vòng cuối: **71 test backend đạt** (gồm benchmark opt-in), **164 test mobile đạt**,
**1 test Dart HTTP thật đạt** khi chạy riêng. Test live bị skip trong lệnh mobile mặc định
vì cần server riêng; đã chạy riêng với GROWTH_LIVE_TEST=true, không tính skip là pass.
Backend: `GROWTH_PERF=1 python -m pytest backend/tests -q`, 71 passed, 2 warnings.
Mobile: `flutter test --no-pub`, 164 passed, 1 skipped. Lệnh live xem hướng dẫn chạy.
Analyzer cuối cho toàn bộ file thay đổi/test mới: **No issues found**.
Sau rà soát cuối, đã kiểm tra thêm timestamp UTC khi session PostgreSQL dùng timezone
Asia/Ho_Chi_Minh và schema response: **2 test đạt**; đây là chạy lại ca đã có, không cộng vào 71.

| Bộ kiểm thử | Nội dung |
|---|---|
| Backend + health | PostgreSQL thật, validation, response schema, quyền, phiên, rollback, concurrency và HTTP thật |
| Mobile toàn repo | Hồi quy ứng dụng, service API, form remote, quyền view, retry và cách ly tài khoản |
| Dart live HTTP | Login → tạo trẻ → lưu/sửa → đọc BMI → xóa → logout với FastAPI/PostgreSQL thật |
| Analyzer phần thay đổi | Kiểm tra growth, services, auth login, child selection và test mới |

## Đối chiếu kế hoạch

| Nhóm ca | Bằng chứng | Giới hạn |
|---|---|---|
| SEC-01–09 | Owner/view/edit/none/revoked/left; ID khác trẻ; token/session hết hạn; sai audience; account không active | Chưa staging nhiều worker |
| SAVE-01–15 | Unit + HTTP: giới hạn, độ chính xác, null/field lạ, note scope, ngày sinh/ngày đo; rollback lỗi sau ghi | Lỗi DB được inject trong test |
| READ-01–07, BMI-01–04 | Empty, lọc bao gồm hai đầu, summary toàn lịch sử, cặp cùng ngày, sửa cặp, cm→m, timezone, schema | Không đánh giá độ chính xác y khoa |
| DEL-01–05, DB-01 | Soft-delete, gọi lại, ID mới khi nhập lại, summary lùi, audit | Không có UI khôi phục trong scope |
| CON-01–03 | Cùng metric/khác metric; PUT cạnh tranh DELETE trên kết nối độc lập | Xác minh thứ tự tuần tự hợp lệ; không dùng thứ tự response HTTP làm thứ tự commit |
| CON-04 | Gửi lại không tạo trùng; giữ form để retry | Chưa cắt mạng chính xác sau commit trên thiết bị thật |
| UI-01–06 | Growth widget hiện có, API mock, form remote, HTTP thật từ Dart | Chưa thao tác toàn bộ màn hình trên thiết bị thật |
| UI-07–09 | Cache/account isolation, response phiên cũ, view không được sửa, retry | Đổi trẻ giữa hai request HTTP thật chưa có device E2E |
| UI-10–12 | Lỗi HTTP, refresh song song, bảo toàn form, không fallback ghi local, empty không hiện demo | Chưa mất/khôi phục Wi-Fi thật trên Android/iOS |
| WHO-01–03 | Bộ test reference/profile/chart hiện có; code chặn đối chiếu tư thế sai | Chưa nghiệm thu trực quan mọi mốc tuổi |
| UI-13 | Widget/layout nhiều chiều rộng và cỡ chữ | Chưa bàn phím/native rendering trên Android/iOS thật |

## Hiệu năng

[Baseline JSON](mobile-growth-performance.json): 1.826 ngày, 5.478 số đo,
20 request đồng thời trên FastAPI TestClient/PostgreSQL Docker. Chưa gồm mạng thiết bị.
Các giá trị p50/p95 và payload được lưu trực tiếp trong JSON, không suy ra từ unit test.

| Thao tác | Kết quả cuối |
|---|---|
| GET toàn bộ 5 năm | p95 6.500,48 ms; 1.880.496 byte; 0 lỗi HTTP |
| GET khoảng ngày | p95 372,93 ms; 17.732 byte; 0 lỗi HTTP |
| PUT | p95 467,61 ms; 0 lỗi HTTP |
| DELETE gồm request chuẩn bị | Một lượt 166,88 ms; chưa phải p95 của 20 lượt DELETE |

Test benchmark thành công chỉ chứng minh thu được số liệu và không lỗi HTTP;
không chứng minh đạt mục tiêu độ trễ đề xuất trong kế hoạch. GET toàn bộ lịch sử
5 năm còn payload gần 1,9 MB và chậm khi tải đồng thời; cần cân nhắc phân trang
hoặc giảm mật độ điểm nếu dùng ở tải này. GET theo khoảng đã lọc trong SQL;
summary vẫn toàn lịch sử. Chỉ khóa hồ sơ khi ghi; đọc dùng snapshot nhất quán.

## Giới hạn nghiệm thu

Không xem báo cáo này là nghiệm thu production/thiết bị thật. Các ca còn thiếu
bằng chứng được ghi ở bảng trên; đặc biệt mạng thật, UI-13 và tải lịch sử dài.

Workspace ban đầu chỉ có auth demo. Phiên tối thiểu bổ sung cho tài khoản active
có sẵn không bao gồm SMS/đăng ký/khôi phục/nhớ phiên qua restart. Không tuyên bố
đã khôi phục hoặc kiểm thử toàn bộ contract auth được trao đổi trước đây.

Test HTTP có cảnh báo deprecation của thư viện WebSocket/uvicorn; không phải lỗi growth.
Analyzer toàn repo còn cảnh báo cũ ở `child_sharing_screen.dart` ngoài scope thay đổi.
Live server test đã dừng; container DB test giữ lại cho lần sau, không đổi DB ứng dụng.
