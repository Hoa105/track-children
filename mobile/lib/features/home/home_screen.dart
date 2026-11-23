import '../journal/journal_screen.dart';
import '../notifications/notifications_screen.dart';
import '../activities/activities_screen.dart';
import '../explore/explore_screen.dart';
import '../../services/demo_store.dart';
import '../../services/notification_inbox.dart';
import '../../services/push_notifications.dart';

import 'package:flutter/material.dart';

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
  void initState() {
    super.initState();
    NotificationInbox.instance.addListener(_inboxChanged);
    NotificationInbox.instance.refresh();
    PushNotifications.instance.sync();
  }

  void _inboxChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    NotificationInbox.instance.removeListener(_inboxChanged);
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
    final rawName = currentName.trim().isEmpty ? 'An' : currentName.trim();
    final name = rawName.toLowerCase().startsWith('bé ') ? rawName : 'Bé $rawName';
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
      backgroundColor: HomeColors.background,
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
                      RepaintBoundary(
                        child: HomeBackgroundSection(
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
                          repository: widget.backgroundRepository,
                          profileChanges: store,
                          photobooth: widget.photobooth,
                          onChangeBackground: widget.onChangeBackground,
                          isCurrentProfile: () =>
                              store.signedIn &&
                              store.parent['id'] == accountId &&
                              store.child?['id'] == childId,
                        ),
                      ),
                    ],
                  ),
                  RepaintBoundary(
                    child: Transform.translate(
                      offset: const Offset(0, -AppLayout.homeHeroOverlap),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _CareCard(childName: name, onTap: _showOverview),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
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
          } else if (label == 'Tạo ghi chép' || label == 'Thêm nhật ký') {
            openAddJournal(context);
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
  const _CareCard({required this.childName, required this.onTap});
  final String childName;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('home-care-card'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HomeColors.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: _TimelineCard(
            key: ValueKey(DemoStore.instance.child?['id']),
          ),
        ),
        if (DemoStore.instance.child != null)
          AssessmentHomeCard(
            childId: DemoStore.instance.child!['id'] as String,
            reminderOnly: true,
          ),
        const SizedBox(height: 16),
        Text(
          'Hôm nay bé ${childName.replaceFirst(RegExp(r'^bé\s+', caseSensitive: false), '')} cần gì?',
          key: const ValueKey('home-care-title'),
          style: const TextStyle(
            fontSize: 18,
            color: HomeColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 18,
            children: [
              for (final item in _HomeScreenState._shortcuts)
                SizedBox(
                  width: (constraints.maxWidth - 24) / 3,
                  child: _CareItem(item: item, onTap: () => onTap(item.label)),
                ),
            ],
          ),
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
    width: double.infinity,
    child: Semantics(
      label: item.label,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
          splashColor: item.accentColor.withValues(alpha: .14),
          highlightColor: item.accentColor.withValues(alpha: .08),
          hoverColor: item.accentColor.withValues(alpha: .08),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: HomeColors.iconBackground,
                  borderRadius: BorderRadius.circular(AppLayout.homeCareRadius),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/images/scenery/icons/care/${item.iconAsset}',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
      : months < 12
      ? 3
      : months < 48
      ? 4
      : months < 60
      ? 5
      : 6;
}

class _TimelineCard extends StatefulWidget {
  const _TimelineCard({super.key});

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
      final offset =
          (_milestoneCenter(target.$2, itemWidth) - viewportWidth / 2)
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

  // Visible widths on the shared 512 px canvas; keep the original image scale.
  static const _iconWidths = [120.0, 178.0, 202.0, 216.0, 238.0, 278.0, 312.0];

  double _milestoneWidth(int index, double itemWidth) {
    final average = _iconWidths.reduce((a, b) => a + b) / _iconWidths.length;
    return itemWidth + (_iconWidths[index] - average) * 72 / 512;
  }

  double _milestoneCenter(int index, double itemWidth) {
    var left = 0.0;
    for (var i = 0; i < index; i++) {
      left += _milestoneWidth(i, itemWidth);
    }
    return left + _milestoneWidth(index, itemWidth) / 2;
  }

  double _totalMilestonesWidth(double itemWidth) {
    var total = 0.0;
    for (var i = 0; i < ages.length; i++) {
      total += _milestoneWidth(i, itemWidth);
    }
    return total;
  }

  static const ages = [
    '0–3 th',
    '4–6 th',
    '7–9 th',
    '10–11 th',
    '1–3 tuổi',
    '4–5 tuổi',
    '5–6 tuổi',
  ];
  @override
  Widget build(BuildContext context) => Padding(
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
          child: SizedBox(
            width: _totalMilestonesWidth(itemWidth),
            child: Stack(
              children: [
                for (var i = 0; i < ages.length - 1; i++)
                  Positioned(
                    left: _milestoneCenter(i, itemWidth),
                    top: 62,
                    width: _milestoneCenter(i + 1, itemWidth) -
                        _milestoneCenter(i, itemWidth),
                    height: 24,
                    child: Image.asset(
                      'assets/images/scenery/icons/age-milestones/timeline/'
                      'connector_${i.isEven ? 'up' : 'down'}_inactive.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < ages.length; i++)
                      SizedBox(
                        key: ValueKey('home-milestone-$i'),
                        width: _milestoneWidth(i, itemWidth),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 8,
                              child: i == _currentAgeMilestoneIndex
                                  ? const Center(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: HomeColors.milestoneAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: SizedBox.square(dimension: 6),
                                      ),
                                    )
                                  : null,
                            ),
                            SizedBox(
                              height: 72,
                              child: OverflowBox(
                                minWidth: 72,
                                maxWidth: 72,
                                child: Image.asset(
                                  _ageMilestoneAssets[i][i ==
                                          _currentAgeMilestoneIndex
                                      ? 1
                                      : 0],
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ages[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: i == _currentAgeMilestoneIndex
                                    ? HomeColors.ink
                                    : HomeColors.primary,
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
              ],
            ),
          ),
        );
      },
    ),
  );
}

const _ageMilestoneAssets = <List<String>>[
  [
    'assets/images/scenery/icons/age-milestones/inactive/stage_01_0_3_months_inactive.png',
    'assets/images/scenery/icons/age-milestones/active/stage_01_0_3_months_active.png',
  ],
  [
    'assets/images/scenery/icons/age-milestones/inactive/stage_02_4_6_months_inactive.png',
    'assets/images/scenery/icons/age-milestones/active/stage_02_4_6_months_active.png',
  ],
  [
    'assets/images/scenery/icons/age-milestones/inactive/stage_03_7_9_months_inactive.png',
    'assets/images/scenery/icons/age-milestones/active/stage_03_7_9_months_active.png',
  ],
  [
    'assets/images/scenery/icons/age-milestones/inactive/stage_04_10_11_months_inactive.png',
    'assets/images/scenery/icons/age-milestones/active/stage_04_10_11_months_active.png',
  ],
  [
    'assets/images/scenery/icons/age-milestones/inactive/stage_05_1_3_years_inactive.png',
    'assets/images/scenery/icons/age-milestones/active/stage_05_1_3_years_active.png',
  ],
  [
    'assets/images/scenery/icons/age-milestones/inactive/stage_06_4_5_years_inactive.png',
    'assets/images/scenery/icons/age-milestones/active/stage_06_4_5_years_active.png',
  ],
  [
    'assets/images/scenery/icons/age-milestones/inactive/stage_07_5_6_years_inactive.png',
    'assets/images/scenery/icons/age-milestones/active/stage_07_5_6_years_active.png',
  ],
];
