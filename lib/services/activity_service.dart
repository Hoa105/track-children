import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/activity.dart';
import '../models/activity_group.dart';

abstract class ActivityService {
  Future<List<ActivityGroup>> getGroups();
  Future<void> markDone(String groupId, String activityId, bool done);
  Future<void> toggleFavorite(String groupId, String activityId, bool favorite);
  Future<List<Activity>> getFavorites();
}

/// Seeded verbatim from the prototype's `groups` mock data array
/// (prototype_reference.md § "Activity groups + items").
class MockActivityService implements ActivityService {
  late final List<ActivityGroup> _groups = _buildGroups();

  static Activity _item(
    String groupId,
    int index,
    String n,
    String a,
    String t,
    bool d,
    ActivityKind kind,
  ) {
    return Activity(
      id: '$groupId-$index',
      groupId: groupId,
      name: n,
      ageRangeLabel: a,
      durationLabel: t,
      isDone: d,
      kind: kind,
      goal: kind == ActivityKind.move
          ? 'Vận động tinh, phối hợp tay – mắt, khả năng tập trung.'
          : null,
      materials: kind == ActivityKind.move
          ? const ['5–6 khối gỗ vuông nhiều màu', 'Mặt phẳng sạch, chắc']
          : const [],
      steps: kind == ActivityKind.move
          ? const [
              'Ngồi cùng bé trên sàn, đặt các khối gỗ trước mặt bé.',
              'Xếp mẫu 2–3 khối chồng lên nhau cho bé quan sát.',
              'Khuyến khích bé tự xếp, vỗ tay khen khi bé làm được.',
            ]
          : const [],
      safetyNote: kind == ActivityKind.move
          ? 'Chọn khối lớn hơn miệng bé, không rời bé khi đang chơi.'
          : null,
      lyrics: kind == ActivityKind.music
          ? 'Con cò cò bé, cò bay lả lả bay la,\n'
              'Bay từ cửa phủ, bay ra cánh đồng.\n\n'
              'Con cò cò bé, cò bay lả lả bay la,\n'
              'Tình tính tang là tang tính tình...\n'
              '(hát lặp lại 2–3 lần theo nhịp vỗ tay)'
          : null,
      movementTip: kind == ActivityKind.music
          ? 'Vừa hát vừa vỗ tay theo nhịp, đưa hai tay lên như cánh cò vỗ – giúp bé cảm nhận nhịp điệu qua vận động.'
          : null,
      storyParagraphs: kind == ActivityKind.story
          ? const [
              'Sáng sớm, Thỏ con xách giỏ theo mẹ ra chợ. Trên đường đi, Thỏ con nhìn thấy rất nhiều rau củ đầy màu sắc.',
              'Đến chợ, mẹ mua cho Thỏ con một củ cà rốt to và giòn. Thỏ con vui lắm, ôm chặt củ cà rốt vào lòng.',
              'Trên đường về, Thỏ con kể cho mẹ nghe về những điều mình nhìn thấy ở chợ. Mẹ mỉm cười lắng nghe Thỏ con kể.',
            ]
          : const [],
      questionsToAsk: kind == ActivityKind.story
          ? 'Con thấy Thỏ con mua gì ở chợ? Con thích ăn loại rau củ nào nhất?'
          : null,
      tagsNote: switch (kind) {
        ActivityKind.move => 'Cần người lớn ngồi cạnh',
        ActivityKind.music => 'Ngôn ngữ · Vận động',
        ActivityKind.story => 'Ngôn ngữ · Kể chuyện',
      },
    );
  }

