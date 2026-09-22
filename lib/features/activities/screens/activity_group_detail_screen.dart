import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/activity.dart';
import '../../../models/activity_group.dart';
import '../../../services/service_locator.dart';

enum _StatusFilter { all, notDone, done }

enum _AgeFilter { all, m0_4, m4_8, m6_12, m10_15, m12_18, m15_20, m18_24 }

enum _DurationFilter { all, le5, from5to10, gt10 }

enum _SortOption { ageMatch, notDoneFirst, newest }

extension on _StatusFilter {
  String get label => switch (this) {
        _StatusFilter.all => 'Tất cả',
        _StatusFilter.notDone => 'Chưa làm',
        _StatusFilter.done => 'Đã hoàn thành',
      };
}

extension on _AgeFilter {
  String get label => switch (this) {
        _AgeFilter.all => 'Tất cả độ tuổi',
        _AgeFilter.m0_4 => '0–4 tháng',
        _AgeFilter.m4_8 => '4–8 tháng',
        _AgeFilter.m6_12 => '6–12 tháng',
        _AgeFilter.m10_15 => '10–15 tháng',
        _AgeFilter.m12_18 => '12–18 tháng',
        _AgeFilter.m15_20 => '15–20 tháng',
        _AgeFilter.m18_24 => '18–24 tháng',
      };

  (int, int)? get range => switch (this) {
        _AgeFilter.all => null,
        _AgeFilter.m0_4 => (0, 4),
        _AgeFilter.m4_8 => (4, 8),
        _AgeFilter.m6_12 => (6, 12),
        _AgeFilter.m10_15 => (10, 15),
        _AgeFilter.m12_18 => (12, 18),
        _AgeFilter.m15_20 => (15, 20),
        _AgeFilter.m18_24 => (18, 24),
      };
}

extension on _DurationFilter {
  String get label => switch (this) {
        _DurationFilter.all => 'Tất cả',
        _DurationFilter.le5 => '≤ 5 phút',
        _DurationFilter.from5to10 => '5–10 phút',
        _DurationFilter.gt10 => '> 10 phút',
      };
}

extension on _SortOption {
  String get label => switch (this) {
        _SortOption.ageMatch => 'Độ tuổi phù hợp',
        _SortOption.notDoneFirst => 'Chưa làm trước',
        _SortOption.newest => 'Mới nhất',
      };
}

(int, int)? _parseAgeRange(String label) {
  final match = RegExp(r'(\d+)\s*[–-]\s*(\d+)').firstMatch(label);
  if (match == null) return null;
  return (int.parse(match.group(1)!), int.parse(match.group(2)!));
}

int? _parseDurationMinutes(String label) {
  final match = RegExp(r'(\d+)\s*phút').firstMatch(label);
  if (match == null) return null;
  return int.parse(match.group(1)!);
}

class ActivityGroupDetailScreen extends StatefulWidget {
  const ActivityGroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<ActivityGroupDetailScreen> createState() => _ActivityGroupDetailScreenState();
}

class _ActivityGroupDetailScreenState extends State<ActivityGroupDetailScreen> {
  ActivityGroup? _group;

  _StatusFilter _status = _StatusFilter.all;
  _AgeFilter _age = _AgeFilter.all;
  _DurationFilter _duration = _DurationFilter.all;
  _SortOption _sort = _SortOption.ageMatch;

  @override
  void initState() {
    super.initState();
    ServiceLocator.activityService.getGroups().then((groups) {
      setState(() => _group = groups.firstWhere((g) => g.id == widget.groupId));
    });
  }

  bool get _hasActiveFilter =>
      _status != _StatusFilter.all || _age != _AgeFilter.all || _duration != _DurationFilter.all;

