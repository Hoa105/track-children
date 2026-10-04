# Prototype reference data (extracted verbatim from the HTML prototype's embedded JS)

The original prototype file (`Be Lon Khon - Prototype (click tung buoc).html`) is a self-executing
"bundler" artifact whose real UI markup is embedded as a JSON-escaped string plus base64 binary
blobs (fonts, a copy of React/ReactDOM). That raw file is not available on this filesystem and is
impractically large to reconstruct byte-for-byte. Build the Flutter app from the structured data
below (copied verbatim from the prototype's JS) plus the screen-by-screen descriptions already
given in the task prompt — that is a complete and sufficient source of truth. Do not block on
finding the literal .html file; proceed with this reference.

## Screen list (verbatim `screens` array from the prototype's Component class)

```json
[{"id":"1","name":"Splash / Welcome"},{"id":"2","name":"Onboarding"},{"id":"3","name":"Đăng nhập / Đăng ký"},{"id":"3b","name":"Chọn bé"},{"id":"4","name":"Trang chủ"},{"id":"5","name":"Hồ sơ bé"},{"id":"6","name":"Theo dõi tăng trưởng"},{"id":"8a","name":"Câu hỏi · Vận động thô"},{"id":"8b","name":"Câu hỏi · Vận động tinh – Nhận thức"},{"id":"8c","name":"Câu hỏi · Ngôn ngữ – Giao tiếp"},{"id":"8d","name":"Câu hỏi · Xã hội – Cảm xúc"},{"id":"9","name":"Kết quả đánh giá"},{"id":"10","name":"Lịch sử & biểu đồ xu hướng"},{"id":"11","name":"Hoạt động · Nhóm"},{"id":"12","name":"Hoạt động trong nhóm"},{"id":"12b","name":"Chi tiết · Vận động"},{"id":"13","name":"Chi tiết · Âm nhạc"},{"id":"13b","name":"Chi tiết · Kể chuyện"},{"id":"14","name":"Nhật ký phát triển"},{"id":"15","name":"Thêm nhật ký"},{"id":"16","name":"Góc đồng hành"},{"id":"18","name":"Thông báo / Nhắc nhở"},{"id":"19","name":"Cài đặt & Quyền riêng tư"}]
```

Note: the on-screen step index (s0..s21) in the sc-if blocks corresponds to this array's order
(s0 = "1" Splash, s1 = "2" Onboarding, s2 = "3" Đăng nhập/Đăng ký, s3 = "3b" Chọn bé, s4 = "4" Trang
chủ, s5 = "5" Hồ sơ bé, s6 = "6" Theo dõi tăng trưởng, s7 = "8a", s8 = "8b", s9 = "8c", s10 = "8d",
s11 = "9" Kết quả, s12 = "10" Lịch sử, s13 = "11" Hoạt động·Nhóm, s14 = "12" Hoạt động trong nhóm,
s15 = "12b" Chi tiết Vận động, s16 = "13" Chi tiết Âm nhạc, s17 = "13b" Chi tiết Kể chuyện,
s18 = "14" Nhật ký, s19 = "15" Thêm nhật ký, s20 = "16" Góc đồng hành, s21 = "18" Thông báo,
s22 = "19" Cài đặt).

## Activity groups + items (verbatim `groups` array — this is the real mock data for the Activities feature)

```json
[{"name":"Vận động thô","tint":"#E4F3EA","kind":"move","items":[{"n":"Tummy time (nằm sấp)","a":"0–3 th","t":"5 phút","d":true},{"n":"Tập lẫy, lăn người","a":"3–6 th","t":"10 phút","d":true},{"n":"Tập ngồi có hỗ trợ","a":"5–8 th","t":"10 phút","d":true},{"n":"Bò qua vật cản (gối, hộp)","a":"7–10 th","t":"15 phút","d":true},{"n":"Tập đứng vịn","a":"8–12 th","t":"10 phút","d":true},{"n":"Tập bước chững (dắt tay)","a":"10–14 th","t":"15 phút","d":true},{"n":"Đi bộ tự do trong nhà","a":"12–18 th","t":"15 phút","d":false},{"n":"Ném – bắt bóng to","a":"14–24 th","t":"10 phút","d":false},{"n":"Bước lên/xuống bậc thang thấp","a":"18–24 th","t":"10 phút","d":false},{"n":"Nhảy tại chỗ hai chân","a":"20–30 th","t":"10 phút","d":false},{"n":"Đạp xe 3 bánh / xe chòi chân","a":"24–36 th","t":"15 phút","d":false},{"n":"Đi trên đường vạch (thăng bằng)","a":"30–36 th","t":"10 phút","d":false}]},{"name":"Vận động tinh","tint":"#EDEBFA","kind":"move","items":[{"n":"Nắm – lắc lục lạc","a":"0–4 th","t":"5 phút","d":true},{"n":"Chuyển đồ vật qua tay","a":"4–7 th","t":"10 phút","d":true},{"n":"Nhón nhặt vật nhỏ (ngón cái–trỏ)","a":"8–10 th","t":"10 phút","d":true},{"n":"Xếp chồng 2–3 khối vuông","a":"10–14 th","t":"10 phút","d":true},{"n":"Xâu hạt gỗ to","a":"14–18 th","t":"15 phút","d":true},{"n":"Vẽ nghịch bằng bút sáp","a":"15–20 th","t":"10 phút","d":false},{"n":"Xé giấy, vò giấy","a":"16–22 th","t":"10 phút","d":false},{"n":"Xúc / đổ nước, cát vào cốc","a":"18–24 th","t":"15 phút","d":false},{"n":"Xếp chồng 6–8 khối","a":"22–28 th","t":"15 phút","d":false},{"n":"Cài / mở cúc áo lớn","a":"24–30 th","t":"10 phút","d":false},{"n":"Tô màu trong đường viền","a":"28–34 th","t":"15 phút","d":false},{"n":"Cắt giấy bằng kéo an toàn","a":"32–36 th","t":"15 phút","d":false}]},{"name":"Ngôn ngữ","tint":"#FDF0D8","kind":"move","items":[{"n":"Trò chuyện – phát âm theo bé","a":"0–4 th","t":"5 phút","d":true},{"n":"Gọi tên khi bé phát âm \"ba, ma\"","a":"4–8 th","t":"10 phút","d":true},{"n":"Đọc sách tranh, chỉ hình gọi tên","a":"6–12 th","t":"10 phút","d":true},{"n":"Gọi tên bộ phận cơ thể","a":"10–15 th","t":"10 phút","d":true},{"n":"Bắt chước âm thanh động vật","a":"12–18 th","t":"10 phút","d":true},{"n":"Đố tên đồ vật quanh nhà","a":"15–20 th","t":"10 phút","d":false},{"n":"Ghép 2 từ thành câu ngắn","a":"18–24 th","t":"10 phút","d":false},{"n":"Hỏi – đáp \"cái gì đây\"","a":"20–26 th","t":"10 phút","d":false},{"n":"Kể lại 1 hoạt động vừa làm","a":"24–30 th","t":"10 phút","d":false},{"n":"Học từ mới theo chủ đề","a":"26–32 th","t":"15 phút","d":false},{"n":"Đặt câu hỏi \"tại sao, như thế nào\"","a":"30–36 th","t":"15 phút","d":false}]},{"name":"Nhận thức & Cảm xúc xã hội","tint":"#E4F3EA","kind":"move","items":[{"n":"Trốn tìm đơn giản (ú òa)","a":"4–8 th","t":"5 phút","d":true},{"n":"Tìm đồ vật bị giấu","a":"8–12 th","t":"10 phút","d":true},{"n":"Xếp hình phân loại theo màu","a":"12–18 th","t":"10 phút","d":true},{"n":"Nhận biết cảm xúc qua tranh","a":"15–20 th","t":"10 phút","d":false},{"n":"Ghép tranh 2–4 miếng","a":"18–24 th","t":"15 phút","d":false},{"n":"Đóng vai (nấu ăn, bác sĩ)","a":"20–26 th","t":"15 phút","d":false},{"n":"Tự xúc ăn, tự cởi giày","a":"22–28 th","t":"theo bữa","d":false},{"n":"Chia sẻ đồ chơi với bạn","a":"24–30 th","t":"15 phút","d":false},{"n":"Ghép puzzle 6–9 miếng","a":"28–34 th","t":"15 phút","d":false},{"n":"Phân loại đồ vật theo nhóm","a":"30–36 th","t":"15 phút","d":false}]},{"name":"Âm nhạc & âm thanh","tint":"#EDEBFA","kind":"music","items":[{"n":"Nghe nhạc êm dịu, ru ngủ","a":"0–6 th","t":"10 phút","d":true},{"n":"Lắc lục lạc / chuông theo nhịp","a":"4–10 th","t":"10 phút","d":true},{"n":"Hát kèm vỗ tay theo nhịp","a":"8–14 th","t":"10 phút","d":true},{"n":"Bài hát có động tác (\"Một con vịt\")","a":"12–20 th","t":"10 phút","d":false},{"n":"Gõ nhịp bằng thìa, trống lắc","a":"15–24 th","t":"10 phút","d":false},{"n":"Hát theo lời bài hát quen thuộc","a":"20–30 th","t":"10 phút","d":false},{"n":"Nhảy múa tự do theo nhạc","a":"24–36 th","t":"15 phút","d":false},{"n":"Phân biệt âm to/nhỏ, nhanh/chậm","a":"28–36 th","t":"10 phút","d":false}]},{"name":"Kể chuyện","tint":"#FDF0D8","kind":"story","items":[{"n":"Nghe kể chuyện có hình minh họa","a":"6–12 th","t":"5 phút","d":true},{"n":"Chuyện ngắn lặp cấu trúc (\"Cáo và Gà\")","a":"12–18 th","t":"10 phút","d":true},{"n":"Chuyện có tương tác – bé chỉ hình","a":"15–22 th","t":"10 phút","d":false},{"n":"Chuyện dân gian ngắn (\"Tích Chu\")","a":"20–28 th","t":"15 phút","d":false},{"n":"Hỏi lại \"sau đó điều gì xảy ra?\"","a":"24–32 th","t":"15 phút","d":false},{"n":"Bé tự kể lại chuyện bằng lời mình","a":"30–36 th","t":"15 phút","d":false}]}]
```

Field meaning: `n`=name, `a`=age range label, `t`=duration label, `d`=isDone (bool). `kind` on the
group controls which detail-screen variant an item opens (move → screen "12b" style detail with
numbered steps; music → screen "13" style detail with lyrics + fake audio player; story → screen
"13b" style detail with 3 numbered story paragraphs + "questions to ask" tip). Group index 0-5
tint colors above are the exact background tints used for that group's icon chip and detail hero.

## Growth metrics mock data (verbatim `metrics` array — for the Growth tracking screen's 3 tabs)

```js
[
  { label: 'Cân nặng', unit: 'kg', val: '10,8', pct: 52, input: 'Cân nặng (kg)', axis: ['14kg', '10kg', '6kg'], points: '30,84 62,74 94,64 126,56 158,48 190,40 208,36', lastY: 36 },
  { label: 'Chiều cao', unit: 'cm', val: '82', pct: 48, input: 'Chiều dài / cao (cm)', axis: ['90cm', '78cm', '64cm'], points: '30,88 62,78 94,68 126,58 158,50 190,42 208,38', lastY: 38 },
  { label: 'Vòng đầu', unit: 'cm', val: '47', pct: 55, input: 'Vòng đầu (cm)', axis: ['50cm', '46cm', '40cm'], points: '30,80 62,66 94,54 126,46 158,40 190,34 208,30', lastY: 30 }
]
```
`points` is an SVG polyline point list (x,y pairs in a 220x110 viewBox) showing the WHO-like
growth curve trend for that metric — treat it as "7 data points trending upward/left-to-right",
you do not need to reproduce exact SVG coordinates in Flutter; just render a comparable rising
line chart with fl_chart using proportionally similar shape, current value, and percentile.

## Selected exact copy strings worth preserving verbatim (pulled from the template)

- Home assessment status card: "Cần theo dõi thêm" / "Lần gần nhất · 02/08/2026" / "Cách lần trước 30 ngày · đã đánh giá 5 lần từ khi tạo hồ sơ"
- Domain labels + statuses on Home: "Vận động thô — Tạm ổn · 6/6", "Vận động tinh — Tạm ổn · 6/7", "Ngôn ngữ — Cần theo dõi · 4/6", "Nhận thức & Cảm xúc xã hội — Tạm ổn · 6/6"
- Trend card: "Xu hướng 5 lần đánh giá" / "Nhóm Ngôn ngữ giảm 2 lần liên tiếp, 3 nhóm còn lại tăng đều."
- Assessment CTA: "Bài đánh giá mốc 18 tháng" / "24 câu hỏi · khoảng 8 phút" / "Mẹ nên quan sát bé trong khoảng 1 tuần rồi trả lời, không cần bắt bé làm ngay lúc này. Có thể lưu tạm và tiếp tục sau." / button "Bắt đầu đánh giá →" plus 4 quick buttons "Nhóm 1 · Vận động thô" / "Nhóm 2 · Vận động tinh" / "Nhóm 3 · Ngôn ngữ" / "Nhóm 4 · Xã hội"
- AI suggestion card: "Gợi ý cho mẹ lúc này" / "Ưu tiên hoạt động nhóm Ngôn ngữ tại nhà trong 4 tuần tới." / button "Xem hoạt động gợi ý"
- Milestone reminder: "Mốc tiếp theo: 24 tháng" / "Còn 45 ngày · sẽ nhắc mẹ tự động"
- Medical disclaimer (repeats on Home + Results): "Đánh giá chỉ mang tính sàng lọc, không phải chẩn đoán y khoa và không thay thế bác sĩ hoặc chuyên gia phát triển trẻ." (Results screen variant: "Kết quả chỉ mang tính hỗ trợ theo dõi, không phải chẩn đoán và không thay thế tư vấn của bác sĩ / chuyên gia phát triển trẻ.")
- Results screen headline: "Bé đang phát triển tốt" / "Đạt 22/25 mốc · 17/08/2026"
- Results per-domain breakdown: Vận động thô 6/6, Vận động tinh 6/7, Ngôn ngữ 4/6, Xã hội 6/6
- Results "why" card: "Vì sao có kết luận này?" / "Nhóm Ngôn ngữ đạt 4/6 mốc và giảm nhẹ so với lần trước → hệ thống khuyến nghị theo dõi thêm trong 4 tuần."
- Assessment question examples (one per domain, screen 7-10):
  - Vận động thô: "Bé có tự leo lên bậc cầu thang khi được nắm một tay không?" options "Có, bé làm được" / "Chưa" / "Chưa chắc"
  - Vận động tinh: "Bé có xếp được tháp 3 khối gỗ mà không đổ không?" + hint "Gợi ý quan sát: đưa bé 4–5 khối vuông, xem bé có tự xếp chồng lên nhau."
  - Ngôn ngữ: "Bé có nói được ít nhất 10 từ đơn mà người thân hiểu được không?" + optional notes field "Ghi chú thêm cho bác sĩ (không bắt buộc)"
  - Xã hội: "Bé có bắt chước việc nhà của người lớn (quét nhà, lau bàn) không?" — last question, buttons "Lưu tạm" + "Xem kết quả"
- Child picker screen: "Chọn bé để theo dõi" / "Tài khoản của mẹ có 2 hồ sơ bé" — child 1 "Nguyễn Bảo Minh, 18 tháng 12 ngày · Bé trai, Đánh giá gần nhất 02/08 · 22/25 mốc"; child 2 "Nguyễn Bảo An, 5 tháng 2 ngày · Bé gái, Chưa đo tăng trưởng tháng này"; add-new CTA "Thêm hồ sơ bé mới"; footnote about single-profile auto-select rule
- Login screen: tabs "Đăng nhập"/"Đăng ký", fields "Email"/"Mật khẩu", "☐ Ghi nhớ đăng nhập" / "Quên mật khẩu?", divider "hoặc đăng nhập nhanh", social buttons "Tiếp tục với Google/Apple/Facebook"
- Journal (Nhật ký) entries: "Bé tự cầm thìa ăn hết bát cháo!" (tags Vận động tinh, Tự lập), "Bé gọi "bà" rất rõ khi bà đến chơi" (tag Ngôn ngữ), "Lần đầu bé chơi cùng bạn ở công viên" (tag Xã hội – Cảm xúc)
- Add-journal moods: "Vui vẻ" / "Bình thường" / "Quấy"; domain chips: "Vận động thô/Vận động tinh/Ngôn ngữ/Xã hội – Cảm xúc"
- Notifications list items (5): "Cần theo dõi thêm" (2 giờ trước), "Đến hạn đo tăng trưởng" (Hôm nay), "Mốc đánh giá 18 tháng" (Hôm qua), "Hoạt động mới cho bé" (14/08), "Nhật ký tuần này" (11/08)
- Settings sections: "HỒ SƠ TRẺ" (Quản lý hồ sơ trẻ, Thêm bé mới), "ỨNG DỤNG" (Ngôn ngữ: Tiếng Việt, Thông báo & nhắc nhở toggle), "QUYỀN RIÊNG TƯ & BẢO MẬT" (Chính sách quyền riêng tư, Khóa ứng dụng bằng sinh trắc toggle, Xóa toàn bộ dữ liệu), "Đăng xuất", footer "Bé Lớn Khôn · phiên bản 1.0.0"
- Companion corner ("Góc đồng hành"): tabs "Bài viết/FAQ/Câu chuyện"; mentor card "Gợi ý từ Mentor — Bé 18 tháng chậm nói: 5 cách mẹ tương tác mỗi ngày."; article "Mốc phát triển ngôn ngữ 12–24 tháng — BS. Nguyễn Lan · 5 phút đọc"; FAQ "Khi nào nên đưa bé đi khám phát triển? · 3 phút đọc"; story "Con tôi chậm nói và hành trình 6 tháng" — Mẹ Hà · Câu chuyện kinh nghiệm
- Activity detail (move) example "Xếp chồng khối gỗ": tags "18–24 tháng / 10 phút / Cần người lớn ngồi cạnh"; goal "Vận động tinh, phối hợp tay – mắt, khả năng tập trung."; materials "5–6 khối gỗ vuông nhiều màu, mặt phẳng sạch."; 3 numbered steps; safety note "chọn khối lớn hơn miệng bé, không rời bé khi đang chơi."
- Activity detail (music) example "Con cò bé bé": tags "12–24 tháng / 4 phút / Ngôn ngữ · Vận động"; full lyric block (Vietnamese folk song lyrics, 2 verses + repeat note); movement tip about clapping/flapping arms
- Activity detail (story) example "Thỏ con đi chợ": tags "18–36 tháng / 9 phút / Ngôn ngữ · Kể chuyện"; 3-paragraph story about a rabbit going to market; "questions to ask after" tip

## Exact color palette (from the prototype's inline styles)

Primary green: #6FBE8F (buttons/accent) · dark green text: #2F6B4C, #4E9E74 · light green surfaces:
#E4F3EA, #F4FBF7, #F2FAF5 · app background: #F2F5F3 · white surface: #FFFFFF · borders: #E4EDE7,
#E1E8E4, #DCE5DF · purple accent (assessment flow): #8B7FD6, headings #5B4FA8, light surfaces
#EDEBFA, #F7F6FE, body text on purple #6E6A8C, border #DCD8F5, #C9C1EE · amber/warning: #D9A13B,
#B98A2E, headline #8A661F, light surfaces #FDF0D8, #FFFBF2, border #F0DFC0 · red/danger: #C0483C,
#A0524A, light surfaces #FFF6F5, #F3D6D2 · text: primary #33453C, secondary #5A6E63 / #7B8C82,
muted #9AAAA1, disabled #B3BFB8 · disabled/inactive nav icon fill: #D8E3DC. Font family: 'Quicksand'
(Google Font, weights 400/500/600/700 — use the `google_fonts` package's `GoogleFonts.quicksand()`
text theme rather than trying to bundle the woff2 files extracted from the prototype). Border
radius is large throughout: ~11-14px for inputs/small chips/rows, 13-16px for buttons/cards,
18-24px for phone-frame-level containers and hero images, 999px (fully round) for pill chips and
the floating action button. Bottom nav is a custom 5-tab row (not Android's default height): icon
chip 18x18 rounded rect (active = filled green #6FBE8F, inactive = muted #D8E3DC) + 8px label below,
active label color #4E9E74 bold, inactive #9AAAA1. Tabs in order: Trang chủ, Theo dõi, Hoạt động,
Nhật ký, Thêm — "Thêm" routes to Cài đặt/Góc đồng hành area (settings icon opens Settings; note the
prototype's own bottom-nav "Thêm" tab target maps to notifications/settings/companion screens —
since those aren't literally in a single icon, treat "Thêm" as a small in-app menu/hub screen that
links to Cài đặt, Góc đồng hành, and Thông báo, since the prototype doesn't show one dedicated
"Thêm" screen body — this is a deliberate, documented interpretation, not a guess to hide).

## Navigation graph (verbatim `go.toXX` targets found wired to buttons/icons across screens)

- Splash → "Bắt đầu hành trình" → Onboarding (to2); "Đã có tài khoản? Đăng nhập" → Login (to3)
- Onboarding → skip link and "Tiếp tục" → Login (to3)
- Login → "Đăng nhập" button, and each social login button → Chọn bé (to3b)
- Chọn bé → tapping either child card → Trang chủ (to4); "+ Thêm hồ sơ bé mới" → Hồ sơ bé (to5); "Vào Trang chủ của bé" button → Trang chủ (to4)
- Trang chủ → child chip/avatar → Hồ sơ bé (to3b in one place, to5 conceptually — use Hồ sơ bé); bell icon → Thông báo (to18); big child card → Hồ sơ bé (to5); assessment CTA "Bắt đầu đánh giá" → Câu hỏi nhóm 1 (to8a); 4 quick group buttons → to8a/to8b/to8c/to8d respectively; trend card "Xem chi tiết" → Lịch sử (to10); activity-of-the-day card → Chi tiết vận động (to12b); AI suggestion "Xem hoạt động gợi ý" → Hoạt động·Nhóm (to11); milestone reminder → Thông báo (to18); bottom nav → to4/to6/to11/to14/to19
- Hồ sơ bé → "✎ Sửa" toggles edit state in place; Huỷ/Lưu toggle back
- Theo dõi tăng trưởng → tabs switch metric in place; "Lịch sử" button → Lịch sử (to10); bottom nav same as above
- Assessment question screens 8a→8b→8c→8d chain via "Tiếp tục"; 8d's "Xem kết quả" → Kết quả (to9); "Lưu tạm" on 8d → Trang chủ (to4)
- Kết quả → "Gợi ý hoạt động phù hợp" → Hoạt động·Nhóm (to11); "Xem lịch sử đánh giá" → Lịch sử (to10)
- Lịch sử → bottom nav; entries are static list, no push target shown
- Hoạt động·Nhóm (group list) → tapping any of the 6 group rows → Hoạt động trong nhóm (to12), with the specific group index stored in state (openG0..openG5 setters)
- Hoạt động trong nhóm → back → Hoạt động·Nhóm (to11 via back arrow); tapping an item → detail screen: move-kind items → to12b, music-kind → to13, story-kind → to13b (component computes this by group kind)
- Activity detail screens (12b/13/13b) → back arrow → Hoạt động trong nhóm (to12); "Đánh dấu đã thực hiện" → to15 in the prototype code (this looks like a possible authoring inconsistency in the prototype — it points at "Thêm nhật ký" screen id 15 rather than back to the list; PRESERVE this behavior since it actually reads as an intentional UX shortcut: completing an activity offers to log it in the journal immediately); heart/favorite icon toggles favorite state in place, no navigation
- Nhật ký (journal list) → floating "+" button → Thêm nhật ký (to15); bottom nav
- Thêm nhật ký → "Lưu nhật ký" → Nhật ký (to14); "Hủy" (top bar) → Nhật ký (to14)
- Góc đồng hành → bottom nav only in this screen's footer (no card push targets shown in the fragment available)
- Thông báo → each notification card routes to a relevant screen: "Cần theo dõi thêm" → Lịch sử (to10); "Đến hạn đo tăng trưởng" → Theo dõi tăng trưởng (to6); "Mốc đánh giá 18 tháng" → Trang chủ (to4); "Hoạt động mới cho bé" → Hoạt động·Nhóm (to11); "Nhật ký tuần này" → Nhật ký (to14); bottom nav
- Cài đặt → "Quản lý hồ sơ trẻ" and "Thêm bé mới" rows → Hồ sơ bé (to5); other rows are static/no-op in the prototype (privacy policy, biometric toggle, delete data, logout) — for Flutter, make these real tappable rows that at minimum show a placeholder dialog/snackbar or a stub screen, since a settings screen with dead rows would look broken; use your judgment, document the choice

Use this graph to drive `go_router` routes. Where the prototype's own logic looks slightly
inconsistent (e.g. activity-detail "done" button jumping to add-journal instead of back), preserve
it deliberately and leave a short code comment explaining you kept the prototype's intended
shortcut rather than "fixing" it into a different flow.