  List<ActivityGroup> _buildGroups() {
    final raw = <Map<String, dynamic>>[
      {
        'id': 'g0',
        'name': 'Vận động thô',
        'tint': AppColors.surfaceGreen,
        'kind': ActivityKind.move,
        'emoji': '🏃',
        'description': 'Các bài tập giúp bé lẫy, ngồi, bò, đi vững.',
        'items': [
          ['Tummy time (nằm sấp)', '0–3 th', '5 phút', true],
          ['Tập lẫy, lăn người', '3–6 th', '10 phút', true],
          ['Tập ngồi có hỗ trợ', '5–8 th', '10 phút', true],
          ['Bò qua vật cản (gối, hộp)', '7–10 th', '15 phút', true],
          ['Tập đứng vịn', '8–12 th', '10 phút', true],
          ['Tập bước chững (dắt tay)', '10–14 th', '15 phút', true],
          ['Đi bộ tự do trong nhà', '12–18 th', '15 phút', false],
          ['Ném – bắt bóng to', '14–24 th', '10 phút', false],
          ['Bước lên/xuống bậc thang thấp', '18–24 th', '10 phút', false],
          ['Nhảy tại chỗ hai chân', '20–30 th', '10 phút', false],
          ['Đạp xe 3 bánh / xe chòi chân', '24–36 th', '15 phút', false],
          ['Đi trên đường vạch (thăng bằng)', '30–36 th', '10 phút', false],
        ],
      },
      {
        'id': 'g1',
        'name': 'Vận động tinh',
        'tint': AppColors.purpleSurface,
        'kind': ActivityKind.move,
        'emoji': '✋',
        'description': 'Rèn khéo tay, phối hợp tay – mắt cho bé.',
        'items': [
          ['Nắm – lắc lục lạc', '0–4 th', '5 phút', true],
          ['Chuyển đồ vật qua tay', '4–7 th', '10 phút', true],
          ['Nhón nhặt vật nhỏ (ngón cái–trỏ)', '8–10 th', '10 phút', true],
          ['Xếp chồng 2–3 khối vuông', '10–14 th', '10 phút', true],
          ['Xâu hạt gỗ to', '14–18 th', '15 phút', true],
          ['Vẽ nghịch bằng bút sáp', '15–20 th', '10 phút', false],
          ['Xé giấy, vò giấy', '16–22 th', '10 phút', false],
          ['Xúc / đổ nước, cát vào cốc', '18–24 th', '15 phút', false],
          ['Xếp chồng 6–8 khối', '22–28 th', '15 phút', false],
          ['Cài / mở cúc áo lớn', '24–30 th', '10 phút', false],
          ['Tô màu trong đường viền', '28–34 th', '15 phút', false],
          ['Cắt giấy bằng kéo an toàn', '32–36 th', '15 phút', false],
        ],
      },
      {
        'id': 'g2',
        'name': 'Ngôn ngữ',
        'tint': AppColors.amberSurface,
        'kind': ActivityKind.move,
        'emoji': '💬',
        'description': 'Khuyến khích bé bập bẹ, nói từ, ghép câu.',
        'items': [
          ['Trò chuyện – phát âm theo bé', '0–4 th', '5 phút', true],
          ['Gọi tên khi bé phát âm "ba, ma"', '4–8 th', '10 phút', true],
          ['Đọc sách tranh, chỉ hình gọi tên', '6–12 th', '10 phút', true],
          ['Gọi tên bộ phận cơ thể', '10–15 th', '10 phút', true],
          ['Bắt chước âm thanh động vật', '12–18 th', '10 phút', true],
          ['Đố tên đồ vật quanh nhà', '15–20 th', '10 phút', false],
          ['Ghép 2 từ thành câu ngắn', '18–24 th', '10 phút', false],
          ['Hỏi – đáp "cái gì đây"', '20–26 th', '10 phút', false],
          ['Kể lại 1 hoạt động vừa làm', '24–30 th', '10 phút', false],
          ['Học từ mới theo chủ đề', '26–32 th', '15 phút', false],
          ['Đặt câu hỏi "tại sao, như thế nào"', '30–36 th', '15 phút', false],
        ],
      },
      {
        'id': 'g3',
        'name': 'Nhận thức & Cảm xúc xã hội',
        'tint': AppColors.surfaceGreen,
        'kind': ActivityKind.move,
        'emoji': '🧠',
        'description': 'Phát triển tư duy, cảm xúc và kỹ năng xã hội.',
        'items': [
          ['Trốn tìm đơn giản (ú òa)', '4–8 th', '5 phút', true],
          ['Tìm đồ vật bị giấu', '8–12 th', '10 phút', true],
          ['Xếp hình phân loại theo màu', '12–18 th', '10 phút', true],
          ['Nhận biết cảm xúc qua tranh', '15–20 th', '10 phút', false],
          ['Ghép tranh 2–4 miếng', '18–24 th', '15 phút', false],
          ['Đóng vai (nấu ăn, bác sĩ)', '20–26 th', '15 phút', false],
          ['Tự xúc ăn, tự cởi giày', '22–28 th', 'theo bữa', false],
          ['Chia sẻ đồ chơi với bạn', '24–30 th', '15 phút', false],
          ['Ghép puzzle 6–9 miếng', '28–34 th', '15 phút', false],
          ['Phân loại đồ vật theo nhóm', '30–36 th', '15 phút', false],
        ],
      },
      {
        'id': 'g4',
        'name': 'Âm nhạc & âm thanh',
        'tint': AppColors.purpleSurface,
        'kind': ActivityKind.music,
        'emoji': '🎵',
        'description': 'Giúp bé cảm nhận nhịp điệu và âm thanh.',
        'items': [
          ['Nghe nhạc êm dịu, ru ngủ', '0–6 th', '10 phút', true],
          ['Lắc lục lạc / chuông theo nhịp', '4–10 th', '10 phút', true],
          ['Hát kèm vỗ tay theo nhịp', '8–14 th', '10 phút', true],
          ['Con cò bé bé', '12–24 th', '4 phút', false],
          ['Gõ nhịp bằng thìa, trống lắc', '15–24 th', '10 phút', false],
          ['Hát theo lời bài hát quen thuộc', '20–30 th', '10 phút', false],
          ['Nhảy múa tự do theo nhạc', '24–36 th', '15 phút', false],
          ['Phân biệt âm to/nhỏ, nhanh/chậm', '28–36 th', '10 phút', false],
        ],
      },
      {
        'id': 'g5',
        'name': 'Kể chuyện',
        'tint': AppColors.amberSurface,
        'kind': ActivityKind.story,
        'emoji': '📖',
        'description': 'Nuôi dưỡng trí tưởng tượng và ngôn ngữ qua chuyện kể.',
        'items': [
          ['Nghe kể chuyện có hình minh họa', '6–12 th', '5 phút', true],
          ['Chuyện ngắn lặp cấu trúc ("Cáo và Gà")', '12–18 th', '10 phút', true],
          ['Thỏ con đi chợ', '18–36 th', '9 phút', false],
          ['Chuyện có tương tác – bé chỉ hình', '15–22 th', '10 phút', false],
          ['Chuyện dân gian ngắn ("Tích Chu")', '20–28 th', '15 phút', false],
          ['Hỏi lại "sau đó điều gì xảy ra?"', '24–32 th', '15 phút', false],
          ['Bé tự kể lại chuyện bằng lời mình', '30–36 th', '15 phút', false],
        ],
      },
    ];

    return raw.map((g) {
      final id = g['id'] as String;
      final kind = g['kind'] as ActivityKind;
      final items = (g['items'] as List)
          .asMap()
          .entries
          .map((e) => _item(id, e.key, e.value[0], e.value[1], e.value[2], e.value[3], kind))
          .toList();
      return ActivityGroup(
        id: id,
        name: g['name'] as String,
        tint: g['tint'] as Color,
        kind: kind,
        emoji: g['emoji'] as String,
        description: g['description'] as String,
        items: items,
      );
    }).toList();
  }

  @override
  Future<List<ActivityGroup>> getGroups() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _groups;
  }

  @override
  Future<void> markDone(String groupId, String activityId, bool done) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final group = _groups.firstWhere((g) => g.id == groupId);
    final index = group.items.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      group.items[index] = group.items[index].copyWith(isDone: done);
    }
  }

  @override
  Future<void> toggleFavorite(String groupId, String activityId, bool favorite) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final group = _groups.firstWhere((g) => g.id == groupId);
    final index = group.items.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      group.items[index] = group.items[index].copyWith(isFavorite: favorite);
    }
  }

  @override
  Future<List<Activity>> getFavorites() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      for (final group in _groups)
        for (final activity in group.items)
          if (activity.isFavorite) activity,
    ];
  }
}
