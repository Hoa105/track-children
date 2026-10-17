# Kế hoạch kiểm thử Theo dõi tăng trưởng

Ngày: 17/10/2026. Contract: [Mobile Growth OpenAPI 0.1.0](mobile-growth.openapi.json).
Trạng thái gốc: **kế hoạch kiểm thử trước triển khai**. Cập nhật 18/10/2026:
đã bổ sung mã nguồn và chạy kiểm thử tự động; xem [kết quả và giới hạn](mobile-growth-test-results.md).
Các ca dưới đây là yêu cầu kiểm thử, không tự động được xem là đã đạt.

## 1. Phạm vi và mức ưu tiên

Kiểm thử ba endpoint đọc lịch sử/tổng quan, lưu số đo theo ngày và xóa mềm số đo;
cân nặng, chiều cao/chiều dài, vòng đầu, BMI; phân quyền; PostgreSQL; màn Theo dõi
và thao tác nhập số đo từ Trang chủ. Kiểm tra hồi quy biểu đồ WHO hiện có.

- P0: chặn phát hành nếu sai — truy cập dữ liệu, mất dữ liệu, transaction, BMI và trùng bản ghi.
- P1: bắt buộc trước nghiệm thu — validation, lịch sử, lọc ngày, UI, lỗi và hồi quy.
- P2: đánh giá bổ sung — hiệu năng, khả năng sử dụng và thiết bị mở rộng.

Ngoài phạm vi: Z-score, percentile, phân loại dinh dưỡng, đồng bộ ghi ngoại tuyến,
API quản lý chuẩn WHO và toàn bộ quy trình mời chia sẻ. Quyền chia sẻ vẫn phải kiểm thử
bằng fixture DB. Không đánh giá độ chính xác y khoa từ kết quả kiểm thử phần mềm.

## 2. Môi trường và dữ liệu

- PostgreSQL test riêng, đủ migrations; chỉ cho phép reset database test đã được xác nhận.
  Không dùng dữ liệu thật hoặc database ứng dụng. Không dùng SQLite thay integration PostgreSQL.
- Backend dùng auth hiện hành; token hợp lệ, hết hạn, thu hồi và tài khoản bị vô hiệu hóa.
- Clock kiểm soát được; ngày hiện tại chuẩn là 17/10/2026 theo Asia/Ho_Chi_Minh.
- Mobile dùng API test; fake repository cho widget test, backend thật cho integration.
- Request đồng thời dùng kết nối độc lập, barrier và commit thật; không chỉ mock transaction.
- Mỗi ca có dữ liệu riêng hoặc reset độc lập; lưu request/response và đối chiếu DB,
  che token khi lưu bằng chứng.

| Fixture | Dữ liệu |
|---|---|
| A | Chủ hồ sơ C1; user active, phiên hợp lệ |
| B | Chủ hồ sơ C2, không có quyền với C1 |
| V / E / N | Thành viên active của C1, quyền growth lần lượt view / edit / none |
| R | Thành viên C1 đã revoked hoặc left, từng có quyền edit |
| C1 | Sinh 17/02/2026; đủ giới tính hợp lệ, chưa xóa |
| C2 | Khác chủ, cùng tên C1 để kiểm tra định danh bằng UUID |
| C3 | Hồ sơ đã xóa mềm |
| D1 | 15/10/2026: cân nặng 8.4 kg, chiều cao 69.5 cm lying, vòng đầu 43.7 cm |
| D2 | 16/10/2026: chỉ cân nặng 8.5 kg |
| D3 | 17/10/2026: chỉ chiều cao 70 cm lying |

Oracle BMI D1: `8.4 / (0.695 * 0.695)`, làm tròn hai chữ số = **17.39**.
D2 và D3 không có BMI; summary BMI vẫn là D1 dù cân nặng/chiều cao mới nhất thuộc hai ngày khác.

## 3. Xác thực và phân quyền

Áp dụng ma trận cho cả GET, PUT và DELETE, bao gồm ID trực tiếp và ngày đo.

