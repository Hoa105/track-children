import '../journal/journal_screen.dart';
import '../notifications/notifications_screen.dart';
import '../activities/activities_screen.dart';
import '../explore/explore_screen.dart';
import '../../services/demo_store.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import 'background/home_background_repository.dart';
import 'home_profile_header.dart';
import 'background/photobooth_entry_screen.dart';
import 'background/home_background_section.dart';
import '../navigation/app_bottom_navigation_bar.dart';
import '../settings/settings_screen.dart';
import '../child/child_profile_screen.dart';
import '../growth/growth_screen.dart';
import '../assessment/assessment_home_card.dart';
import '../teething/teething_screen.dart';
import '../vaccination/vaccination_screen.dart';
import '../feeding/milk_calculator_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.childName,
    this.onLogout,
    this.backgroundRepository = const HomeBackgroundRepository(),
    this.onChangeBackground,
    this.photobooth,
    super.key,
  });

  final String childName;
  final VoidCallback? onLogout;
  final HomeBackgroundRepository backgroundRepository;
  final HomeBackgroundChooser? onChangeBackground;
  final PhotoboothHomeLauncher? photobooth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with DemoStoreBinding {
  final _scrollController = ScrollController();
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static const _shortcuts = <_Shortcut>[
    _Shortcut('Lượng sữa', 'Chưa có dữ liệu', 'milk_bottle.png'),
    _Shortcut('Tiêm chủng', 'Chưa có dữ liệu', 'vaccination_syringe.png'),
    _Shortcut('Mọc răng', 'Chưa có dữ liệu', 'tooth.png'),
    _Shortcut('Hoạt động', 'Chưa có dữ liệu', 'activity_blocks.png'),
    _Shortcut('Nhật ký', 'Chưa có dữ liệu', 'diary_book.png'),
  ];

  Future<void> _openLatestJournal() async {
    final store = DemoStore.instance;
    final child = store.child;
    if (child == null) {
      await _showOverview('Nhật ký');
      return;
    }
    final childId = child['id'] as String;
    final entries = store.journalEntries(childId);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => entries.isEmpty
            ? JournalScreen(childId: childId)
            : JournalEditorScreen(childId: childId, entry: entries.first),
      ),
    );
  }

  Future<void> _showOverview(String label) async {
    final child = DemoStore.instance.child;
    if (label == 'Thông báo') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return;
    }
    if (label == 'Nhật ký' && child != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => JournalScreen(childId: child['id'] as String),
        ),
      );
      return;
    }
    if (label == 'Lượng sữa' && child != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MilkCalculatorScreen(childId: child['id'] as String),
        ),
      );
      return;
    }
    if (label == 'Tiêm chủng' && child != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => VaccinationScreen(childId: child['id'] as String),
        ),
      );
      return;
    }
    if (label == 'Hoạt động' && child != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ActivitiesScreen(childId: child['id'] as String),
        ),
      );
      return;
    }
    if (label == 'Mọc răng' && child != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TeethingScreen(childId: child['id'] as String),
        ),
      );
      return;
    }
    final care = child?['care'] as Map?;
    final journal = child?['journal'] as Map?;
    final message = switch (label) {
      'Thông báo' => 'Chưa có thông báo. Nhắc lịch tự động chưa được kết nối.',
      'Nhật ký' =>
        journal == null
            ? 'Chưa có nhật ký cho bé.'
            : '${journal['title'] ?? 'Nhật ký'}\n${journal['date']?.toString().split('T').first ?? ''} · ${journal['category'] ?? ''}',
      'Hành trình lớn khôn' =>
        child == null
            ? 'Chọn hồ sơ bé để xem giai đoạn hiện tại.'
            : 'Bé đang ở giai đoạn ${DemoStore.instance.ageLabel(child)}.',
      _ => care?[label]?.toString() ?? 'Chưa có dữ liệu cho bé.',
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(message),
                      const SizedBox(height: 16),
                      if (label != 'Thông báo')
                        const Text(
                          'Thông tin tổng quan. Tính năng ghi chép và chi tiết mục này chưa khả dụng.',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMeasurement() async {
    await openMeasurementFromHome(
      context,
      childName:
          DemoStore.instance.child?['full_name'] as String? ?? widget.childName,
    );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          onLogout: widget.onLogout,
          childName:
              DemoStore.instance.child?['full_name'] as String? ??
              widget.childName,
        ),
      ),
    );
  }

  void _openGrowth({int metric = 0}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GrowthScreen(
          initialMetric: metric,
          childName:
              DemoStore.instance.child?['full_name'] as String? ??
              widget.childName,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = DemoStore.instance.child;
    final currentName = active?['full_name'] as String? ?? widget.childName;
    final name = currentName.trim().isEmpty ? 'Bé An' : currentName.trim();
    final store = DemoStore.instance;
    final accountId = store.signedIn ? store.parent['id'] as String? : null;
    final childId = active?['id'] as String?;
    final role = accountId == null
        ? null
        : (store.parent['defaultRelationship'] ??
                  store.parent['relationship'] ??
                  store.parent['role'])
              as String?;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    key: const ValueKey('home-hero'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HomeBackgroundSection(
                        header: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: HomeProfileHeader(
                              name: name,
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => ChildProfileScreen(
                                    initialFields:
                                        active ?? {'full_name': name},
                                    onSave: active == null
                                        ? null
                                        : (fields, avatar) => store
                                              .saveChild(
                                                active['id'] as String,
                                                fields,
                                              )
                                              .then((_) {}),
                                  ),
                                ),
                              ),
                              onSettingsTap: _openSettings,
                              onNotificationsTap: () =>
                                  _showOverview('Thông báo'),
                            ),
                          ),
                        ),
                        key: ValueKey((
                          accountId,
                          childId,
                          widget.backgroundRepository,
                        )),
                        accountId: accountId,
                        childId: childId,
                        role: role,
                        childGender: active?['gender'] as String?,
                        repository: widget.backgroundRepository,
                        profileChanges: store,
                        photobooth: widget.photobooth,
                        onChangeBackground: widget.onChangeBackground,
                        isCurrentProfile: () =>
                            store.signedIn &&
                            store.parent['id'] == accountId &&
                            store.child?['id'] == childId,
                      ),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -AppLayout.homeHeroOverlap),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _CareCard(onTap: _showOverview),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.list(
                children: [
                  if (active != null) ...[
                    AssessmentHomeCard(childId: active['id'] as String),
                    const SizedBox(height: 16),
                  ],
                  _GrowthCards(onTap: (metric) => _openGrowth(metric: metric)),
                  const SizedBox(height: 16),
                  _TimelineCard(
                    onTap: () => _showOverview('Hành trình lớn khôn'),
                  ),
                  const SizedBox(height: 16),
                  _JournalCard(onTap: _openLatestJournal),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        onTap: (label) {
          if (label == 'Cá nhân') {
            _openSettings();
          } else if (label == 'Theo dõi') {
            _openGrowth();
          } else if (label == 'Tạo ghi chép') {
            _openMeasurement();
          } else if (label == 'Khám phá') {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ExploreScreen(onLogout: widget.onLogout),
              ),
            );
          } else if (label == 'Trang chủ') {
            if (MediaQuery.disableAnimationsOf(context)) {
              _scrollController.jumpTo(0);
              return;
            }
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        },
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut(this.label, this.status, this.iconAsset);
  final String label, status, iconAsset;

  Color get accentColor => switch (iconAsset) {
    'milk_bottle.png' => const Color(0xFF62B5D9),
    'vaccination_syringe.png' => const Color(0xFFF08095),
    'tooth.png' => const Color(0xFF7CA9E8),
    'activity_blocks.png' => const Color(0xFF96B95D),
    'diary_book.png' => const Color(0xFFAB83DE),
    _ => AppColors.primary,
  };
}

