# Hệ màu chung — Bé lớn khôn

Đọc file này trước khi tạo hoặc cập nhật giao diện ứng dụng mobile. **Green Sprout**
là hệ màu chuẩn cho các màn hình được cập nhật. Tài liệu này tập trung quy tắc màu;
không thay thế yêu cầu bố cục và nghiệp vụ của từng tính năng.

## 1. Bảng màu chuẩn Green Sprout

Các token dưới đây hiện nằm trong `HomeColors` tại
[`mobile/lib/app_colors.dart`](../mobile/lib/app_colors.dart).

| Vai trò | Mã màu | Token nguồn | Cách dùng |
|---|---|---|---|
| Nền màn hình | `#F0F5E7` | `background` | Scaffold, nền trang |
| Nền nội dung | `#FFFFFF` | `surface` | Form, danh sách, khối nội dung, chữ trên nút xanh đậm |
| Màu chủ đạo | `#538B29` | `primary` | Nút chính, tiến trình, trạng thái được chọn |
| Chữ chính | `#29451E` | `ink` | Tiêu đề, nội dung, icon chính, chữ trên nền xanh non |
| Chữ phụ / CTA | `#477921` | `reminderCta` | Mô tả, nhãn phụ, liên kết hành động |
| Nền icon / viền nhẹ | `#D9EFA9` | `iconBackground` | Nền icon, đường phân cách khi cần |
| Điểm nhấn | `#B6E34E` | `milestoneAccent` | Mốc hiện tại, tab hoặc chip đang chọn; dùng với chữ `#29451E` |
| Nền nhắc nhở | `#EAF5C9` | `reminderBackground` | Banner, vùng thông tin nhẹ, trạng thái nhấn |
| Đầu gradient header | `#B8DF8A` | `headerStart` | Chỉ dùng cho header có gradient |
| Cuối gradient header | `#D9EFA9` | `headerEnd` | Kết hợp với `headerStart` |

## 2. Quy tắc áp dụng

- Dùng xanh lá xuyên suốt; nền trang xanh nhạt, nội dung trắng, chữ xanh đậm.
- Nút chính: nền `primary`, chữ trắng. Tab/chip nhấn xanh non: nền `milestoneAccent`,
  chữ `ink`. Không dùng chữ trắng trên nền xanh non.
- Dùng điểm nhấn trên diện tích nhỏ; hạn chế gradient, viền và bóng đổ trang trí.
- Giữ font Nunito và màu gốc của ảnh, mascot, sticker, minh họa giải phẫu.
- Trạng thái active, inactive, disabled phải phân biệt được. Trạng thái disabled
  dùng cơ chế của Material; không dùng màu disabled cho nội dung vẫn tương tác được.
- Giữ màu lỗi, cảnh báo, trạng thái nghiệp vụ và biểu đồ theo ý nghĩa của chúng;
  không đổi tất cả thành xanh lá. Luôn kèm nhãn hoặc icon, không chỉ dựa vào màu.
- Dùng token trong Dart, không rải mã hex vào widget. Nếu cần thêm màu, khai báo
  token có tên theo vai trò và cập nhật tài liệu này cùng thay đổi mã.
- Khi có dark mode, cần bảng màu riêng được kiểm tra; bảng trên là bảng nền sáng.

## 3. Cách tích hợp vào mã hiện có

**Hiện ứng dụng chưa chuyển toàn bộ sang Green Sprout.** Theme gốc trong
`mobile/lib/main.dart` vẫn dùng `AppColors` cũ. Không đổi hàng loạt `AppColors`
chỉ để cập nhật một màn hình vì sẽ ảnh hưởng các tính năng khác.

| Phạm vi | Bộ token đang dùng |
|---|---|
| Home | `HomeColors` |
| Start | `StartColors`, tham chiếu `HomeColors` |
| Chọn hồ sơ bé | `ChildProfileSelectionColors`, tham chiếu `HomeColors` |
| Mọc răng | `TeethingColors`, tham chiếu `HomeColors`; `TeethingTheme` cho Material controls |
| Thông báo & nhắc nhở | `NotificationColors`, tham chiếu `HomeColors` |
| Cài đặt & quyền riêng tư | `SettingsColors`, tham chiếu `HomeColors` |
| Tăng trưởng | `GrowthColors`, tham chiếu `HomeColors`; giữ `WeightChartColors` & `StatureChartColors` cho biểu đồ và trạng thái y khoa |
| Các màn hình chưa chuyển đổi | `AppColors` và token riêng của tính năng |