| ID | Ưu tiên | Tình huống | Kết quả mong đợi |
|---|---|---|---|
| SEC-01 | P0 | Chủ hồ sơ A đọc/ghi/xóa C1 | Được phép; created_by/updated_by/deleted_by lấy từ phiên |
| SEC-02 | P0 | V đọc; V ghi/xóa | GET 200; ghi/xóa 403 GROWTH_WRITE_FORBIDDEN |
| SEC-03 | P0 | E đọc/ghi/xóa | Được phép như quyền growth edit |
| SEC-04 | P0 | B, N, R truy cập C1; truy cập C3 hoặc childId không tồn tại | 404, không lộ metadata/số đo; không đổi DB |
| SEC-05 | P0 | Thiếu token, token hỏng/hết hạn, phiên thu hồi/hết hạn | 401 theo auth, có WWW-Authenticate: Bearer |
| SEC-06 | P0 | Tài khoản không còn khả dụng | 403 ACCOUNT_UNAVAILABLE; không đổi DB |
| SEC-07 | P0 | measurementId của C2 đặt dưới đường dẫn C1 | 404, không xóa số đo C2 |
| SEC-08 | P0 | Thu hồi quyền sau request thành công rồi gọi lại | Quyền mới có hiệu lực; không dựa vào quyền cache phía mobile |
| SEC-09 | P1 | Token admin gọi API mobile | Bị từ chối theo cơ chế auth mobile |

## 4. Lưu số đo và validation

Endpoint: `PUT /children/{childId}/growth/days/{date}`; thành công luôn 200.

| ID | Ưu tiên | Tình huống | Kết quả mong đợi |
|---|---|---|---|
| SAVE-01 | P0 | Nhập riêng cân nặng, riêng chiều cao, riêng vòng đầu | Chỉ tạo chỉ số đã gửi; đơn vị đúng; BMI null nếu thiếu cặp |
| SAVE-02 | P0 | Nhập cả ba chỉ số D1 | Ba bản ghi active, cùng ngày/trẻ; BMI 17.39 |
| SAVE-03 | P0 | Gửi lại nguyên request; cập nhật cân nặng cùng ngày | Không tăng số dòng active; cập nhật đúng ID đang active, không tạo trùng |
| SAVE-04 | P0 | Ngày có đủ ba chỉ số, chỉ gửi weightKg mới | Chiều cao/vòng đầu và ghi chú của chúng giữ nguyên; BMI tính lại |
| SAVE-05 | P1 | note bỏ qua / null / chuỗi / rỗng | Giữ nguyên / xóa / thay thế / lưu chuỗi rỗng cho chỉ số được gửi; không tác động chỉ số bỏ qua |
| SAVE-06 | P1 | Chỉ gửi note hoặc body rỗng | 422; phải có ít nhất một chỉ số |
| SAVE-07 | P1 | null cho chỉ số, chuỗi số, boolean, mảng, field lạ hoặc BMI client | 422; không ép kiểu để âm thầm chấp nhận dữ liệu sai |
| SAVE-08 | P1 | Giá trị 0, âm, trên giới hạn; NaN/Infinity trong JSON | Bị từ chối; không ghi dữ liệu không hữu hạn |
| SAVE-09 | P1 | 200 kg / 250 cm chiều cao / 100 cm vòng đầu và cao hơn 0.01 | Đúng giới hạn được nhận; vượt giới hạn 422; không dùng làm ngưỡng phân loại |
| SAVE-10 | P1 | 0.01; 8.40; 8.401; note 2000/2001 ký tự | Hai số đầu hợp lệ; quá hai chữ số thập phân bị từ chối; note tối đa 2000 |
| SAVE-11 | P1 | Height thiếu value/tư thế; tư thế không nằm trong lying/standing | 422; không tự suy diễn tư thế |
| SAVE-12 | P1 | Ngày sinh, hôm nay, trước sinh, ngày mai | Hai ca đầu hợp lệ; hai ca sau 422 |
| SAVE-13 | P1 | Sai UUID; ngày không tồn tại; timestamp thay date; năm nhuận | Sai định dạng/ngày 422; ngày nhuận hợp lệ được xử lý đúng |
| SAVE-14 | P0 | Lỗi DB khi đã ghi một phần trong request ba chỉ số | Rollback toàn bộ, 503 DATABASE_UNAVAILABLE; không còn bản ghi dở dang |
| SAVE-15 | P1 | Client cố gửi ageInDays, childId hoặc người tạo trong body | 422; tuổi và người thao tác do server xác định |