class _CareCard extends StatelessWidget {
  const _CareCard({required this.onTap});
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('home-care-card'),
    padding: const EdgeInsets.all(AppLayout.pagePadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D194C3C),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppLayout.minimumTouchTarget,
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Hôm nay bé cần gì?',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF183257),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppLayout.mediumGap),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: AppLayout.mediumGap,
          runSpacing: AppLayout.mediumGap,
          children: [
            for (final item in _HomeScreenState._shortcuts)
              _CareItem(
                item: _Shortcut(
                  item.label,
                  item.label == 'Lượng sữa'
                      ? 'Ước tính theo cân nặng'
                      : item.label == 'Tiêm chủng' &&
                            DemoStore.instance.child != null
                      ? 'Đã tiêm ${DemoStore.instance.vaccinations(DemoStore.instance.child!['id'] as String).where((r) => r['given'] == true).length} mũi'
                      : item.label == 'Mọc răng' &&
                            DemoStore.instance.child != null
                      ? 'Đã mọc ${DemoStore.instance.teeth(DemoStore.instance.child!['id'] as String).length}/20 răng'
                      : item.label == 'Hoạt động' &&
                            DemoStore.instance.child != null
                      ? 'Đã thực hiện ${DemoStore.instance.completedActivities(DemoStore.instance.child!['id'] as String).length} hoạt động'
                      : (DemoStore.instance.child?['care'] as Map?)?[item.label]
                                as String? ??
                            item.status,
                  item.iconAsset,
                ),
                onTap: () => onTap(item.label),
              ),
          ],
        ),
      ],
    ),
  );
}