  List<Activity> _filteredItems(List<Activity> source) {
    var items = source.where((a) {
      if (_status == _StatusFilter.notDone && a.isDone) return false;
      if (_status == _StatusFilter.done && !a.isDone) return false;

      final ageBucket = _age.range;
      if (ageBucket != null) {
        final activityRange = _parseAgeRange(a.ageRangeLabel);
        if (activityRange == null) return false;
        final (aMin, aMax) = activityRange;
        final (bMin, bMax) = ageBucket;
        if (aMin > bMax || aMax < bMin) return false;
      }

      if (_duration != _DurationFilter.all) {
        final minutes = _parseDurationMinutes(a.durationLabel);
        if (minutes == null) return false;
        switch (_duration) {
          case _DurationFilter.le5:
            if (minutes > 5) return false;
          case _DurationFilter.from5to10:
            if (minutes < 5 || minutes > 10) return false;
          case _DurationFilter.gt10:
            if (minutes <= 10) return false;
          case _DurationFilter.all:
            break;
        }
      }
      return true;
    }).toList();

    switch (_sort) {
      case _SortOption.ageMatch:
        items.sort((a, b) {
          final ra = _parseAgeRange(a.ageRangeLabel);
          final rb = _parseAgeRange(b.ageRangeLabel);
          return (ra?.$1 ?? 0).compareTo(rb?.$1 ?? 0);
        });
      case _SortOption.notDoneFirst:
        items.sort((a, b) => (a.isDone ? 1 : 0).compareTo(b.isDone ? 1 : 0));
      case _SortOption.newest:
        items = items.reversed.toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    if (group == null) {
      return AppShellScaffold(
        tab: AppTab.activities,
        appBar: AppBar(title: const Text('Hoạt động trong nhóm')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final items = _filteredItems(group.items);

    return AppShellScaffold(
      tab: AppTab.activities,
      appBar: AppBar(title: Text(group.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('${items.length} hoạt động', style: AppTextStyles.caption),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_list_rounded, color: AppColors.textMuted),
                      tooltip: 'Bộ lọc',
                      onPressed: _openFilterSheet,
                    ),
                    if (_hasActiveFilter)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final activity = items[i];
                return CardContainer(
                  onTap: () => context.push('${AppRoutes.activityDetail}/${activity.id}'),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: group.tint, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Icon(
                          activity.isDone ? Icons.check_rounded : Icons.circle_outlined,
                          size: 16,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activity.name, style: AppTextStyles.body),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: [
                                _tag(activity.ageRangeLabel),
                                _tag(activity.durationLabel),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (activity.isDone)
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<
        (_StatusFilter, _AgeFilter, _DurationFilter, _SortOption)>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _FilterSheet(
        initialStatus: _status,
        initialAge: _age,
        initialDuration: _duration,
        initialSort: _sort,
      ),
    );
    if (result != null) {
      setState(() {
        _status = result.$1;
        _age = result.$2;
        _duration = result.$3;
        _sort = result.$4;
      });
    }
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: AppRadius.smallRadius),
      child: Text(text, style: AppTextStyles.caption),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initialStatus,
    required this.initialAge,
    required this.initialDuration,
    required this.initialSort,
  });

  final _StatusFilter initialStatus;
  final _AgeFilter initialAge;
  final _DurationFilter initialDuration;
  final _SortOption initialSort;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _StatusFilter _status = widget.initialStatus;
  late _AgeFilter _age = widget.initialAge;
  late _DurationFilter _duration = widget.initialDuration;
  late _SortOption _sort = widget.initialSort;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bộ lọc', style: AppTextStyles.h3),
                  TextButton(
                    onPressed: () => setState(() {
                      _status = _StatusFilter.all;
                      _age = _AgeFilter.all;
                      _duration = _DurationFilter.all;
                      _sort = _SortOption.ageMatch;
                    }),
                    child: const Text('Đặt lại'),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('Trạng thái'),
                      for (final v in _StatusFilter.values)
                        _radioTile(v.label, _status == v, () => setState(() => _status = v)),
                      const SizedBox(height: AppSpacing.md),
                      _section('Độ tuổi'),
                      for (final v in _AgeFilter.values)
                        _radioTile(v.label, _age == v, () => setState(() => _age = v)),
                      const SizedBox(height: AppSpacing.md),
                      _section('Thời gian thực hiện'),
                      for (final v in _DurationFilter.values)
                        _radioTile(v.label, _duration == v, () => setState(() => _duration = v)),
                      const SizedBox(height: AppSpacing.md),
                      _section('Sắp xếp'),
                      for (final v in _SortOption.values)
                        _radioTile(v.label, _sort == v, () => setState(() => _sort = v)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Áp dụng',
                onPressed: () => Navigator.pop(context, (_status, _age, _duration, _sort)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(title, style: AppTextStyles.titleMedium),
    );
  }

  Widget _radioTile(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}