Contract yêu cầu JSON number, không nhận chuỗi số. UI có thể chuyển dấu phẩy thập phân
sang số trước khi gửi; kiểm tra riêng ở mobile. Nếu implementation chọn ép kiểu,
phải sửa contract trước khi nghiệm thu, không thay oracle để bỏ qua sai lệch.

## 5. BMI, đọc dữ liệu và lọc ngày

| ID | Ưu tiên | Tình huống | Kết quả mong đợi |
|---|---|---|---|
| READ-01 | P1 | Trẻ chưa có số đo | days=[]; bốn mục summary=null; child metadata đúng |
| READ-02 | P1 | Nhiều ngày nhập không theo thứ tự | days tăng dần; mỗi ngày chỉ có chỉ số active; không lặp ngày/chỉ số |
| READ-03 | P1 | from/to đủ, chỉ một đầu, bỏ cả hai; from=to | Lọc bao gồm hai đầu; đầu bỏ qua không giới hạn; một ngày trả đúng một ngày nếu có dữ liệu |
| READ-04 | P1 | from > to hoặc ngày lọc không hợp lệ | 422 VALIDATION_ERROR |
| READ-05 | P0 | Lọc khoảng không chứa số mới nhất hoặc không có số đo | days theo khoảng; summary vẫn trên toàn bộ lịch sử |
| BMI-01 | P0 | D1 đủ cặp cùng ngày, D2/D3 khác ngày | D1=17.39; không ghép chéo ngày; summary BMI=D1 |
| BMI-02 | P0 | Sửa cân nặng hoặc chiều cao D1; thêm phần còn thiếu cho D2 | Tính lại từ dữ liệu hiện hành, không dùng BMI cache cũ |
| BMI-03 | P1 | Nhập 100 cm và 10 kg trong fixture phù hợp | BMI=10.00, xác nhận đổi cm sang m; JSON có thể biểu diễn là 10 |
| BMI-04 | P1 | Hai giá trị tư thế lying/standing | Lưu và trả đúng tư thế, không tự quy đổi chiều cao |
| READ-06 | P1 | Kiểm tra response bằng schema OpenAPI | camelCase, UUID, date, UTC timestamp, null và đơn vị đúng; không lộ trường nội bộ |
| READ-07 | P1 | Ghi gần 00:00 tại Việt Nam nhưng UTC còn ngày trước | Validation hôm nay theo Asia/Ho_Chi_Minh, không dịch ngày đo sang UTC |

Không dùng so sánh chuỗi để yêu cầu BMI phải có hai số 0 cuối; so sánh giá trị số.
Ca làm tròn đúng điểm giữa cần chốt quy tắc half-up/half-even trong contract trước khi thêm oracle.

## 6. Xóa mềm, audit và đồng thời

| ID | Ưu tiên | Tình huống | Kết quả mong đợi |
|---|---|---|---|
| DEL-01 | P0 | Xóa một chỉ số của D1 | 204 không body; deleted_at/deleted_by đúng; chỉ số khác giữ nguyên |
| DEL-02 | P0 | Xóa cân nặng/chiều cao mới nhất | BMI của ngày thành null; summary lùi về số/cặp active gần nhất |
| DEL-03 | P1 | Xóa hết chỉ số trong một ngày; xóa lại ID đó | Ngày biến mất khỏi days; gọi lại 204 |
| DEL-04 | P1 | Xóa ID không tồn tại | 404 MEASUREMENT_NOT_FOUND |
| DEL-05 | P0 | PUT chỉ số sau khi chỉ số ngày đó đã xóa | Tạo ID active mới; lịch sử xóa cũ còn nguyên; không tái sử dụng dòng đã xóa |
| DB-01 | P0 | Đối chiếu sau thêm/sửa/xóa | value, metric, measured_at, age_in_days, người thao tác đúng; index active không bị vi phạm |
| CON-01 | P0 | Hai request cùng trẻ/ngày/chỉ số với barrier | Một dòng active, không 500; kết quả theo thứ tự ghi được tuần tự hóa, xác minh bằng dấu vết DB |
| CON-02 | P0 | Đồng thời ghi cân nặng và chiều cao cùng ngày | Giữ cả hai chỉ số sau commit; lần đọc sau cùng có BMI đúng |
| CON-03 | P0 | PUT và DELETE đồng thời trên một chỉ số | Kết quả tương ứng một thứ tự thực thi tuần tự hợp lệ; không trùng dòng active, không BMI từ số đã xóa |
| CON-04 | P1 | Server commit nhưng client mất response rồi gửi lại | Không nhân đôi số đo; client tải lại nhận dữ liệu đã lưu |

