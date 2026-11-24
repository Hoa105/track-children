
import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/vaccination.dart';
import '../../services/demo_store.dart';
import '../sharing/access_gate.dart';
import '../../services/vaccination_schedule.dart';
import 'vaccination_widgets.dart';
import 'vaccination_details.dart';
import 'vaccination_history.dart';
import 'supplement_vaccine_editor.dart';
import 'vaccine_appointment_sheet.dart';
import 'vaccination_style.dart' show VaccinationTheme;

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

List<ScheduledVaccine> vaccinationSchedule(String childId) {
  final store = DemoStore.instance;
  final child = store.childById(childId);
  if (child == null) return [];
  return buildVaccinationSchedule(
    childId: childId,
    dob: DateTime.parse(child['date_of_birth'] as String),
    entries: store.vaccinations(childId),
    plans: store.vaccinePlans(childId),
    today: _today,
  );
}

/// Age of the child in the same units as [VaccineDose.ageKey] (≈ days, months × 30).
int _childAgeKey(DateTime dob) {
  final months = VaccineDose.monthsBetween(dob, _today);
  final anniversary = DateTime(dob.year, dob.month + months, dob.day);
  return months * 30 + _today.difference(anniversary).inDays.clamp(0, 29);
}

class VaccinationScreen extends StatefulWidget {
  const VaccinationScreen({super.key, required this.childId});
  final String childId;
  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationMemo {
  _VaccinationMemo({
    required this.key,
    required this.schedule,
    required this.records,
    required this.appointments,
    required this.reference,
    required this.due,
    required this.done,
    required this.missing,
    required this.families,
    required this.supplements,
    required this.active,
    required this.ageGroups,
    required this.sortedGroups,
    required this.ages,
    required this.dob,
    required this.childAge,
    required this.childAgeKey,
    required this.priority,
  });

  final Object key;
  final List<ScheduledVaccine> schedule;
  final List<ScheduledVaccine> records;
  final List<ScheduledVaccine> appointments;
  final List<ScheduledVaccine> reference;
  final List<ScheduledVaccine> due;
  final int done;
  final List<ScheduledVaccine> missing;
  final Map<String, List<ScheduledVaccine>> families;
  final Map<String, List<ScheduledVaccine>> supplements;
  final List<List<ScheduledVaccine>> active;
  final Map<int, List<ScheduledVaccine>> ageGroups;
  final Map<int, List<ScheduledVaccine>> sortedGroups;
  final List<int> ages;
  final DateTime dob;
  final int childAge;
  final int childAgeKey;
  final ScheduledVaccine? priority;
}

class _VaccinationScreenState extends State<VaccinationScreen>
    with DemoStoreBinding {
  String get _childId => widget.childId;
  int _view = 0;
  int? _selectedAge;
  _VaccinationMemo? _memo;

  _VaccinationMemo _computeMemo(Map<String, dynamic> child) {
    final today = _today;
    final key = (
      _childId,
      DemoStore.instance.revision,
      today,
      vaccineCatalog,
      child['date_of_birth'],
    );
    final cached = _memo;
    if (cached != null && cached.key == key) return cached;

    final schedule = vaccinationSchedule(_childId);
    final records = schedule.where((v) => v.record != null).toList()
      ..sort((a, b) => b.record!.date.compareTo(a.record!.date));
    final appointments = schedule.where((v) => v.hasAppointment).toList();
    final reference = schedule.where((v) => !v.dose.isCustom).toList();
    final due = reference.where((v) => !v.dueDate.isAfter(today)).toList();
    final done = due.where((v) => v.record != null).length;
    final missing = due.where((v) => v.record == null).toList();
    final families = <String, List<ScheduledVaccine>>{};
    for (final v in reference) {
      families.putIfAbsent(v.dose.name, () => []).add(v);
    }
    final supplements = <String, List<ScheduledVaccine>>{};
    for (final v in schedule.where((v) => v.dose.isCustom)) {
      supplements.putIfAbsent(v.dose.groupId ?? v.dose.id, () => []).add(v);
    }
    final pendingWithNextDue = <(List<ScheduledVaccine>, DateTime)>[];
    final completed = <List<ScheduledVaccine>>[];
    for (final group in families.values) {
      ScheduledVaccine? firstUnrecorded;
      for (final v in group) {
        if (v.record == null) {
          firstUnrecorded = v;
          break;
        }
      }
      if (firstUnrecorded != null) {
        pendingWithNextDue.add((group, firstUnrecorded.dueDate));
      } else {
        completed.add(group);
      }
    }
    pendingWithNextDue.sort((a, b) => a.$2.compareTo(b.$2));
    final active = <List<ScheduledVaccine>>[
      for (final item in pendingWithNextDue) item.$1,
      ...completed,
    ];
    final ageGroups = <int, List<ScheduledVaccine>>{};
    for (final v in reference) {
      ageGroups.putIfAbsent(v.dose.ageKey, () => []).add(v);
    }
    final sortedGroups = Map.fromEntries(
      ageGroups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final ages = sortedGroups.keys.toList();
    final dob = DateTime.parse(child['date_of_birth'] as String);
    final childAge = VaccineDose.monthsBetween(dob, today);
    final childAgeKey = _childAgeKey(dob);
    final future = reference
        .where((v) => v.record == null && v.dueDate.isAfter(today))
        .firstOrNull;
    final priority = appointments.firstOrNull ?? future;

    final next = _VaccinationMemo(
      key: key,
      schedule: schedule,
      records: records,
      appointments: appointments,
      reference: reference,
      due: due,
      done: done,
      missing: missing,
      families: families,
      supplements: supplements,
      active: active,
      ageGroups: ageGroups,
      sortedGroups: sortedGroups,
      ages: ages,
      dob: dob,
      childAge: childAge,
      childAgeKey: childAgeKey,
      priority: priority,
    );
    _memo = next;
    return next;
  }

  @override
  void initState() {
    super.initState();
    // Lấy sổ tiêm mới nhất từ backend (người chăm sóc khác có thể đã cập nhật).
    DemoStore.instance.syncVaccinations(_childId);
  }

  Future<void> _details(ScheduledVaccine v) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: VaccinationColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => VaccineDetailSheet(
        vaccine: v,
        readOnly: !DemoStore.instance.canEditChild(_childId, 'vaccination'),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'appointment') {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: VaccinationColors.background,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (context) =>
            VaccineAppointmentSheet(childId: _childId, vaccine: v),
      );
      return;
    }
    await _open(vaccine: v, markGiven: action == 'mark');
  }

