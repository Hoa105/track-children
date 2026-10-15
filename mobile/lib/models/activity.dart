import 'package:flutter/material.dart';

class ActivityGroup {
  const ActivityGroup(this.id, this.name, this.description, this.icon);
  final String id, name, description;
  final IconData icon;
}

class ChildActivity {
  const ChildActivity(
    this.id,
    this.groupId,
    this.name,
    this.minMonths,
    this.maxMonths,
    this.minutes,
  );
  final String id, groupId, name;
  final int minMonths, maxMonths, minutes;
  String get ageLabel => '$minMonths–$maxMonths tháng';
}

const activityGroups = <ActivityGroup>[
  ActivityGroup(
    'g0',
    'Vận động thô',
    'Các bài tập giúp bé lẫy, ngồi, bò, đi vững.',
    Icons.directions_run_rounded,
  ),
  ActivityGroup(
    'g1',
    'Vận động tinh',
    'Rèn khéo tay, phối hợp tay – mắt cho bé.',
    Icons.back_hand_outlined,
  ),
  ActivityGroup(
    'g2',
    'Ngôn ngữ',
    'Khuyến khích bé bập bẹ, nói từ, ghép câu.',
    Icons.chat_bubble_outline_rounded,
  ),
  ActivityGroup(
    'g3',
    'Nhận thức & Cảm xúc xã hội',
    'Phát triển tư duy, cảm xúc và kỹ năng xã hội.',
    Icons.psychology_outlined,
  ),
  ActivityGroup(
    'g4',
    'Âm nhạc & âm thanh',
    'Giúp bé cảm nhận nhịp điệu và âm thanh.',
    Icons.music_note_rounded,
  ),
  ActivityGroup(
    'g5',
    'Kể chuyện',
    'Nuôi dưỡng trí tưởng tượng và ngôn ngữ qua chuyện kể.',
    Icons.auto_stories_outlined,
  ),
];
const activityCatalog = <ChildActivity>[
  ChildActivity('g0-0', 'g0', 'Tummy time (nằm sấp)', 0, 3, 5),
  ChildActivity('g0-1', 'g0', 'Tập lẫy, lăn người', 3, 6, 10),
  ChildActivity('g0-2', 'g0', 'Tập ngồi có hỗ trợ', 5, 8, 10),
  ChildActivity('g0-3', 'g0', 'Bò qua vật cản (gối, hộp)', 7, 10, 15),
  ChildActivity('g0-4', 'g0', 'Tập đứng vịn', 8, 12, 10),
  ChildActivity('g0-5', 'g0', 'Tập bước chững (dắt tay)', 10, 14, 15),
  ChildActivity('g0-6', 'g0', 'Đi bộ tự do trong nhà', 12, 18, 15),
  ChildActivity('g0-7', 'g0', 'Ném – bắt bóng to', 14, 24, 10),
  ChildActivity('g0-8', 'g0', 'Bước lên/xuống bậc thang thấp', 18, 24, 10),
  ChildActivity('g0-9', 'g0', 'Nhảy tại chỗ hai chân', 20, 30, 10),
  ChildActivity('g0-10', 'g0', 'Đạp xe 3 bánh / xe chòi chân', 24, 36, 15),
  ChildActivity('g0-11', 'g0', 'Đi trên đường vạch (thăng bằng)', 30, 36, 10),
  ChildActivity('g1-0', 'g1', 'Nắm – lắc lục lạc', 0, 4, 5),
  ChildActivity('g1-1', 'g1', 'Chuyển đồ vật qua tay', 4, 7, 10),
  ChildActivity('g1-2', 'g1', 'Nhón nhặt vật nhỏ (ngón cái–trỏ)', 8, 10, 10),
  ChildActivity('g1-3', 'g1', 'Xếp chồng 2–3 khối vuông', 10, 14, 10),
  ChildActivity('g1-4', 'g1', 'Xâu hạt gỗ to', 14, 18, 15),
  ChildActivity('g1-5', 'g1', 'Vẽ nghịch bằng bút sáp', 15, 20, 10),
  ChildActivity('g1-6', 'g1', 'Xé giấy, vò giấy', 16, 22, 10),
  ChildActivity('g1-7', 'g1', 'Xúc / đổ nước, cát vào cốc', 18, 24, 15),
  ChildActivity('g1-8', 'g1', 'Xếp chồng 6–8 khối', 22, 28, 15),
  ChildActivity('g1-9', 'g1', 'Cài / mở cúc áo lớn', 24, 30, 10),
  ChildActivity('g1-10', 'g1', 'Tô màu trong đường viền', 28, 34, 15),
  ChildActivity('g1-11', 'g1', 'Cắt giấy bằng kéo an toàn', 32, 36, 15),
  ChildActivity('g2-0', 'g2', 'Trò chuyện – phát âm theo bé', 0, 4, 5),
  ChildActivity('g2-1', 'g2', 'Gọi tên khi bé phát âm "ba, ma"', 4, 8, 10),
  ChildActivity('g2-2', 'g2', 'Đọc sách tranh, chỉ hình gọi tên', 6, 12, 10),
  ChildActivity('g2-3', 'g2', 'Gọi tên bộ phận cơ thể', 10, 15, 10),
  ChildActivity('g2-4', 'g2', 'Bắt chước âm thanh động vật', 12, 18, 10),
  ChildActivity('g2-5', 'g2', 'Đố tên đồ vật quanh nhà', 15, 20, 10),
  ChildActivity('g2-6', 'g2', 'Ghép 2 từ thành câu ngắn', 18, 24, 10),
  ChildActivity('g2-7', 'g2', 'Hỏi – đáp "cái gì đây"', 20, 26, 10),
  ChildActivity('g2-8', 'g2', 'Kể lại 1 hoạt động vừa làm', 24, 30, 10),
  ChildActivity('g2-9', 'g2', 'Học từ mới theo chủ đề', 26, 32, 15),
  ChildActivity(
    'g2-10',
    'g2',
    'Đặt câu hỏi "tại sao, như thế nào"',
    30,
    36,
    15,
  ),
  ChildActivity('g3-0', 'g3', 'Trốn tìm đơn giản (ú òa)', 4, 8, 5),
  ChildActivity('g3-1', 'g3', 'Tìm đồ vật bị giấu', 8, 12, 10),
  ChildActivity('g3-2', 'g3', 'Xếp hình phân loại theo màu', 12, 18, 10),
  ChildActivity('g3-3', 'g3', 'Nhận biết cảm xúc qua tranh', 15, 20, 10),
  ChildActivity('g3-4', 'g3', 'Ghép tranh 2–4 miếng', 18, 24, 15),
  ChildActivity('g3-5', 'g3', 'Đóng vai (nấu ăn, bác sĩ)', 20, 26, 15),
  ChildActivity('g3-6', 'g3', 'Tự xúc ăn, tự cởi giày', 22, 28, 0),
  ChildActivity('g3-7', 'g3', 'Chia sẻ đồ chơi với bạn', 24, 30, 15),
  ChildActivity('g3-8', 'g3', 'Ghép puzzle 6–9 miếng', 28, 34, 15),
  ChildActivity('g3-9', 'g3', 'Phân loại đồ vật theo nhóm', 30, 36, 15),
  ChildActivity('g4-0', 'g4', 'Nghe nhạc êm dịu, ru ngủ', 0, 6, 10),
  ChildActivity('g4-1', 'g4', 'Lắc lục lạc / chuông theo nhịp', 4, 10, 10),
  ChildActivity('g4-2', 'g4', 'Hát kèm vỗ tay theo nhịp', 8, 14, 10),
  ChildActivity('g4-3', 'g4', 'Con cò bé bé', 12, 24, 4),
  ChildActivity('g4-4', 'g4', 'Gõ nhịp bằng thìa, trống lắc', 15, 24, 10),
  ChildActivity('g4-5', 'g4', 'Hát theo lời bài hát quen thuộc', 20, 30, 10),
  ChildActivity('g4-6', 'g4', 'Nhảy múa tự do theo nhạc', 24, 36, 15),
  ChildActivity('g4-7', 'g4', 'Phân biệt âm to/nhỏ, nhanh/chậm', 28, 36, 10),
  ChildActivity('g5-0', 'g5', 'Nghe kể chuyện có hình minh họa', 6, 12, 5),
  ChildActivity(
    'g5-1',
    'g5',
    'Chuyện ngắn lặp cấu trúc ("Cáo và Gà")',
    12,
    18,
    10,
  ),
  ChildActivity('g5-2', 'g5', 'Thỏ con đi chợ', 18, 36, 9),
  ChildActivity('g5-3', 'g5', 'Chuyện có tương tác – bé chỉ hình', 15, 22, 10),
  ChildActivity('g5-4', 'g5', 'Chuyện dân gian ngắn ("Tích Chu")', 20, 28, 15),
  ChildActivity('g5-5', 'g5', 'Hỏi lại "sau đó điều gì xảy ra?"', 24, 32, 15),
  ChildActivity('g5-6', 'g5', 'Bé tự kể lại chuyện bằng lời mình', 30, 36, 15),
];