## 7. Mobile và hồi quy giao diện

| ID | Ưu tiên | Tình huống | Kết quả mong đợi |
|---|---|---|---|
| UI-01 | P1 | Mở màn Theo dõi, đổi bốn tab | Hiển thị chỉ số/đơn vị/lịch sử đúng, loading/rỗng/lỗi rõ ràng |
| UI-02 | P0 | Nhập từ Theo dõi và Trang chủ | Cùng repository/API; sau lưu, biểu đồ, summary và Trang chủ nhất quán |
| UI-03 | P1 | Chọn ngày đã có dữ liệu, sửa một chỉ số | Hiện số cũ trước xác nhận; không vô tình xóa hoặc ghi lại các chỉ số không sửa |
| UI-04 | P1 | Đổi bộ lọc có sẵn, Tất cả, khoảng tự chọn | Gửi from/to đúng; biểu đồ/lịch sử đúng khoảng; thẻ summary theo contract toàn lịch sử |
| UI-05 | P1 | Số 8,4 và 8.4; ký tự sai; trường trống | Chuyển số hợp lệ sang JSON number; thông báo validation; không gửi note-only |
| UI-06 | P1 | Thiếu cân nặng hoặc chiều cao cùng ngày | BMI hiển thị chưa đủ số đo; không lấy số ngày khác để điền |
| UI-07 | P0 | Chuyển C1/C2 cùng tên; đổi tài khoản; logout | Không lẫn cache/dữ liệu; định danh bằng childId và owner/account |
| UI-08 | P1 | Chuyển trẻ khi request cũ đang chậm | Response cũ không ghi đè màn trẻ mới |
| UI-09 | P1 | Quyền view; quyền bị thu hồi khi form đang mở | UI phù hợp quyền; server từ chối ghi, không hiển thị thành công giả |
| UI-10 | P1 | Mất mạng, timeout, 422, 503, hết hạn access token | Giữ bản nhập để thử lại khi phù hợp; lỗi rõ ràng; refresh theo auth hiện hành; không tạo trùng |
| UI-11 | P1 | Nhấn Lưu liên tục; xóa rồi API lỗi | Không gửi lặp ngoài ý muốn; không làm UI mất dữ liệu vĩnh viễn khi server chưa xác nhận |
| UI-12 | P0 | Tài khoản thật chưa có số đo, dữ liệu demo/local tồn tại | Hiện trạng thái rỗng; không tự gửi dữ liệu demo/local lên server |
| WHO-01 | P1 | Đổi ngày sinh/giới tính, đổi hồ sơ | Tham chiếu WHO cập nhật đúng hồ sơ; không giữ metadata trẻ trước |
| WHO-02 | P1 | Trước sinh, mốc 24 tháng, đúng 60 tháng, sau 60 tháng | Giữ quy tắc phạm vi và tách đường tham chiếu hiện có; số đo thật vẫn xem được ngoài phạm vi |
| WHO-03 | P1 | Tư thế đo không phù hợp tham chiếu hoặc thiếu metadata | Không tự quy đổi/đưa phân loại; UI xử lý theo quy tắc đã chốt và không gán chuẩn sai |
| UI-13 | P2 | Android/iOS, bàn phím mở, màn nhỏ, chữ lớn | Form cuộn được, nút lưu nhìn thấy, lỗi đọc được, đơn vị không bị cắt |

