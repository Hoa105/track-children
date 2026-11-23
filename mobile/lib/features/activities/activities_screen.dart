import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/activity.dart';
import '../../services/activity_api.dart';
import '../../services/demo_store.dart';
import '../../services/who_bmi_reference.dart';
import 'activity_journal_screen.dart';

part 'activities_discovery.dart';

const _heading = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: ActivitiesColors.textPrimary,
  letterSpacing: -0.3,
);
const _title = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: ActivitiesColors.textPrimary,
);
const _secondary = TextStyle(
  fontSize: 13,
  color: ActivitiesColors.textSecondary,
  height: 1.45,
);
const _body = TextStyle(
  fontSize: 15,
  height: 1.6,
  color: ActivitiesColors.textPrimary,
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
  static const _ranges = [(0, 6), (6, 12), (12, 18), (18, 24), (24, 36)];
  // Tuổi hiện tại của bé (tháng); null nếu chưa có ngày sinh.
  late final int? _childMonths = _monthsOf(widget.childId);
  // Lựa chọn độ tuổi: 0 = tất cả, 1 = đúng tuổi bé (nếu biết), sau đó là các khoảng cố định.
  late final List<String> _ageLabels = [
    'Tất cả độ tuổi',
    if (_childMonths != null) 'Tuổi của bé · $_childMonths tháng',
    for (final r in _ranges) '${r.$1}–${r.$2} tháng',
  ];
  int get _childAge => _childMonths == null ? 0 : 1;
  bool get _filtered => _status != 0 || _age != 0 || _duration != 0 || _sort != 0;
  int get _filterCount =>
      (_status != 0 ? 1 : 0) +
      (_age != 0 ? 1 : 0) +
      (_duration != 0 ? 1 : 0) +
      (_sort != 0 ? 1 : 0);

  void _reset() => setState(() {
    _status = _age = _duration = _sort = 0;
  });

  static int? _monthsOf(String childId) {
    final dob = DemoStore.instance.childById(childId)?['date_of_birth'];
    if (dob is! String) return null;
    return WhoBmiReference.ageMonths(DateTime.parse(dob), DateTime.now());
  }

  bool _matchesAge(ChildActivity a) {
    if (_age == 0) return true;
    if (_age == _childAge) {
      return a.minMonths <= _childMonths! && _childMonths <= a.maxMonths;
    }
    final (lo, hi) = _ranges[_age - _childAge - 1];
    return a.minMonths < hi && a.maxMonths > lo;
  }

  @override
  void initState() {
    super.initState();
    _age = _childAge;
  }

  Future<void> _filters() async {
    var status = _status, age = _age, duration = _duration, sort = _sort;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ActivitiesColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Bộ lọc hoạt động', style: _heading),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Đóng',
                        style: IconButton.styleFrom(
                          backgroundColor: ActivitiesColors.primarySoft,
                          minimumSize: const Size(36, 36),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: ActivitiesColors.border),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    children: [
                      _choices(
                        'Trạng thái thực hiện',
                        ['Tất cả', 'Chưa thực hiện', 'Đã thực hiện'],
                        status,
                        (v) => update(() => status = v),
                      ),
                      _choices(
                        'Độ tuổi phù hợp',
                        _ageLabels,
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
                        'Sắp xếp danh sách',
                        ['Phù hợp tuổi bé', 'Chưa thực hiện trước'],
                        sort,
                        (v) => update(() => sort = v),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: ActivitiesColors.border.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => update(() {
                          status = duration = sort = 0;
                          age = _childAge;
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: ActivitiesColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Đặt lại'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: ActivitiesColors.primary,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Áp dụng bộ lọc',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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
    listenable: Listenable.merge([DemoStore.instance, activityCatalogState]),
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
        if (!_matchesAge(a)) return false;
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
        backgroundColor: ActivitiesColors.background,
        appBar: AppBar(
          backgroundColor: ActivitiesColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            widget.group?.name ?? 'Hoạt động yêu thích',
            style: _heading,
          ),
        ),
        body: Column(
          children: [
            // Quick one-handed filter chips bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  FilterChip(
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: _filtered ? Colors.white : ActivitiesColors.primary,
                    ),
                    label: Text(
                      _filtered ? 'Lọc ($_filterCount)' : 'Bộ lọc',
                    ),
                    selected: _filtered,
                    selectedColor: ActivitiesColors.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _filtered
                            ? ActivitiesColors.primary
                            : ActivitiesColors.border,
                      ),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _filtered ? Colors.white : ActivitiesColors.textPrimary,
                    ),
                    onSelected: (_) => _filters(),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    showCheckmark: false,
                    label: const Text('Chưa làm'),
                    selected: _status == 1,
                    selectedColor: ActivitiesColors.primarySoft,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _status == 1
                            ? ActivitiesColors.primary
                            : ActivitiesColors.border,
                      ),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _status == 1
                          ? ActivitiesColors.primary
                          : ActivitiesColors.textSecondary,
                    ),
                    onSelected: (val) => setState(() => _status = val ? 1 : 0),
                  ),
                  if (_childMonths != null) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      showCheckmark: false,
                      label: Text('Đúng tuổi bé ($_childMonths th)'),
                      selected: _age == _childAge,
                      selectedColor: ActivitiesColors.primarySoft,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _age == _childAge
                              ? ActivitiesColors.primary
                              : ActivitiesColors.border,
                        ),
                      ),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _age == _childAge
                            ? ActivitiesColors.primary
                            : ActivitiesColors.textSecondary,
                      ),
                      onSelected: (val) =>
                          setState(() => _age = val ? _childAge : 0),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilterChip(
                    showCheckmark: false,
                    label: const Text('≤ 5 phút'),
                    selected: _duration == 1,
                    selectedColor: ActivitiesColors.primarySoft,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _duration == 1
                            ? ActivitiesColors.primary
                            : ActivitiesColors.border,
                      ),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _duration == 1
                          ? ActivitiesColors.primary
                          : ActivitiesColors.textSecondary,
                    ),
                    onSelected: (val) => setState(() => _duration = val ? 1 : 0),
                  ),
                  if (_filtered) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      label: const Text('Xóa lọc'),
                      avatar: const Icon(Icons.close_rounded, size: 14),
                      backgroundColor: ActivitiesColors.primarySoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: ActivitiesColors.border),
                      ),
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ActivitiesColors.primary,
                      ),
                      onPressed: _reset,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${items.length} hoạt động phù hợp',
                    style: _secondary.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: ActivitiesColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _filtered
                                    ? Icons.filter_alt_off_outlined
                                    : Icons.favorite_border_rounded,
                                size: 36,
                                color: ActivitiesColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filtered
                                  ? 'Không tìm thấy hoạt động phù hợp bộ lọc.'
                                  : 'Chưa có hoạt động yêu thích.\nChạm biểu tượng trái tim để lưu lại những trò bé thích!',
                              textAlign: TextAlign.center,
                              style: _secondary,
                            ),
                            if (_filtered) ...[
                              const SizedBox(height: 16),
                              FilledButton.tonal(
                                onPressed: _reset,
                                style: FilledButton.styleFrom(
                                  backgroundColor: ActivitiesColors.primarySoft,
                                  foregroundColor: ActivitiesColors.primary,
                                ),
                                child: const Text('Đặt lại bộ lọc'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
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
                              _PlayArt(
                                groupId: group.id,
                                imageUrl: a.thumbnailUrl,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.name,
                                      style: _title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 13,
                                          color: ActivitiesColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(a.durationLabel, style: _secondary),
                                        const SizedBox(width: 6),
                                        const Text('·', style: _secondary),
                                        const SizedBox(width: 6),
                                        Text(a.ageLabel, style: _secondary),
                                      ],
                                    ),
                                    if (done.contains(a.id)) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ActivitiesColors.primarySoft,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 13,
                                              color: ActivitiesColors.primary,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Đã chơi',
                                              style: TextStyle(
                                                color: ActivitiesColors.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ActivitiesColors.background,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: ActivitiesColors.primary,
                                  size: 12,
                                ),
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
  padding: const EdgeInsets.only(bottom: 20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: _title.copyWith(fontSize: 15)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < labels.length; i++)
            ChoiceChip(
              showCheckmark: false,
              label: Text(labels[i]),
              selected: i == selected,
              selectedColor: ActivitiesColors.primarySoft,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: i == selected
                      ? ActivitiesColors.primary
                      : ActivitiesColors.border,
                  width: 1,
                ),
              ),
              labelStyle: TextStyle(
                color: i == selected
                    ? ActivitiesColors.primary
                    : ActivitiesColors.textPrimary,
                fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
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
  ActivityDetail? _detail;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.activity.remote) _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final detail = await ActivityApi.instance.fetchDetail(widget.activity.id);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Guide sections: backend detail for library activities, bundled text otherwise.
  List<(String, String)> get _guide =>
      _detail?.guide ?? activitySections(widget.activity);

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
            backgroundColor: ActivitiesColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              favorite
                  ? (store.favoriteActivities.contains(widget.activity.id)
                      ? 'Đã thêm vào yêu thích'
                      : 'Đã bỏ yêu thích')
                  : (store.completedActivities(widget.childId).contains(widget.activity.id)
                      ? 'Đã ghi nhận hoàn thành cùng bé'
                      : 'Đã hủy đánh dấu hoàn thành'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Chưa lưu được thay đổi. Vui lòng thử lại.'),
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
        backgroundColor: ActivitiesColors.background,
        appBar: AppBar(
          backgroundColor: ActivitiesColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Chi tiết hoạt động', style: _heading),
          actions: [
            IconButton.filledTonal(
              tooltip: favorite ? 'Bỏ yêu thích' : 'Lưu yêu thích',
              style: IconButton.styleFrom(
                backgroundColor: favorite
                    ? ActivitiesColors.primarySoft
                    : Colors.white,
              ),
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
                  color: favorite ? Colors.red.shade400 : ActivitiesColors.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Hero card
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'activity-art-${a.id}',
                    child: a.thumbnailUrl == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: _PlayArt(groupId: group.id, large: true),
                            ),
                          )
                        : _Photo(a.thumbnailUrl!, groupId: group.id),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    a.name,
                    style: _heading.copyWith(fontSize: 22, height: 1.25),
                  ),
                  const SizedBox(height: 12),
                  // Attributes row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        icon: Icons.child_care_rounded,
                        label: a.ageLabel,
                        color: ActivitiesColors.textSecondary,
                        bgColor: ActivitiesColors.background,
                      ),
                      _MetaPill(
                        icon: Icons.schedule_rounded,
                        label: a.durationLabel,
                        color: ActivitiesColors.textSecondary,
                        bgColor: ActivitiesColors.background,
                      ),
                      _MetaPill(
                        icon: group.icon,
                        label: group.name,
                        color: ActivitiesColors.primary,
                        bgColor: ActivitiesColors.primarySoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status highlight banner
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    child: Container(
                      key: ValueKey(done),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: done
                            ? ActivitiesColors.primarySoft
                            : ActivitiesColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: done
                              ? ActivitiesColors.primary.withValues(alpha: 0.3)
                              : ActivitiesColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            done
                                ? Icons.verified_rounded
                                : Icons.auto_awesome_rounded,
                            color: ActivitiesColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              done
                                  ? 'Bé đã hoàn thành hoạt động này'
                                  : 'Sẵn sàng cùng bé khám phá và học hỏi',
                              style: const TextStyle(
                                color: ActivitiesColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Remote guide loader
            if (a.remote && _detail == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _loadFailed
                    ? _Card(
                        child: Column(
                          children: [
                            const Text(
                              'Chưa tải được hướng dẫn chi tiết từ máy chủ.',
                              textAlign: TextAlign.center,
                              style: _secondary,
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: _load,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: ActivitiesColors.primary,
                          ),
                        ),
                      ),
              ),

            // Content sections
            if (_detail != null) ...[
              if (_detail!.goal != null)
                _GoalCard(goal: _detail!.goal!),
              if (_detail!.materialItems.isNotEmpty)
                _MaterialsCard(items: _detail!.materialItems),
              for (final section in _detail!.sections)
                _GuideCard(section.$1, section.$2),
              if (_detail!.steps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.format_list_numbered_rounded,
                              color: ActivitiesColors.primary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text('Các bước thực hiện', style: _title),
                          ],
                        ),
                        const SizedBox(height: 14),
                        for (final step in _detail!.steps) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: ActivitiesColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${step.number}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  step.instruction,
                                  style: _body,
                                ),
                              ),
                            ],
                          ),
                          if (step.imageUrl != null) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(left: 38),
                              child: _Photo(step.imageUrl!, groupId: group.id),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              if (_detail!.lyrics != null)
                _LyricsCard(lyrics: _detail!.lyrics!),
            ],
            if (!a.remote)
              for (final section in activitySections(a))
                if (section.$1 == 'Mục tiêu')
                  _GoalCard(goal: section.$2)
                else
                  _GuideCard(section.$1, section.$2),
          ],
        ),

        // Thumb-friendly sticky bottom action bar
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: ActivitiesColors.border.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: ActivitiesColors.primaryDark.withValues(alpha: .06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ActivitiesColors.primaryDark,
                        side: const BorderSide(
                          color: ActivitiesColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed:
                          store.childById(widget.childId) == null ||
                              !store.canEditChild(widget.childId, 'diary')
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ActivityJournalScreen(
                                  childId: widget.childId,
                                  activity: a,
                                  guide: _guide,
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text(
                        'Nhật ký',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: done
                            ? ActivitiesColors.primaryDark
                            : ActivitiesColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size(0, 52),
                        elevation: 1,
                      ),
                      onPressed:
                          _saving ||
                              store.childById(widget.childId) == null ||
                              !store.canEditChild(widget.childId, 'activities')
                          ? null
                          : () => _save(false),
                      icon: Icon(
                        done
                            ? Icons.replay_rounded
                            : Icons.check_circle_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _saving
                            ? 'Đang lưu…'
                            : store.childById(widget.childId) != null &&
                                  !store.canEditChild(widget.childId, 'activities')
                            ? 'Chỉ có quyền xem'
                            : done
                            ? 'Bỏ đánh dấu'
                            : 'Đánh dấu đã chơi',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

List<(String, String)> activitySections(ChildActivity a) {
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

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final String goal;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      decoration: BoxDecoration(
        color: ActivitiesColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ActivitiesColors.primary.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.track_changes_rounded,
                color: ActivitiesColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Mục tiêu hoạt động',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ActivitiesColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(goal, style: _body),
        ],
      ),
    ),
  );
}

class _MaterialsCard extends StatelessWidget {
  const _MaterialsCard({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: ActivitiesColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text('Cần chuẩn bị', style: _title),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: ActivitiesColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item, style: _body)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _LyricsCard extends StatelessWidget {
  const _LyricsCard({required this.lyrics});
  final String lyrics;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADBBE)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: Color(0xFF9E651D),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Lời bài hát / Thơ ca',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9E651D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lyrics,
            style: _body.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.7,
              color: const Color(0xFF3B2F23),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard(this.title, this.body);
  final String title, body;

  IconData _iconFor(String title) {
    if (title.contains('Lưu ý') || title.contains('an toàn')) {
      return Icons.shield_outlined;
    }
    if (title.contains('Chuẩn bị')) {
      return Icons.inventory_2_outlined;
    }
    if (title.contains('Hỏi') || title.contains('kể')) {
      return Icons.chat_outlined;
    }
    return Icons.lightbulb_outline_rounded;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconFor(title),
                color: ActivitiesColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(title, style: _title),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: _body),
        ],
      ),
    ),
  );
}

/// Photo from the backend (`/static/...`); falls back to the group artwork offline.
class _Photo extends StatelessWidget {
  const _Photo(this.path, {required this.groupId});
  final String path, groupId;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.network(
        ActivityApi.instance.imageUrl(path),
        fit: BoxFit.cover,
        semanticLabel: 'Ảnh minh họa hoạt động',
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                color: ActivitiesColors.primarySoft,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: ActivitiesColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
        errorBuilder: (_, _, _) =>
            Center(child: _PlayArt(groupId: groupId, large: true)),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: ActivitiesColors.border.withValues(alpha: 0.7),
        width: 1.2,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}