  Future<void> _open({
    ScheduledVaccine? vaccine,
    bool given = true,
    bool markGiven = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: VaccinationColors.background,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height * .88 -
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: VaccineEditorScreen(
            childId: _childId,
            vaccine: vaccine,
            initiallyGiven: given,
            markAsGiven: markGiven,
          ),
        ),
      ),
    );
  }

  Future<void> _add() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: VaccinationColors.background,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: constraints.maxHeight,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SupplementVaccineEditor(childId: _childId),
        ),
      ),
    ),
  );

  Widget _dose(ScheduledVaccine v, {bool showDivider = true}) => _DoseEntry(
    key: ValueKey('$_childId-${v.dose.id}-${v.record != null}'),
    vaccine: v,
    onTap: () => _details(v),
    showDivider: showDivider,
  );

  Future<void> _pickAge(
    Map<int, List<ScheduledVaccine>> groups,
    int selected,
  ) async {
    final age = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: VaccinationColors.background,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => FractionallySizedBox(
        heightFactor: .75,
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Các mốc tiêm chủng',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: VaccinationColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng các mốc',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              for (final group in groups.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected == group.key
                        ? VaccinationColors.primarySoft
                        : VaccinationColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      selected: selected == group.key,
                      selectedColor: VaccinationColors.primaryDark,
                      title: Text(
                        VaccineDose.ageLabelFor(group.key),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: VaccinationColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${group.value.length} mũi trong lịch',
                        style: const TextStyle(
                          color: VaccinationColors.secondary,
                        ),
                      ),
                      trailing: Text(
                        '${group.value.where((v) => v.record != null).length}/${group.value.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: VaccinationColors.primaryDark,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, group.key),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (age != null && mounted) {
      setState(() {
        _selectedAge = age;
      });
    }
  }

  Future<void> _showDoses(String title, List<ScheduledVaccine> doses) async {
    final selected = await showModalBottomSheet<ScheduledVaccine>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: VaccinationColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => VaccineDosesSheet(title: title, doses: doses),
    );
    if (selected != null && mounted) await _details(selected);
  }

  Widget _vaccineProgress(List<ScheduledVaccine> doses) {
    final done = doses.where((v) => v.record != null).length;
    final next = doses.where((v) => v.record == null).firstOrNull;
    final needsReview = next != null && !next.dueDate.isAfter(_today);
    return Semantics(
      label:
          '${doses.first.dose.name}, đã ghi nhận $done trên ${doses.length} mũi',
      child: InkWell(
        onTap: () => _showDoses(doses.first.dose.name, doses),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doses.first.dose.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: VaccinationColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExcludeSemantics(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final v in doses)
                            Icon(
                              v.record != null
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 16,
                              color: v.record != null
                                  ? VaccinationColors.recorded
                                  : VaccinationColors.secondary,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      next == null
                          ? 'Hoàn thành trong lịch'
                          : needsReview
                          ? 'Chưa ghi nhận - ${next.dose.doseLabel}'
                          : '${next.dose.doseLabel} - ${_date(next.dueDate)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: needsReview
                            ? VaccinationColors.attention
                            : next != null
                            ? VaccinationColors.planned
                            : VaccinationColors.secondary,
                        fontWeight: next != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$done/${doses.length}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: VaccinationColors.primaryDark,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: VaccinationColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final child = DemoStore.instance.childById(_childId);
      if (child == null) {
        return VaccinationTheme(
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'Sổ tiêm chủng',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: VaccinationColors.textPrimary,
                ),
              ),
            ),
            body: const Center(child: Text('Không tìm thấy hồ sơ bé.')),
          ),
        );
      }
      if (!DemoStore.instance.canViewChild(_childId, 'vaccination')) {
        return VaccinationTheme(
          child: Scaffold(
            backgroundColor: VaccinationColors.background,
            appBar: AppBar(
              title: const Text('Sổ tiêm chủng'),
              backgroundColor: VaccinationColors.background,
            ),
            body: const NoAccessView(section: 'sổ tiêm chủng'),
          ),
        );
      }
      final canEdit = DemoStore.instance.canEditChild(_childId, 'vaccination');
      final memo = _computeMemo(child);
      final records = memo.records;
      final appointments = memo.appointments;
      final due = memo.due;
      final done = memo.done;
      final missing = memo.missing;
      final supplements = memo.supplements;
      final active = memo.active;
      final ageGroups = memo.ageGroups;
      final sortedGroups = memo.sortedGroups;
      final ages = memo.ages;
      final childAge = memo.childAge;
      final childAgeKey = memo.childAgeKey;
      final selectedAge = ageGroups.containsKey(_selectedAge)
          ? _selectedAge!
          : ages.where((age) => age <= childAgeKey).lastOrNull ??
                ages.firstOrNull;
      final selectedDoses =
          ageGroups[selectedAge] ?? const <ScheduledVaccine>[];
      final priority = memo.priority;
      return VaccinationTheme(
        child: Scaffold(
          backgroundColor: VaccinationColors.background,
          appBar: AppBar(
            title: const Text(
              'Sổ tiêm chủng',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: VaccinationColors.textPrimary,
              ),
            ),
            backgroundColor: VaccinationColors.background,
            scrolledUnderElevation: 0,
            actions: [
              if (canEdit)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Tooltip(
                    message: 'Thêm vắc-xin bổ sung',
                    child: FilledButton(
                      key: const ValueKey('vaccination-add'),
                      onPressed: _add,
                      style: FilledButton.styleFrom(
                        backgroundColor: VaccinationColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Thêm',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: VaccinationTabs(
                        index: _view,
                        onChanged: (i) => setState(() => _view = i),
                      ),
                    ),
                    Expanded(
                      child: _view == 2
                          ? VaccinationHistory(
                              key: ValueKey('history-$_childId'),
                              childId: _childId,
                              records: records,
                              onSelect: _details,
                            )
                          : ListView(
                              key: PageStorageKey(
                                'vaccination-$_childId-$_view',
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              children: [
                                if (_view != 2) ...[
                                  VaccinationContent(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Đến $childAge tháng tuổi',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          VaccinationColors.primaryDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '$done/${due.length}',
                                                    key: const ValueKey(
                                                      'age-progress',
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 30,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          VaccinationColors.primaryDark,
                                                    ),
                                                  ),
                                                  const Text(
                                                    'mũi đã ghi nhận',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          VaccinationColors.primaryDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: TextButton(
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      VaccinationColors.planned,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 8,
                                                      ),
                                                  minimumSize: const Size(
                                                    0,
                                                    48,
                                                  ),
                                                ),
                                                onPressed: missing.isEmpty
                                                    ? null
                                                    : () => _showDoses(
                                                        'Cần kiểm tra',
                                                        missing,
                                                      ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        missing.isEmpty
                                                            ? ''
                                                            : '${missing.length} mũi chưa ghi nhận',
                                                        textAlign:
                                                            TextAlign.start,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    if (missing.isNotEmpty)
                                                      const Icon(
                                                        Icons
                                                            .chevron_right_rounded,
                                                        size: 18,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: due.isEmpty
                                                ? 0.0
                                                : done / due.length,
                                            minHeight: 6,
                                            color: VaccinationColors.primary,
                                            backgroundColor:
                                                VaccinationColors.primarySoft,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Theo lịch tham khảo',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: VaccinationColors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (priority != null) ...[
                                    Builder(
                                      builder: (context) {
                                        final isOverdue = !priority.hasAppointment &&
                                            !priority.dueDate.isAfter(_today);
                                        final isAppointment = priority.hasAppointment;
                                        final cardBg = isOverdue
                                            ? VaccinationColors.attentionSoft
                                            : VaccinationColors.plannedSoft;
                                        final badgeBg = isOverdue
                                            ? VaccinationColors.attention
                                            : (isAppointment
                                                ? VaccinationColors.primary
                                                : VaccinationColors.planned);
                                        final badgeIcon = isOverdue
                                            ? Icons.warning_amber_rounded
                                            : (isAppointment
                                                ? Icons.event_available_rounded
                                                : Icons.schedule_rounded);
                                        final badgeLabel = isAppointment
                                            ? 'Lịch hẹn'
                                            : (isOverdue ? 'Cần kiểm tra' : 'Dự kiến');
                                        return Material(
                                          color: cardBg,
                                          borderRadius: BorderRadius.circular(20),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () => _details(priority),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      color: badgeBg.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                    child: Icon(badgeIcon, color: badgeBg, size: 22),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Wrap(
                                                          spacing: 8,
                                                          runSpacing: 4,
                                                          crossAxisAlignment:
                                                              WrapCrossAlignment
                                                                  .center,
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: badgeBg,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                              child: Text(
                                                                badgeLabel,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                            Text(
                                                              _date(priority
                                                                  .dueDate),
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: isOverdue
                                                                    ? VaccinationColors
                                                                        .attention
                                                                    : VaccinationColors
                                                                        .primaryDark,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          '${priority.dose.name} - ${priority.dose.doseLabel}',
                                                          maxLines: 2,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                VaccinationColors
                                                                    .textPrimary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: VaccinationColors.secondary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (appointments.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              VaccinationColors.planned,
                                        ),
                                        onPressed: () => _showDoses(
                                          'Lịch hẹn đã lưu',
                                          appointments,
                                        ),
                                        icon: const Icon(Icons.event_outlined),
                                        label: Text(
                                          '${appointments.length} lịch hẹn đã lưu',
                                        ),
                                      ),
                                    ),
                                  if (_view == 0) ...[
                                    Wrap(
                                      alignment:
                                          WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          selectedAge == null
                                              ? 'Chưa có mốc'
                                              : 'Mốc ${VaccineDose.ageLabelFor(selectedAge)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: VaccinationColors.textPrimary,
                                          ),
                                        ),
                                        TextButton.icon(
                                          key: const ValueKey(
                                            'all-age-milestones',
                                          ),
                                          onPressed: selectedAge == null
                                              ? null
                                              : () => _pickAge(
                                                  sortedGroups,
                                                  selectedAge,
                                                ),
                                          icon: const Icon(
                                            Icons.tune_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Tất cả mốc'),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '${selectedDoses.where((v) => v.record != null).length}/${selectedDoses.length} mũi đã ghi nhận',
                                        style: const TextStyle(
                                          color: VaccinationColors.primaryDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        for (final v in selectedDoses)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Material(
                                              color: v.record == null
                                                  ? VaccinationColors
                                                        .plannedSoft
                                                  : VaccinationColors
                                                        .recordedSoft,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 2,
                                                    ),
                                                child: _dose(
                                                  v,
                                                  showDivider: false,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ] else if (active.isNotEmpty)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Tiến độ Vắc-xin',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: VaccinationColors.textPrimary,
                                          ),
                                        ),
                                        const Text(
                                          'Đã ghi nhận / tổng trong lịch',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: VaccinationColors.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        for (final group in active)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Material(
                                              color:
                                                  group.any(
                                                    (v) => v.record == null,
                                                  )
                                                  ? VaccinationColors
                                                        .plannedSoft
                                                  : VaccinationColors
                                                        .recordedSoft,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 2,
                                                    ),
                                                child: _vaccineProgress(group),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  if (_view == 1 && supplements.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Vắc-xin bổ sung',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: VaccinationColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    for (final group in supplements.values)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Material(
                                          color:
                                              group.any((v) => v.record == null)
                                              ? VaccinationColors.plannedSoft
                                              : VaccinationColors.recordedSoft,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 2,
                                            ),
                                            child: _vaccineProgress(group),
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DoseEntry extends StatelessWidget {
  const _DoseEntry({
    super.key,
    required this.vaccine,
    required this.onTap,
    this.showDivider = true,
  });
  final ScheduledVaccine vaccine;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final v = vaccine;
    final pending = v.record == null;
    final isOverdue = pending && !v.dueDate.isAfter(_today) && !v.hasAppointment;
    final statusColor = !pending
        ? VaccinationColors.recorded
        : (isOverdue ? VaccinationColors.attention : VaccinationColors.planned);
    final statusBg = !pending
        ? VaccinationColors.recordedSoft
        : (isOverdue ? VaccinationColors.attentionSoft : VaccinationColors.plannedSoft);
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              !pending
                  ? Icons.check_circle_rounded
                  : (isOverdue
                      ? Icons.warning_amber_rounded
                      : (v.hasAppointment
                          ? Icons.event_available_rounded
                          : Icons.schedule_rounded)),
              size: 20,
              color: statusColor,
            ),
          ),
          title: Text(
            v.dose.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: VaccinationColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${v.dose.doseLabel}${!v.dose.isCustom ? (v.dose.isTcmr ? " - TCMR" : " - Dịch vụ") : ""}${pending ? " - ${v.hasAppointment ? 'Hẹn' : 'Dự kiến'} ${_date(v.dueDate)}" : ""}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                if (v.record?.reaction.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Phản ứng: ${v.record!.reaction}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: VaccinationColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: VaccinationColors.secondary,
          ),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1, color: VaccinationColors.border),
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: VaccinationColors.background,
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: VaccinationColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  elevation: 2,
                  shadowColor: VaccinationColors.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: onPressed,
                icon: Icon(label == 'Thêm' ? Icons.add_rounded : Icons.check_rounded),
                label: Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class VaccineEditorScreen extends StatefulWidget {
  const VaccineEditorScreen({
    super.key,
    required this.childId,
    this.vaccine,
    this.initiallyGiven = true,
    this.markAsGiven = false,
  });
  final bool initiallyGiven;
  final bool markAsGiven;
  final String childId;
  final ScheduledVaccine? vaccine;
  @override
  State<VaccineEditorScreen> createState() => _VaccineEditorScreenState();
}

class _VaccineEditorScreenState extends State<VaccineEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _prevents,
      _dose,
      _place,
      _reaction,
      _note;
  late DateTime _selected;
  late bool _given;

  /// [VaccineProduct.code] for a scheduled dose; null = chưa chọn.
  String? _product;
  late bool _editing;
  bool _saving = false;
  bool _confirmingClose = false;
  late String _initialSnapshot;
  String get _snapshot => [
    _name.text,
    _prevents.text,
    _dose.text,
    _place.text,
    _reaction.text,
    _note.text,
    _selected.toIso8601String(),
    _given.toString(),
    _product ?? '',
  ].map((s) => '${s.length}:$s').join();
  bool get _dirty => _snapshot != _initialSnapshot;

  Future<void> _requestClose() async {
    if (_saving || _confirmingClose) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    _confirmingClose = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thay đổi chưa lưu?'),
        content: const Text(
          'Thông tin vừa nhập sẽ không được lưu vào sổ tiêm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục nhập'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    _confirmingClose = false;
    if (discard == true && mounted) Navigator.pop(context);
  }

  bool get _custom => widget.vaccine == null || widget.vaccine!.dose.isCustom;

  List<VaccineProduct> get _products => _custom
      ? const []
      : vaccineCatalog.vaccine(widget.vaccine!.dose.vaccineCode)?.products ??
            const [];

  @override
  void initState() {
    super.initState();
    final v = widget.vaccine;
    _name = TextEditingController(text: v?.dose.name);
    _prevents = TextEditingController(text: v?.dose.prevents);
    _dose = TextEditingController(text: v?.dose.doseLabel ?? 'Mũi 1');
    _place = TextEditingController(
      text: v?.record?.place ?? v?.appointmentPlace,
    );
    _reaction = TextEditingController(text: v?.record?.reaction);
    _note = TextEditingController(text: v?.record?.note ?? v?.dose.note);
    _product = v?.record?.product ?? v?.plannedProduct;
    _given = v == null
        ? widget.initiallyGiven
        : widget.markAsGiven || v.record != null || !v.dose.isCustom;
    _selected =
        v?.record?.date ?? (v?.dose.isCustom == true ? v!.dueDate : _today);
    if (_given && _selected.isAfter(_today)) _selected = _today;
    _editing = true;
    _initialSnapshot = _snapshot;
  }

  @override
  void dispose() {
    for (final c in [_name, _prevents, _dose, _place, _reaction, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final child = DemoStore.instance.childById(widget.childId);
    if (child == null) return;
    final dob = DateTime.parse(child['date_of_birth'] as String);
    final first = DateTime(dob.year, dob.month, dob.day);
    final last = _given ? _today : DateTime(_today.year + 5);
    final initial = _selected.isBefore(first)
        ? first
        : (_selected.isAfter(last) ? last : _selected);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _selected = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DemoStore.instance.saveVaccination(widget.childId, {
        'id':
            widget.vaccine?.dose.id ??
            'custom-${DateTime.now().microsecondsSinceEpoch}',
        'custom': _custom,
        if (widget.vaccine?.dose.groupId != null)
          'groupId': widget.vaccine!.dose.groupId,
        'name': _name.text.trim(),
        'prevents': _prevents.text.trim(),
        'doseLabel': _dose.text.trim().isEmpty ? 'Mũi tiêm' : _dose.text.trim(),
        'given': _given,
        if (!_custom && _product != null) 'product': _product,
        'date': _selected.toIso8601String(),
        // Đã tiêm: giữ ngày hẹn; chưa từng hẹn thì lưu ngày dự kiến làm ngày hẹn
        if (_given && widget.vaccine?.plannedDate != null)
          'scheduledDate': DateUtils.dateOnly(widget.vaccine!.plannedDate!)
              .toIso8601String(),
        if (_given && widget.vaccine != null)
          if ((widget.vaccine!.record?.appointmentPlace ??
                  widget.vaccine!.appointmentPlace)
              case final String appointmentPlace
              when appointmentPlace.isNotEmpty)
            'appointmentPlace': appointmentPlace,
        'place': _place.text.trim(),
        'reaction': _given ? _reaction.text.trim() : '',
        'note': _note.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được. Kiểm tra ngày tiêm và thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _custom ? 'Xóa mũi tiêm?' : 'Bỏ đánh dấu đã tiêm?',
          style: const TextStyle(
            color: VaccinationColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text('Thông tin đã ghi nhận của mũi này sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await DemoStore.instance.removeVaccination(
        widget.childId,
        widget.vaccine!.dose.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa xóa được. Vui lòng thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      style: const TextStyle(color: VaccinationColors.primaryDark),
      readOnly: !_editing || _saving,
      minLines: lines > 1 ? 3 : 1,
      maxLines: lines > 1 ? 5 : 1,
      maxLength: lines > 1 ? 500 : null,
      textInputAction: lines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        helperText: required ? 'Bắt buộc' : null,
        labelStyle: const TextStyle(color: VaccinationColors.textSecondary),
        floatingLabelStyle: const TextStyle(
          color: VaccinationColors.primary,
          fontWeight: FontWeight.w700,
        ),
        alignLabelWithHint: lines > 1,
        filled: true,
        fillColor: VaccinationColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: VaccinationColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: VaccinationColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: VaccinationColors.primary, width: 2),
        ),
      ),
      validator: (value) => required && (value == null || value.trim().isEmpty)
          ? 'Vui lòng nhập $label'
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _requestClose();
    },
    child: Material(
      color: VaccinationColors.background,
      child: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: VaccinationColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.vaccine == null
                          ? (_given ? 'Thêm vắc-xin bổ sung' : 'Thêm lịch hẹn')
                          : (_given ? 'Sửa mũi tiêm' : 'Sửa thông tin'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: VaccinationColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!_editing)
                    IconButton(
                      tooltip: 'Sửa thông tin',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (widget.vaccine != null &&
                      (_custom || widget.vaccine!.record != null))
                    PopupMenuButton<String>(
                      tooltip: 'Tùy chọn mũi tiêm',
                      enabled: !_saving,
                      onSelected: (_) => _remove(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            _custom ? 'Xóa mũi tiêm' : 'Bỏ đánh dấu đã tiêm',
                          ),
                        ),
                      ],
                    ),
                  IconButton(
                    tooltip: 'Đóng biểu mẫu',
                    onPressed: _saving ? null : _requestClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_custom) ...[
                      _field('Tên vaccine', _name, required: true),
                      _field('Mũi', _dose),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VaccinationColors.primarySoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vaccine!.dose.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: VaccinationColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.vaccine!.dose.doseLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _given
                                    ? VaccinationColors.primary
                                    : VaccinationColors.planned,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_products.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DropdownButtonFormField<String?>(
                            key: const ValueKey('vaccine-product'),
                            initialValue: _product,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Loại vắc-xin (tùy chọn)',
                              filled: true,
                              fillColor: VaccinationColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Chưa rõ'),
                              ),
                              for (final p in _products)
                                DropdownMenuItem(
                                  value: p.code,
                                  child: Text(
                                    [
                                      p.name,
                                      if (p.origin != null) p.origin!,
                                      if (p.doseCount != null)
                                        '${p.doseCount} liều',
                                    ].join(' - '),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _editing && !_saving
                                ? (value) => setState(() => _product = value)
                                : null,
                          ),
                        ),
                    ],
                    Material(
                      color: VaccinationColors.primarySoft,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: VaccinationColors.primary),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        title: Text(
                          _given ? 'Ngày tiêm' : 'Ngày hẹn tiêm',
                          style: const TextStyle(
                            fontSize: 14,
                            color: VaccinationColors.primaryDark,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _date(_selected),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _given
                                  ? VaccinationColors.primaryDark
                                  : VaccinationColors.planned,
                            ),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.calendar_month_outlined,
                          color: VaccinationColors.primary,
                        ),
                        onTap: _editing && !_saving ? _pick : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
                      child: Text(
                        _given
                            ? 'Ngày tiêm thực tế của bé'
                            : 'Lịch tự lưu - Chưa xác nhận với cơ sở tiêm',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: VaccinationColors.secondary,
                        ),
                      ),
                    ),
                    if (!_given) _field('Nơi hẹn tiêm', _place),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      key: ValueKey('additional-$_given'),
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(
                        Icons.notes_rounded,
                        color: VaccinationColors.primary,
                      ),
                      title: const Text(
                        'Thêm thông tin',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: VaccinationColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        _given
                            ? 'Tùy chọn - Nơi tiêm, phản ứng, ghi chú'
                            : 'Tùy chọn - Phòng bệnh và ghi chú',
                        style: const TextStyle(fontSize: 13),
                      ),
                      children: [
                        if (_custom) _field('Phòng bệnh', _prevents),
                        if (_given) _field('Nơi tiêm', _place),
                        if (_given)
                          _field('Phản ứng sau tiêm', _reaction, lines: 3),
                        _field('Ghi chú', _note, lines: 3),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _BottomAction(
              label: _saving
                  ? 'Đang lưu…'
                  : (_editing
                        ? (_given ? 'Lưu mũi tiêm' : 'Lưu lịch hẹn')
                        : (_given ? 'Sửa mũi tiêm' : 'Đánh dấu đã tiêm')),
              onPressed: _saving
                  ? null
                  : () {
                      if (_editing) {
                        _save();
                      } else {
                        setState(() {
                          _editing = true;
                          if (!_given) {
                            _given = true;
                            if (_selected.isAfter(_today)) _selected = _today;
                          }
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
