import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/activity.dart';
import '../../services/demo_store.dart';
import '../../services/who_bmi_reference.dart';

part 'activities_discovery.dart';

const _heading = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);
const _title = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);
const _secondary = TextStyle(
  fontSize: 13,
  color: AppColors.textSecondary,
  height: 1.5,
);

class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({super.key, required this.childId, this.group});
  final String childId;
  final ActivityGroup? group;
  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  int _status = 0, _age = 0, _duration = 0, _sort = 0;
  static const ages = [(0, 36), (0, 6), (6, 12), (12, 18), (18, 24), (24, 36)];
  bool get _filtered => _status != 0 || _age != 0 || _duration != 0;
  void _reset() => setState(() {
    _status = _age = _duration = _sort = 0;
  });

  Future<void> _filters() async {
    var status = _status, age = _age, duration = _duration, sort = _sort;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Bộ lọc hoạt động', style: _heading),
                      ),
                      IconButton(
                        tooltip: 'Đóng bộ lọc',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _choices(
                        'Trạng thái',
                        ['Tất cả', 'Chưa thực hiện', 'Đã thực hiện'],
                        status,
                        (v) => update(() => status = v),
                      ),
                      _choices(
                        'Độ tuổi',
                        [
                          'Tất cả độ tuổi',
                          '0–6 tháng',
                          '6–12 tháng',
                          '12–18 tháng',
                          '18–24 tháng',
                          '24–36 tháng',
                        ],
                        age,
                        (v) => update(() => age = v),
                      ),
                      _choices(
                        'Thời lượng',
                        ['Tất cả', '≤ 5 phút', '5–10 phút', '> 10 phút'],
                        duration,
                        (v) => update(() => duration = v),
                      ),
                      _choices(
                        'Sắp xếp',
                        ['Phù hợp tuổi bé', 'Chưa thực hiện trước'],
                        sort,
                        (v) => update(() => sort = v),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => update(() {
                          status = age = duration = sort = 0;
                        }),
                        child: const Text('Đặt lại'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Áp dụng'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply == true && mounted) {
      setState(() {
        _status = status;
        _age = age;
        _duration = duration;
        _sort = sort;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final store = DemoStore.instance;
      final child = store.childById(widget.childId);
      final done = store.completedActivities(widget.childId);
      final favorites = store.favoriteActivities;
      final months = child == null
          ? 0
          : WhoBmiReference.ageMonths(
              DateTime.parse(child['date_of_birth'] as String),
              DateTime.now(),
            );
      final items = activityCatalog.where((a) {
        if (widget.group == null
            ? !favorites.contains(a.id)
            : a.groupId != widget.group!.id) {
          return false;
        }
        if (_status == 1 && done.contains(a.id) ||
            _status == 2 && !done.contains(a.id)) {
          return false;
        }
        if (_age != 0 &&
            (a.minMonths > ages[_age].$2 || a.maxMonths < ages[_age].$1)) {
          return false;
        }
        if (_duration != 0 && a.minutes == 0) return false;
        if (_duration == 1 && a.minutes > 5 ||
            _duration == 2 && (a.minutes < 5 || a.minutes > 10) ||
            _duration == 3 && a.minutes <= 10) {
          return false;
        }
        return true;
      }).toList();
      int distance(ChildActivity a) => months < a.minMonths
          ? a.minMonths - months
          : months > a.maxMonths
          ? months - a.maxMonths
          : 0;
      items.sort((a, b) {
        final order = _sort == 1
            ? (done.contains(a.id) ? 1 : 0).compareTo(
                done.contains(b.id) ? 1 : 0,
              )
            : distance(a).compareTo(distance(b));
        return order != 0 ? order : a.minMonths.compareTo(b.minMonths);
      });
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(
            widget.group?.name ?? 'Hoạt động yêu thích',
            style: _heading,
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${items.length} hoạt động${_filtered ? ' · Đang lọc' : ''}',
                      style: _secondary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Bộ lọc',
                    onPressed: _filters,
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: _filtered
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _filtered ? 'Không có hoạt động phù hợp bộ lọc.' : 'Chưa có hoạt động yêu thích.\nChạm trái tim trong chi tiết để lưu lại.',
                              textAlign: TextAlign.center,
                              style: _secondary,
                            ),
                            if (_filtered)
                              TextButton(
                                onPressed: _reset,
                                child: const Text('Xóa bộ lọc'),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final a = items[i];
                        final group = activityGroups.firstWhere(
                          (g) => g.id == a.groupId,
                        );
                        return _Card(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ActivityDetailScreen(
                                childId: widget.childId,
                                activity: a,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              _PlayArt(groupId: group.id),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.name, style: _title),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${a.ageLabel} · ${a.minutes == 0 ? 'Theo bữa' : '${a.minutes} phút'}',
                                      style: _secondary,
                                    ),
                                    if (done.contains(a.id))
                                      const Text(
                                        'Đã thực hiện',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                done.contains(a.id)
                                    ? Icons.check_circle_rounded
                                    : Icons.chevron_right_rounded,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _choices(
  String title,
  List<String> labels,
  int selected,
  ValueChanged<int> onSelect,
) => Padding(
  padding: const EdgeInsets.only(bottom: 24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: _title),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < labels.length; i++)
            ChoiceChip(
              label: Text(labels[i]),
              selected: i == selected,
              selectedColor: AppColors.primarySoft,
              labelStyle: TextStyle(
                color: i == selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) => onSelect(i),
            ),
        ],
      ),
    ],
  ),
);

class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.childId,
    required this.activity,
  });
  final String childId;
  final ChildActivity activity;
  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _saving = false;
  Future<void> _save(bool favorite) async {
    setState(() => _saving = true);
    final store = DemoStore.instance;
    try {
      if (favorite) {
        await store.setActivityFavorite(
          widget.activity.id,
          !store.favoriteActivities.contains(widget.activity.id),
        );
      } else {
        await store.setActivityDone(
          widget.childId,
          widget.activity.id,
          !store
              .completedActivities(widget.childId)
              .contains(widget.activity.id),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              favorite
                  ? 'Đã cập nhật yêu thích'
                  : 'Đã cập nhật hoạt động của bé',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được thay đổi. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final a = widget.activity;
      final store = DemoStore.instance;
      final group = activityGroups.firstWhere((g) => g.id == a.groupId);
      final done = store.completedActivities(widget.childId).contains(a.id);
      final favorite = store.favoriteActivities.contains(a.id);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Chi tiết hoạt động', style: _heading),
          actions: [
            IconButton(
              tooltip: favorite ? 'Bỏ yêu thích' : 'Yêu thích',
              onPressed: _saving ? null : () => _save(true),
              icon: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(favorite),
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'activity-art-${a.id}',
                    child: Center(
                      child: _PlayArt(groupId: group.id, large: true),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(a.name, style: _heading),
                  const SizedBox(height: 8),
                  Text(
                    '${a.ageLabel} · ${a.minutes == 0 ? 'Theo bữa' : '${a.minutes} phút'}',
                    style: _secondary,
                  ),
                  const SizedBox(height: 8),
                  Text(group.name, style: _secondary),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    child: Row(
                      key: ValueKey(done),
                      children: [
                        Icon(
                          done
                              ? Icons.verified_rounded
                              : Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            done
                                ? 'Đã chơi cùng bé'
                                : 'Sẵn sàng cùng bé khám phá',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...activitySections(a).map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.$1, style: _title),
                      const SizedBox(height: 12),
                      Text(
                        section.$2,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _saving || store.childById(widget.childId) == null
                  ? null
                  : () => _save(false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _saving
                      ? 'Đang lưu…'
                      : done
                      ? 'Bỏ đánh dấu'
                      : 'Đánh dấu đã thực hiện',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

List<(String, String)> activitySections(ChildActivity a) {
  // Content is selected per activity, rather than reusing unrelated prototype instructions.
  return activityInstructions[a.id] ??
      [
        (
          'Mục tiêu',
          activityGroups.firstWhere((g) => g.id == a.groupId).description,
        ),
        (
          'Cùng bé thực hiện',
          'Chọn không gian yên tĩnh, phù hợp với hoạt động “${a.name}”. Người lớn làm mẫu chậm, cho bé quan sát rồi khuyến khích bé thử theo khả năng. Dừng khi bé mệt hoặc không muốn tiếp tục.',
        ),
        (
          'Lưu ý',
          'Luôn có người lớn đồng hành. Độ tuổi và thời lượng chỉ để tham khảo; không ép bé hoàn thành. Hướng dẫn chi tiết cho hoạt động này đang được bổ sung.',
        ),
      ];
}

const activityInstructions = <String, List<(String, String)>>{
  'g1-3': [
    ('Mục tiêu', 'Khuyến khích phối hợp tay – mắt và sự khéo léo của bàn tay.'),
    (
      'Cần chuẩn bị',
      '2–3 khối đồ chơi lớn, phù hợp độ tuổi; mặt phẳng sạch và chắc chắn.',
    ),
    (
      'Các bước thực hiện',
      '1. Ngồi cạnh bé và đặt các khối trong tầm với.\n2. Xếp chồng hai khối thật chậm để bé quan sát.\n3. Mời bé đặt thêm một khối hoặc tự thử lại. Khen sự cố gắng của bé.',
    ),
    (
      'Lưu ý an toàn',
      'Không dùng khối nhỏ có thể nuốt. Luôn quan sát bé trong khi chơi.',
    ),
  ],
  'g4-3': [
    (
      'Lời bài hát',
      'Con cò bé bé,\nNó đậu cành tre.\nĐi không hỏi mẹ,\nBiết đi đường nào.\nKhi đi em hỏi,\nKhi về em chào.\nMiệng em chúm chím,\nMẹ có yêu không nào.',
    ),
    (
      'Gợi ý vận động',
      'Hát chậm, vỗ tay nhẹ theo nhịp và mời bé bắt chước. Có thể dừng giữa câu để bé đáp lại bằng âm thanh hoặc cử chỉ.',
    ),
  ],
  'g5-2': [
    (
      'Thỏ con đi chợ',
      'Sáng sớm, Thỏ con xách giỏ theo mẹ ra chợ. Dọc đường, Thỏ nhìn thấy những luống rau xanh mướt.\n\nỞ chợ, Thỏ chọn một củ cà rốt màu cam. Thỏ nói lời cảm ơn rồi cẩn thận đặt cà rốt vào giỏ.\n\nTrên đường về, Thỏ kể cho mẹ nghe những điều mình nhìn thấy. Mẹ mỉm cười lắng nghe. Hai mẹ con cùng chuẩn bị bữa trưa.',
    ),
    (
      'Hỏi bé sau khi kể',
      'Thỏ con đi đâu cùng mẹ? Củ cà rốt có màu gì? Con thích loại rau củ nào?',
    ),
  ],
};

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}