Khi cập nhật một tính năng, tạo hoặc tái sử dụng bộ token riêng tham chiếu màu
chuẩn trong `app_colors.dart`, theo mẫu `TeethingColors`. Áp dụng theme trong
phạm vi tính năng cho nút, dialog, bottom sheet, thanh trạng thái và các màn con.
Giữ nguyên API, nghiệp vụ, điều hướng và giao diện ngoài phạm vi yêu cầu.

## 4. Màu cũ và màu chuyên biệt cần nhận biết

### AppColors cũ — chỉ duy trì màn hình chưa chuyển đổi

| Token | Mã màu | Token | Mã màu |
|---|---|---|---|
| `primary` | `#286B52` | `primaryDark` | `#194C3C` |
| `primarySoft` | `#E5EFE3` | `background` | `#FAF7F0` |
| `surface` | `#FFFFFF` | `heroPanel` | `#F0DFC3` |
| `textPrimary` | `#23332E` | `textSecondary` | `#718078` |
| `border` | `#EAE8DF` | `purpleSurfaceLight` | `#F0EAF8` |
| `purpleText` | `#655080` | | |

### Biểu đồ tăng trưởng

Nguồn: `WeightChartColors`, `StatureChartColors` trong `app_colors.dart`.
Giữ sự khác biệt giữa dữ liệu đo, đường chuẩn và các vùng biểu đồ.

| Token | Mã màu | Token | Mã màu |
|---|---|---|---|
| `heroInk` | `#173B68` | `axis` | `#315B87` |
| `ink` | `#182B34` | `muted` | `#526573` |
| `positive` | `#287A45` | `attention` | `#9A651D` |
| `critical` | `#B44B42` | `unknown` | `#64748B` |
| `frame` | `#E5ECF3` | `grid` | `#E8EEEB` |
| `data` (cân nặng) | `#E58C45` | `data` (chiều cao) | `#4B92C6` |
| `median` | `#25B96C` | `sd2` | `#F3B44F` |
| `sd3` | `#FF885C` | `center` | `#DDF5DF` |
| `outer` | `#FFEDCC` | | |

### Tiêm chủng

Nguồn: `mobile/lib/features/vaccination/vaccination_style.dart`.

| Vai trò | Chữ / icon | Nền |
|---|---|---|
| Đã ghi nhận | `#286B52` | `#E5EFE3` |
| Đã lên kế hoạch / nhóm tím | `#655080` | `#F0EAF8` |
| Cần chú ý | `#875414` | `#FFF0D8` |

### Mọc răng

Giữ màu hồng của nướu và minh họa răng. Banner lỗi/offline giữ ý nghĩa cảnh báo.
Ở tab Răng của bé, độ mờ lần lượt là: đã ghi nhận **100%**, đến tuổi tham khảo
nhưng chưa ghi nhận **72%**, chưa đến tuổi **55%**. Tab Tham khảo dùng **100%**
cho răng đến mốc và **55%** cho răng chưa đến mốc; không xem đây là dữ liệu đã mọc.

## 5. Kiểm tra khi cập nhật

- Kiểm tra cả màn chính, màn con, form, dialog và trạng thái loading/error/disabled.
- Kiểm tra màn hình nhỏ 360 × 800, chữ lớn, độ tương phản và vùng nhấn.
- Giữ nguyên màu asset và ý nghĩa các trạng thái/đường biểu đồ.
- Chạy phân tích Dart và kiểm thử liên quan; kiểm tra không đổi màn hình ngoài phạm vi.
- Nếu đổi màu Start, đồng bộ tài nguyên khởi động native trong phạm vi được yêu cầu;
  đổi token Flutter không tự cập nhật LaunchScreen iOS hoặc Start native Android.

Khi thay đổi hệ màu, cập nhật **file này và các token tương ứng cùng lúc**.
`docs/update_UI_home.md` là yêu cầu bố cục Home; dùng file này làm tham chiếu màu chung.
