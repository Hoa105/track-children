import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/vaccination.dart';
import 'vaccination_style.dart';

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

class VaccinationHistory extends StatefulWidget {
  const VaccinationHistory({
    super.key,
    required this.childId,
    required this.records,
    required this.onSelect,
  });
  final String childId;
  final List<ScheduledVaccine> records;
  final ValueChanged<ScheduledVaccine> onSelect;

  @override
  State<VaccinationHistory> createState() => _VaccinationHistoryState();
}

class _VaccinationHistoryState extends State<VaccinationHistory> {
  String? _vaccine;
  int? _year;
  bool _oldest = false;

  void _clear() => setState(() {
    _vaccine = null;
    _year = null;
  });

  Future<T?> _chooseFilter<T>(
    String title,
    List<(T, String)> options,
    T selected,
  ) => showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .65,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng bộ lọc',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final (value, label) = options[index];
                  final active = value == selected;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: active ? AppColors.primarySoft : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        selected: active,
                        selectedColor: AppColors.primary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            color: active
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: Icon(
                          active
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: active
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        onTap: () => Navigator.pop(context, value),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final years =
        widget.records.map((v) => v.record!.date.year).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
    final selectedYear = years.contains(_year) ? _year : null;
    final names = widget.records.map((v) => v.dose.name).toSet().toList()
      ..sort();
    final selectedVaccine = names.contains(_vaccine) ? _vaccine : null;
    final visible =
        widget.records
            .where(
              (v) =>
                  (selectedYear == null ||
                      v.record!.date.year == selectedYear) &&
                  (selectedVaccine == null || v.dose.name == selectedVaccine),
            )
            .toList()
          ..sort(
            (a, b) => _oldest
                ? a.record!.date.compareTo(b.record!.date)
                : b.record!.date.compareTo(a.record!.date),
          );
    final visits = <String, List<ScheduledVaccine>>{};
    for (final v in visible) {
      final r = v.record!;
      final key = '${_date(r.date)}|${r.place.trim().toLowerCase()}';
      visits.putIfAbsent(key, () => []).add(v);
    }
    final entries = visits.entries.toList();
    final filtering = selectedVaccine != null || selectedYear != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 176),
                  child: _FilterButton(
                    tooltip: 'Lọc vắc-xin',
                    label: selectedVaccine ?? 'Vắc-xin',
                    icon: Icons.vaccines_outlined,
                    active: selectedVaccine != null,
                    onPressed: () async {
                      final value = await _chooseFilter<String>('Lọc vắc-xin', [
                        ('', 'Tất cả vắc-xin'),
                        for (final name in names) (name, name),
                      ], selectedVaccine ?? '');
                      if (value != null && mounted) {
                        setState(() => _vaccine = value.isEmpty ? null : value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FilterButton(
                tooltip: 'Lọc năm tiêm',
                label: selectedYear == null ? 'Năm' : '$selectedYear',
                active: selectedYear != null,
                onPressed: () async {
                  final value = await _chooseFilter<int>('Lọc năm tiêm', [
                    (0, 'Tất cả năm'),
                    for (final year in years) (year, '$year'),
                  ], selectedYear ?? 0);
                  if (value != null && mounted) {
                    setState(() => _year = value == 0 ? null : value);
                  }
                },
              ),
              IconButton(
                tooltip: _oldest ? 'Cũ nhất trước' : 'Mới nhất trước',
                onPressed: () => setState(() => _oldest = !_oldest),
                icon: Icon(
                  _oldest
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${visible.length} mũi · ${visits.length} buổi tiêm',
                  style: const TextStyle(
                    fontSize: 13,
                    color: VaccinationColors.recorded,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (filtering)
                TextButton(onPressed: _clear, child: const Text('Bỏ lọc')),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        filtering
                            ? Icons.search_off_rounded
                            : Icons.auto_stories_outlined,
                        size: 36,
                        color: VaccinationColors.recorded,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        filtering
                            ? 'Không tìm thấy mũi phù hợp'
                            : 'Chưa ghi nhận mũi tiêm',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (filtering)
                        TextButton(
                          onPressed: _clear,
                          child: const Text('Xóa bộ lọc'),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: PageStorageKey('vaccination-history-${widget.childId}'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final doses = entry.value;
                    final first = doses.first.record!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: VaccinationColors.recordedSoft,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          key: PageStorageKey(
                            'visit-${widget.childId}-${entry.key}-$selectedVaccine-$selectedYear-$_oldest',
                          ),
                          initiallyExpanded: filtering || index == 0,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            8,
                          ),
                          shape: const Border(),
                          collapsedShape: const Border(),
                          iconColor: VaccinationColors.recorded,
                          collapsedIconColor: VaccinationColors.recorded,
                          title: Text(
                            '${_date(first.date)} · ${doses.length} mũi',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          subtitle: Text(
                            first.place.isEmpty
                                ? 'Chưa ghi nơi tiêm'
                                : first.place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: VaccinationColors.ink,
                            ),
                          ),
                          children: [
                            for (final v in doses)
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                title: Text(
                                  v.dose.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${v.dose.doseLabel}${v.record!.reaction.isEmpty ? '' : '\nPhản ứng: ${v.record!.reaction}'}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: VaccinationColors.ink,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: VaccinationColors.recorded,
                                ),
                                onTap: () => widget.onSelect(v),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.tooltip,
    required this.label,
    required this.onPressed,
    required this.active,
    this.icon,
  });
  final String tooltip, label;
  final VoidCallback onPressed;
  final bool active;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: active ? AppColors.primarySoft : AppColors.surface,
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    ),
  );
}