class _CareItem extends StatelessWidget {
  const _CareItem({required this.item, required this.onTap});
  final _Shortcut item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppLayout.homeCareIconSize + AppLayout.smallGap * 2,
    child: Semantics(
      label: item.label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Color.lerp(Colors.white, item.accentColor, .2),
              borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
                splashColor: item.accentColor.withValues(alpha: .14),
                highlightColor: item.accentColor.withValues(alpha: .08),
                hoverColor: item.accentColor.withValues(alpha: .08),
                child: Padding(
                  padding: const EdgeInsets.all(AppLayout.smallGap),
                  child: Image.asset(
                    'assets/images/scenery/icons/care/${item.iconAsset}',
                    width: AppLayout.homeCareIconSize * .8,
                    height: AppLayout.homeCareIconSize * .8,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GrowthCards extends StatelessWidget {
  const _GrowthCards({required this.onTap});
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final store = DemoStore.instance;
      final child = store.child;
      String value(int metric) {
        final measurement = child == null
            ? null
            : store.latest(child['id'] as String, metric);
        return measurement == null
            ? 'Chưa có số đo'
            : '${measurement.toStringAsFixed(1)} ${metric == 0 ? 'kg' : 'cm'}';
      }

      String change(int metric) {
        if (child == null) return 'Chưa có số đo';
        final records = store
            .records(child['id'] as String)
            .where((r) => r['v$metric'] != null)
            .toList();
        if (records.isEmpty) return 'Chưa có số đo';
        if (records.length < 2) return 'Số đo đầu tiên';
        final delta =
            (records.last['v$metric'] as num) -
            (records[records.length - 2]['v$metric'] as num);
        return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${metric == 0 ? 'kg' : 'cm'}';
      }

      List<double> trend(int metric, List<double> fallback) {
        if (child == null) return fallback;
        final values = store
            .records(child['id'] as String)
            .where((r) => r['v$metric'] != null)
            .map((r) => (r['v$metric'] as num).toDouble())
            .toList();
        if (values.isEmpty) return [];
        final lo = values.reduce((a, b) => a < b ? a : b),
            hi = values.reduce((a, b) => a > b ? a : b);
        return values
            .map((v) => hi == lo ? .5 : .15 + (v - lo) / (hi - lo) * .7)
            .toList();
      }

      final cards = [
        _MetricCard(
          iconAsset: 'assets/images/scenery/icons/ui/bamboo_segment-solid.svg',
          onTap: () => onTap(0),
          label: 'Cân nặng',
          value: value(0),
          change: change(0),
          trend: trend(0, []),
        ),
        _MetricCard(
          iconAsset: 'assets/images/scenery/icons/ui/ruler-solid.svg',
          onTap: () => onTap(1),
          label: 'Chiều cao',
          value: value(1),
          change: change(1),
          trend: trend(1, []),
        ),
      ];
      final stacked =
          constraints.maxWidth < 328 ||
          MediaQuery.textScalerOf(context).scale(20) > 28;
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cards[0],
            const SizedBox(height: AppLayout.mediumGap),
            cards[1],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 10),
          Expanded(child: cards[1]),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.change,
    required this.trend,
    required this.onTap,
  });
  final String iconAsset;
  final String label, value, change;
  final List<double> trend;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    elevation: 1,
    shadowColor: const Color(0x18194C3C),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 126),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primarySoft,
                  child: iconAsset.endsWith('.svg')
                      ? SvgPicture.asset(iconAsset, width: 24, height: 24)
                      : Image.asset(iconAsset, width: 24, height: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF183257),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppLayout.smallGap,
              runSpacing: AppLayout.smallGap,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4E4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    change,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 58,
                  height: 30,
                  child: CustomPaint(painter: _SparkPainter(trend)),
                ),
              ],
            ),
            const Text(
              'so với lần đo trước',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final pt = Offset(
        values.length == 1 ? s.width / 2 : s.width * i / (values.length - 1),
        s.height * (1 - values[i]),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
      c.drawCircle(pt, 2.2, Paint()..color = AppColors.primary);
    }
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}

int get _currentAgeMilestoneIndex {
  final child = DemoStore.instance.child;
  if (child == null) return 0;
  final months = int.parse(DemoStore.instance.ageLabel(child).split(' ').first);
  return months < 4
      ? 0
      : months < 7
      ? 1
      : months < 10
      ? 2
      : months < 13
      ? 3
      : months < 48
      ? 4
      : 5;
}

