# Flutter UI Quick Guide — Track Children

> Mục đích: hướng dẫn nhanh cho coding agent khi tạo hoặc chỉnh sửa giao diện Flutter của Track Children.
> Ngôn ngữ: Tiếng Việt. Đơn vị layout: logical pixels.

## 1. Kích thước tham chiếu

Dùng các viewport sau để kiểm thử responsive. Đây là mốc tham khảo, không phải kích thước bắt buộc của mọi thiết bị.

| Thiết bị/mục đích | Viewport logic (rộng × cao) |
|---|---:|
| Android nhỏ | `320 × 640` |
| Android phổ biến | `360 × 800` |
| iPhone tham chiếu | `390 × 844` |
| iPhone đời mới | `402 × 874` |
| Điện thoại lớn | `430 × 932` |

**Quy ước:** bắt đầu thiết kế ở `390 × 844`, sau đó kiểm tra ít nhất `360 × 800` và `320 × 640`.

Không nhầm logical pixels với pixel vật lý hoặc số inch màn hình. Kích thước thực tế phụ thuộc thiết bị, hệ điều hành, display scaling và vùng system UI.

## 2. Quy tắc responsive bắt buộc

1. **Không cố định toàn bộ màn hình** theo một width/height cụ thể.
2. Dùng `MediaQuery.sizeOf(context)` để đọc kích thước vùng layout và `LayoutBuilder` để phản hồi theo constraints của widget cha.
3. Dùng `Expanded`, `Flexible`, `Wrap`, `ConstrainedBox`, `AspectRatio`, `ListView` hoặc `SingleChildScrollView` đúng ngữ cảnh.
4. Không scale toàn bộ UI theo một tỷ lệ width/height; chỉ điều chỉnh thành phần cần thiết.
5. Dùng breakpoint theo nhu cầu layout, không theo tên model thiết bị. Có thể bắt đầu với:
   - `< 360`: compact
   - `360–599`: phone
   - `600–839`: tablet/small expanded
   - `>= 840`: wide layout
6. Tránh `RenderFlex overflow`, unbounded constraints và chiều cao cố định cho nội dung có thể xuống dòng.
7. Hỗ trợ nội dung tiếng Việt dài và text scaling của hệ thống; không khóa cỡ chữ chỉ để khớp mockup.

Ví dụ:

```dart
final size = MediaQuery.sizeOf(context);

LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 360) {
      return const CompactLayout();
    }
    return const StandardPhoneLayout();
  },
)
```

## 3. Safe area và system UI

- Dùng `SafeArea` cho nội dung tương tác cần tránh tai thỏ, Dynamic Island, status bar và home indicator.
- Không hard-code padding trên/dưới theo một model điện thoại.
- Kiểm tra Android gesture navigation, navigation buttons và bàn phím mở.
- Nếu background tràn dưới system bars, giữ nội dung quan trọng trong vùng an toàn.
- Kiểm tra lại hành vi edge-to-edge trên thiết bị/emulator thực tế.

## 4. Background minh họa của Track Children

Với background phong cảnh, cây tre, nhân vật và vùng thông điệp:

- Tách background, nhân vật PNG trong suốt và vùng chữ thành các layer/widget riêng khi có thể.
- Dùng `BoxFit.cover` khi cần phủ kín vùng; hiểu rằng ảnh có thể bị crop.
- Dùng `BoxFit.contain` nếu bắt buộc hiển thị toàn bộ hình, chấp nhận có thể xuất hiện khoảng trống.
- Không để mặt nhân vật, cây tre quan trọng hoặc vùng thông điệp sát cạnh có nguy cơ bị crop.
- Định vị nhân vật bằng `Alignment`, constraints hoặc `LayoutBuilder`, không hard-code tọa độ cho một viewport.
- Không đặt nội dung thay đổi theo tên/tuổi/trạng thái của trẻ trực tiếp vào ảnh background.
- Đảm bảo chữ dễ đọc trên nền phong cảnh.
- Kiểm tra crop ở màn hình hẹp, rộng, thấp và cao.

## 5. Typography và thao tác

- Dùng `ThemeData` và `TextTheme` nhất quán.
- Cho phép text xuống dòng; tránh chiều cao cố định cho card chứa văn bản.
- Mục tiêu vùng chạm nút khoảng `48 × 48 logical pixels` trở lên khi phù hợp.
- Giữ tương phản màu tốt; không chỉ dùng màu để truyền tải trạng thái.
- Form phải cuộn được khi bàn phím xuất hiện.
- Danh sách dài nên dùng `ListView` hoặc `CustomScrollView`.

## 6. Checklist trước khi hoàn tất màn hình

- [ ] Không có overflow hoặc lỗi constraints.
- [ ] Nội dung không bị system bars hoặc bàn phím che.
- [ ] Chữ tiếng Việt và nội dung dài hiển thị đầy đủ.
- [ ] Nút chính dễ nhìn và dễ chạm.
- [ ] Background không crop mất chi tiết quan trọng.
- [ ] Bố cục hợp lý ở `320`, `360`, `390`, `402` và `430` logical pixels.
- [ ] Đã kiểm tra text scaling lớn hơn mặc định.
- [ ] Giữ đúng Design System của Track Children.
- [ ] Nếu có thể, đã kiểm thử trên Android và iOS thực tế.

## 7. Hướng dẫn cho coding agent

Khi tạo/chỉnh sửa màn hình:

1. Đọc Design System và các màn hình hiện có trước khi thay đổi.
2. Tái sử dụng theme, spacing tokens và widget dùng chung.
3. Ưu tiên responsive constraints thay vì kích thước tuyệt đối.
4. Không tự ý thay đổi màu sắc, typography, radius, spacing hoặc phong cách minh họa đã thống nhất.
5. Khi sửa overflow, tìm nguyên nhân layout thay vì chỉ giảm font hoặc thu nhỏ mọi thành phần.
6. Nêu rõ các viewport đã kiểm thử và vấn đề còn tồn tại.

## 8. Tài liệu chính thức

- Flutter adaptive/responsive: https://docs.flutter.dev/ui/adaptive-responsive
- Flutter layout: https://docs.flutter.dev/ui/layout
- `MediaQuery`: https://api.flutter.dev/flutter/widgets/MediaQuery-class.html
- `LayoutBuilder`: https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html
- `SafeArea`: https://api.flutter.dev/flutter/widgets/SafeArea-class.html

---

## Tóm tắt ngắn

**Bắt đầu tại `390 × 844`, nhưng không khóa giao diện theo kích thước này.** Dùng logical pixels, responsive constraints, SafeArea, nội dung cuộn được và kiểm thử ở `360 × 800` cùng `320 × 640`. Với background minh họa, giữ nhân vật và vùng thông điệp trong vùng an toàn, tránh crop mất chi tiết quan trọng.