Tái sử dụng và cập nhật test trong `mobile/test/`: `measurement_sheet_test.dart`,
`growth_screen_test.dart`, `growth_redesign_test.dart`, `growth_date_range_test.dart`,
`who_growth_chart_test.dart`, `who_bmi_reference_test.dart`, `who_profile_sync_test.dart`.
Test local hiện có không thay thế được integration test API mới.

## 8. Cách triển khai kiểm thử

1. Kiểm tra schema OpenAPI, reference, ví dụ và thống nhất các quyết định còn mở.
2. Unit test validation, BMI, nhóm số đo theo ngày, quy tắc quyền và ánh xạ response.
3. Integration test FastAPI + PostgreSQL cho toàn bộ ca P0/P1 API/DB, gồm lỗi giữa transaction và concurrency.
4. Service/widget test mobile bằng fake HTTP hoặc repository: request đúng contract, các trạng thái và response đến trễ.
5. Chạy luồng đầu cuối với backend thật: đăng nhập → chọn trẻ → nhập → xem/lọc → sửa → xóa → mở lại ứng dụng.
6. Chạy hồi quy auth và bộ test tăng trưởng hiện có; kiểm tra thủ công thiết bị mục tiêu.

Lệnh/shell script cụ thể cho growth sẽ được bổ sung sau khi có implementation.
Không dùng script reset database auth hiện tại cho growth nếu chưa xác minh phạm vi và fixture.

## 9. Hiệu năng và bằng chứng

- Dữ liệu tải đề xuất: một trẻ có số đo mỗi ngày trong 5 năm, tài khoản có nhiều trẻ;
  đo GET không lọc, GET có lọc, PUT và DELETE với nhiều request đồng thời.
- Ghi kích thước response, thời gian p50/p95, tỷ lệ lỗi và kế hoạch truy vấn trên môi trường ghi rõ cấu hình.
- Mục tiêu tham khảo để thống nhất trước đo: GET p95 <= 1 giây, ghi p95 <= 500 ms
  ở 20 request đồng thời trên backend test; không dùng kết quả máy cá nhân để kết luận production.
- Nếu payload không phân trang gây chậm, đề xuất sửa contract và UI trước khi nghiệm thu.
- Mỗi ca ghi: ID, commit, môi trường, fixture, bước chạy, expected/actual, pass/fail/blocked,
  bằng chứng request/response/DB hoặc ảnh UI, liên kết lỗi. Không lưu access/refresh token trong báo cáo.

## 10. Điều kiện bắt đầu và nghiệm thu

Điều kiện bắt đầu integration: API hồ sơ trẻ/xác thực chạy được, migrations hoàn tất,
API growth triển khai theo contract, có DB test và cơ chế tạo fixture/clock/lỗi DB an toàn.

Các điểm cần chốt trước test tương ứng: quy tắc làm tròn BMI ở điểm giữa;
cách UI xử lý tư thế đo khi so với WHO; thay đổi ngày sinh có tính lại age_in_days
đã lưu hay không. Đây là quyết định còn mở, không tự xem là lỗi implementation.

Cập nhật triển khai 18/10/2026: đã chọn ROUND_HALF_UP hai chữ số; không đối chiếu
chiều cao/BMI khi tư thế không phù hợp; tính lại tuổi số đo active khi đổi ngày sinh
và từ chối ngày sinh sau số đo active đã có. Contract/hướng dẫn đã cập nhật theo các quyết định này.

Nghiệm thu khi:

- Tất cả ca P0/P1 áp dụng đã chạy và đạt; không còn lỗi sai quyền, mất dữ liệu hoặc BMI sai.
- Contract và implementation khớp; ca bị chặn/chưa chạy được báo rõ, không tính pass.
- Hồi quy auth và tăng trưởng đạt; luồng thật trên các nền tảng mục tiêu đã xác nhận.
- Có bằng chứng rollback, concurrency, idempotency, cách ly hồ sơ/tài khoản và refresh phiên.
- Báo cáo kết quả tách rõ kiểm thử tự động, thủ công và hiệu năng; ghi các giới hạn còn lại.

Ước lượng sau khi tính năng sẵn sàng: 1–2 ngày chuẩn bị fixture và test API/DB,
1–2 ngày mobile/integration, 1 ngày chạy hồi quy và tổng hợp; chưa gồm thời gian sửa lỗi.