class _TimelineCard extends StatefulWidget {
  const _TimelineCard({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_TimelineCard> createState() => _TimelineCardState();
}

class _TimelineCardState extends State<_TimelineCard> {
  final _milestoneScrollController = ScrollController();
  Object? _lastScrollTarget;

  @override
  void dispose() {
    _milestoneScrollController.dispose();
    super.dispose();
  }

  void _revealCurrentMilestone(double viewportWidth, double itemWidth) {
    final target = (
      DemoStore.instance.child?['id'],
      _currentAgeMilestoneIndex,
      viewportWidth,
      itemWidth,
    );
    if (target == _lastScrollTarget) return;
    final initial = _lastScrollTarget == null;
    _lastScrollTarget = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          target != _lastScrollTarget ||
          !_milestoneScrollController.hasClients) {
        return;
      }
      final position = _milestoneScrollController.position;
      final offset = (target.$2 * itemWidth + itemWidth / 2 - viewportWidth / 2)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (initial || MediaQuery.disableAnimationsOf(context)) {
        _milestoneScrollController.jumpTo(offset);
      } else {
        _milestoneScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  static const ages = [
    '0–3 tháng',
    '4–6 tháng',
    '7–9 tháng',
    '10–12 tháng',
    '1–3 tuổi',
    '4–5 tuổi',
  ];
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x09194C3C), blurRadius: 12)],
    ),
    child: Column(
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/images/scenery/icons/ui/bamboo_segment-solid.svg',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Hành trình lớn khôn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF183257),
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: widget.onTap,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text(
                  'Tổng quan  ›',
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppLayout.mediumGap),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = MediaQuery.textScalerOf(context)
                  .scale(72)
                  .clamp(72.0, 144.0)
                  .toDouble();
              _revealCurrentMilestone(constraints.maxWidth, itemWidth);
              return SingleChildScrollView(
                key: const ValueKey('home-milestones-scroll'),
                controller: _milestoneScrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < ages.length; i++)
                      SizedBox(
                        key: ValueKey('home-milestone-$i'),
                        width: itemWidth,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 8,
                              child: i == _currentAgeMilestoneIndex
                                  ? const Center(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: SizedBox.square(dimension: 6),
                                      ),
                                    )
                                  : null,
                            ),
                            Image.asset(
                              _ageMilestoneAssets[i][i ==
                                      _currentAgeMilestoneIndex
                                  ? 1
                                  : 0],
                              width: 58,
                              height: 72,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ages[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: i == _currentAgeMilestoneIndex
                                    ? AppColors.primaryDark
                                    : AppColors.textSecondary,
                                fontWeight: i == _currentAgeMilestoneIndex
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5E9),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/images/scenery/icons/ui/bamboo_segment-solid.svg',
                width: 23,
                height: 23,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  DemoStore.instance.child == null
                      ? 'Bé đang ở những tháng đầu đời. Ba mẹ cùng theo dõi từng bước phát triển nhé!'
                      : 'Bé đang ở giai đoạn ${DemoStore.instance.ageLabel(DemoStore.instance.child!)}. Cùng theo dõi từng bước phát triển nhé!',
                  style: TextStyle(fontSize: 12, color: Color(0xFF41584D)),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ],
    ),
  );
}

const _ageMilestoneAssets = <List<String>>[
  [
    'assets/images/scenery/icons/age_milestones/stage_01_0_3_months_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_01_0_3_months_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_02_4_6_months_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_02_4_6_months_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_03_7_9_months_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_03_7_9_months_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_04_10_12_months_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_04_10_12_months_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_05_1_3_years_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_05_1_3_years_active_simple_flat_bright.png',
  ],
  [
    'assets/images/scenery/icons/age_milestones/stage_06_4_5_years_inactive_simple_flat.png',
    'assets/images/scenery/icons/age_milestones/stage_06_4_5_years_active_simple_flat_bright.png',
  ],
];

class _JournalCard extends StatelessWidget {
  const _JournalCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x09194C3C), blurRadius: 12)],
    ),
    child: Column(
      children: [
        Row(
          children: [
            SvgPicture.asset(
              'assets/images/scenery/icons/ui/camera-solid.svg',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Nhật ký gần đây',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF183257),
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: onTap,
                child: const Text(
                  'Xem chi tiết  ›',
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9D8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  size: 34,
                  color: Color(0xFFD99170),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (DemoStore.instance.child?['journal'] as Map?)?['title']
                              as String? ??
                          'Chưa có nhật ký',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF183257),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      DemoStore.instance.child == null
                          ? 'Chọn hồ sơ để xem nhật ký'
                          : '${(DemoStore.instance.child?['journal'] as Map?)?['date']?.toString().split('T').first ?? '—'} · ${(DemoStore.instance.child?['journal'] as Map?)?['category'] ?? 'Nhật ký'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
            ],
          ),
        ),
      ],
    ),
  );
}
