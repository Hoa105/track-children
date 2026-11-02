import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';
import 'growth_repository.dart';

Color trackingMetricColor(GrowthMetric metric) => switch (metric) {
  GrowthMetric.weight => const Color(0xFFE58C45),
  GrowthMetric.lengthHeight => const Color(0xFF4B92C6),
  GrowthMetric.headCircumference => const Color(0xFF9B78C6),
};

IconData trackingMetricIcon(GrowthMetric metric) => switch (metric) {
  GrowthMetric.weight => Icons.monitor_weight_outlined,
  GrowthMetric.lengthHeight => Icons.height,
  GrowthMetric.headCircumference => Icons.face_retouching_natural_outlined,
};

String trackingDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
String trackingDay(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String trackingValue(dynamic value) => value is num
    ? value.toDouble().toStringAsFixed(1).replaceAll('.', ',')
    : '--';
String trackingMetricKey(GrowthMetric metric) => switch (metric) {
  GrowthMetric.weight => 'weight',
  GrowthMetric.lengthHeight => 'height',
  GrowthMetric.headCircumference => 'head_circumference',
};
String trackingError(Object error) {
  if (error is AuthException) {
    return switch (error.code) {
      'MEASUREMENT_EXISTS' =>
        'Ngày này đã có số đo. Mẹ hãy mở số đo đó để sửa.',
      'INVALID_DATE' => 'Ngày đo phải từ ngày sinh đến hôm nay.',
      'INVALID_MEASURE_POSITION' => 'Hãy chọn đúng cách đo nằm hoặc đứng.',
      'UNAUTHORIZED_CAREGIVER' => 'Bạn chỉ có quyền xem số đo.',
      'RESOURCE_NOT_FOUND' => 'Số đo không còn tồn tại. Hãy tải lại lịch sử.',
      _ => 'Chưa thực hiện được. Vui lòng thử lại.',
    };
  }
  return 'Chưa thực hiện được. Vui lòng thử lại.';
}

Future<DateTime?> pickTrackingDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String helpText,
}) => showDatePicker(
  context: context,
  initialDate: initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
  helpText: helpText,
  builder: (context, child) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );
    return Theme(
      data: theme.copyWith(
        colorScheme: colors,
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: AppColors.primary,
          headerForegroundColor: Colors.white,
          headerHeadlineStyle: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
          headerHelpStyle: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          weekdayStyle: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
          dayStyle: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          todayForegroundColor: WidgetStatePropertyAll(AppColors.primary),
          todayBackgroundColor: WidgetStatePropertyAll(Colors.transparent),
          dayForegroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textSecondary.withAlpha(100);
            }
            return AppColors.textPrimary;
          }),
          dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return Colors.transparent;
          }),
          todayBorder: BorderSide(color: AppColors.primary, width: 1.5),
          rangeSelectionBackgroundColor: AppColors.primarySoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
        ),
      ),
      child: child!,
    );
  },
);

Future<bool> openTrackingEditor(
  BuildContext context,
  GrowthRepository repository, {
  GrowthMetric? metric,
  GrowthMeasurementDraft? original,
  DateTime? initialDate,
}) async {
  if (!repository.canEdit) return false;
  final selected =
      metric ??
      await showModalBottomSheet<GrowthMetric>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.background,
        useSafeArea: true,
        builder: (sheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thêm số đo mới',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Chọn thông tin bạn muốn cập nhật cho bé',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              for (final item in GrowthMetric.values) ...[
                _MetricChoiceTile(
                  metric: item,
                  onTap: () => Navigator.pop(sheet, item),
                ),
                if (item != GrowthMetric.values.last)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );
  if (selected == null || !context.mounted) return false;
  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TrackingMeasurementEditor(
            repository: repository,
            metric: selected,
            original: original,
            initialDate: initialDate,
          ),
        ),
      ) ??
      false;
}

class _MetricChoiceTile extends StatelessWidget {
  const _MetricChoiceTile({required this.metric, required this.onTap});
  final GrowthMetric metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: trackingMetricColor(metric).withAlpha(28),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                trackingMetricIcon(metric),
                color: trackingMetricColor(metric),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Đơn vị: ${metric.unit}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}

class _MeasureMethodTile extends StatelessWidget {
  const _MeasureMethodTile({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final GrowthMeasurementMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = method == GrowthMeasurementMethod.recumbent
        ? 'Nằm đo chiều dài'
        : 'Đứng đo chiều cao';
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                method == GrowthMeasurementMethod.recumbent
                    ? Icons.airline_seat_flat_outlined
                    : Icons.accessibility_new_outlined,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrackingMeasurementEditor extends StatefulWidget {
  const TrackingMeasurementEditor({
    super.key,
    required this.repository,
    required this.metric,
    this.original,
    this.initialDate,
  });
  final GrowthRepository repository;
  final GrowthMetric metric;
  final GrowthMeasurementDraft? original;
  final DateTime? initialDate;
  @override
  State<TrackingMeasurementEditor> createState() =>
      _TrackingMeasurementEditorState();
}

class _TrackingMeasurementEditorState extends State<TrackingMeasurementEditor> {
  final _form = GlobalKey<FormState>();
  late final _value = TextEditingController(
    text: widget.original == null
        ? ''
        : formatGrowthValue(widget.original!.value),
  );
  late DateTime _day = DateUtils.dateOnly(
    widget.original?.measuredAt ?? widget.initialDate ?? DateTime.now(),
  );
  late GrowthMeasurementDraft? _original = widget.original;
  late GrowthMeasurementMethod? _method = widget.original?.method;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final first = DateUtils.dateOnly(
      widget.repository.dateOfBirth ?? DateTime(1900),
    );
    final last = DateUtils.dateOnly(DateTime.now());
    if (first.isAfter(last)) return;
    final chosen = await pickTrackingDate(
      context,
      initialDate: _day.isBefore(first)
          ? first
          : _day.isAfter(last)
          ? last
          : _day,
      firstDate: first,
      lastDate: last,
      helpText: 'Chọn ngày thực sự đo',
    );
    if (chosen != null && mounted) setState(() => _day = chosen);
  }

  Future<void> _save() async {
    if (_busy ||
        !widget.repository.canEdit ||
        !_form.currentState!.validate()) {
      return;
    }
    if (widget.metric == GrowthMetric.lengthHeight && _method == null) {
      setState(() => _error = 'Mẹ hãy xác nhận bé được đo nằm hay đứng.');
      return;
    }
    final birth = widget.repository.dateOfBirth;
    if (_day.isAfter(DateUtils.dateOnly(DateTime.now())) ||
        birth != null && _day.isBefore(DateUtils.dateOnly(birth))) {
      setState(() => _error = 'Ngày đo phải từ ngày sinh đến hôm nay.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // A preflight makes duplicate handling friendly; the server still enforces it atomically.
      await widget.repository.refreshMeasurements();
      final rows = await widget.repository.measurements(widget.metric);
      final conflicts = rows.where(
        (r) =>
            DateUtils.isSameDay(r.measuredAt, _day) &&
            (_original == null ||
                (_original!.id != null
                    ? r.id != _original!.id
                    : !DateUtils.isSameDay(
                        r.measuredAt,
                        _original!.measuredAt,
                      ))),
      );
      if (conflicts.isNotEmpty) {
        if (!mounted) return;
        if (_original != null) {
          setState(
            () => _error = 'Ngày này đã có số đo khác. Hãy chọn lại ngày đo.',
          );
          return;
        }
        final existing = conflicts.first;
        final edit = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Ngày này đã có số đo'),
            content: Text(
              '${trackingValue(existing.value)} ${widget.metric.unit} · ${trackingDate(existing.measuredAt)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Quay lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Mở để sửa'),
              ),
            ],
          ),
        );
        if (edit == true && mounted) {
          setState(() {
            _original = existing;
            _value.text = formatGrowthValue(existing.value);
            _day = existing.measuredAt;
            _method = existing.method;
          });
        }
        return;
      }
      final draft = GrowthMeasurementDraft(
        value: double.parse(_value.text.trim().replaceAll(',', '.')),
        measuredAt: _day,
        method: widget.metric == GrowthMetric.lengthHeight ? _method : null,
      );
      if (_original == null) {
        await widget.repository.createRecord(widget.metric, draft);
      } else {
        await widget.repository.updateRecord(widget.metric, _original!, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = trackingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final original = _original;
    if (_busy || original == null || !widget.repository.canEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFB44B42),
          size: 32,
        ),
        title: const Text(
          'Xóa số đo?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Bản ghi ${trackingValue(original.value)} ${widget.metric.unit} ngày ${trackingDate(original.measuredAt)} sẽ bị xóa khỏi lịch sử.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB44B42),
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.deleteRecord(widget.metric, original);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = trackingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: Text('${_original == null ? 'Thêm' : 'Sửa'} số đo'),
        actions: [
          if (_original != null)
            IconButton(
              tooltip: 'Xóa số đo',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: trackingMetricColor(widget.metric).withAlpha(28),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: trackingMetricColor(widget.metric).withAlpha(70),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(210),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      trackingMetricIcon(widget.metric),
                      color: trackingMetricColor(widget.metric),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.metric.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.metric.measurementTip,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _value,
                      enabled: !_busy,
                      autofocus: _original == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Số đo',
                        hintText: widget.metric.initialValue,
                        suffixText: widget.metric.unit,
                        filled: true,
                        fillColor: AppColors.background,
                        prefixIcon: const Icon(Icons.edit_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (input) {
                        final raw = (input ?? '').trim().replaceAll(',', '.');
                        final value = double.tryParse(raw);
                        if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw) ||
                            value == null ||
                            !value.isFinite ||
                            value <= 0 ||
                            value > 99999.99) {
                          return 'Nhập số lớn hơn 0, tối đa 2 chữ số thập phân.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _busy ? null : _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ngày đo',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateUtils.isSameDay(_day, DateTime.now()) ? 'Hôm nay, ' : ''}${trackingDate(_day)}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.metric == GrowthMetric.lengthHeight) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bé được đo thế nào?',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final method in GrowthMeasurementMethod.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MeasureMethodTile(
                            method: method,
                            selected: _method == method,
                            enabled: !_busy,
                            onTap: () => setState(() => _method = method),
                          ),
                        ),
                      const Text(
                        'Dưới 2 tuổi: nên đo nằm. Từ 2 tuổi: nên đo đứng.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _busy || !widget.repository.canEdit ? null : _save,
              child: Text(
                _busy
                    ? 'Đang lưu…'
                    : _original == null
                    ? 'Thêm số đo'
                    : 'Lưu thay đổi',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TrackingBmiQuickEditor extends StatefulWidget {
  const TrackingBmiQuickEditor({
    super.key,
    required this.repository,
    this.initialDate,
  });

  final GrowthRepository repository;
  final DateTime? initialDate;

  @override
  State<TrackingBmiQuickEditor> createState() => _TrackingBmiQuickEditorState();
}

class _TrackingBmiQuickEditorState extends State<TrackingBmiQuickEditor> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  late DateTime _day = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
  late GrowthMeasurementMethod _method = _recommendedMethod(_day);
  bool _busy = false;
  String? _error;

  GrowthMeasurementMethod _recommendedMethod(DateTime day) {
    final birth = widget.repository.dateOfBirth;
    if (birth == null) return GrowthMeasurementMethod.standing;
    return day.difference(DateUtils.dateOnly(birth)).inDays < 731
        ? GrowthMeasurementMethod.recumbent
        : GrowthMeasurementMethod.standing;
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final first = DateUtils.dateOnly(
      widget.repository.dateOfBirth ?? DateTime(1900),
    );
    final last = DateUtils.dateOnly(DateTime.now());
    if (first.isAfter(last)) return;
    final chosen = await pickTrackingDate(
      context,
      initialDate: _day.isBefore(first)
          ? first
          : _day.isAfter(last)
          ? last
          : _day,
      firstDate: first,
      lastDate: last,
      helpText: 'Chọn ngày đo cân nặng và chiều cao',
    );
    if (chosen != null && mounted) {
      setState(() {
        _day = chosen;
        _method = _recommendedMethod(chosen);
      });
    }
  }

  String? _validateNumber(String? input) {
    final raw = (input ?? '').trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw) ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 99999.99) {
      return 'Nhập số lớn hơn 0, tối đa 2 chữ số thập phân.';
    }
    return null;
  }

  double _number(TextEditingController controller) =>
      double.parse(controller.text.trim().replaceAll(',', '.'));

  Future<bool> _hasExistingMeasurement() async {
    await widget.repository.refreshMeasurements();
    final measurements = await Future.wait([
      widget.repository.measurements(GrowthMetric.weight),
      widget.repository.measurements(GrowthMetric.lengthHeight),
    ]);
    return measurements.any(
      (items) =>
          items.any((item) => DateUtils.isSameDay(item.measuredAt, _day)),
    );
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final hadExisting = await _hasExistingMeasurement();
      await widget.repository.saveBmiMeasurements(
        measuredAt: _day,
        weightKg: _number(_weight),
        heightCm: _number(_height),
        heightMethod: _method,
      );
      if (mounted) Navigator.pop(context, hadExisting);
    } catch (error) {
      if (mounted) setState(() => _error = trackingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: const Text('Cập nhật BMI nhanh'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF177565)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nên đo cân nặng và chiều cao mới trong cùng một lần để kết quả BMI phản ánh đúng tình trạng hiện tại của bé.',
                      style: TextStyle(
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        enabled: !_busy,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Cân nặng',
                          suffixText: 'kg',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: _validateNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _height,
                        enabled: !_busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Chiều cao',
                          suffixText: 'cm',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: _validateNumber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Ngày đo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${DateUtils.isSameDay(_day, DateTime.now()) ? 'Hôm nay, ' : ''}${trackingDate(_day)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _pickDate,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cách đo chiều cao',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final method in GrowthMeasurementMethod.values)
                  ChoiceChip(
                    label: Text(
                      method == GrowthMeasurementMethod.recumbent
                          ? 'Nằm đo chiều dài'
                          : 'Đứng đo chiều cao',
                    ),
                    selected: _method == method,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _method = method),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Dưới 2 tuổi: nên đo nằm. Từ 2 tuổi: nên đo đứng.',
              style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Đang lưu…' : 'Lưu và xem kết quả'),
            ),
          ],
        ),
      ),
    ),
  );
}

class TrackingHistoryScreen extends StatefulWidget {
  const TrackingHistoryScreen({
    super.key,
    required this.repository,
    required this.metric,
  });
  final GrowthRepository repository;
  final GrowthMetric metric;
  @override
  State<TrackingHistoryScreen> createState() => _TrackingHistoryScreenState();
}

class _TrackingHistoryScreenState extends State<TrackingHistoryScreen> {
  late Future<List<GrowthMeasurementDraft>> _data = _load();
  Future<List<GrowthMeasurementDraft>> _load() async {
    await widget.repository.refreshMeasurements();
    final rows = [...await widget.repository.measurements(widget.metric)]
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return rows;
  }

  void _reload() {
    setState(() {
      _data = _load();
      _data.ignore();
    });
  }

  Future<void> _edit([GrowthMeasurementDraft? row]) async {
    if (await openTrackingEditor(
          context,
          widget.repository,
          metric: widget.metric,
          original: row,
        ) &&
        mounted) {
      _reload();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu số đo')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      scrolledUnderElevation: 0,
      title: Text(widget.metric.title),
      actions: [
        if (widget.repository.canEdit)
          IconButton(
            tooltip: 'Ghi số đo',
            onPressed: _edit,
            icon: const Icon(Icons.add),
          ),
      ],
    ),
    body: FutureBuilder<List<GrowthMeasurementDraft>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('Chưa tải được. Thử lại'),
            ),
          );
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trackingMetricIcon(widget.metric),
                        size: 48,
                        color: trackingMetricColor(widget.metric),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Chưa có số đo',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Thêm số đo đầu tiên để theo dõi sự phát triển của bé.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      if (widget.repository.canEdit) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => _edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm số đo'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _data;
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = rows[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: widget.repository.canEdit ? () => _edit(row) : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: trackingMetricColor(widget.metric)
                                .withAlpha(25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            trackingMetricIcon(widget.metric),
                            color: trackingMetricColor(widget.metric),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trackingDate(row.measuredAt),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.metric == GrowthMetric.lengthHeight)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    row.method ==
                                            GrowthMeasurementMethod.recumbent
                                        ? 'Đo nằm'
                                        : 'Đo đứng',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${trackingValue(row.value)} ${widget.metric.unit}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (widget.repository.canEdit)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class TrackingHeadQuickEditor extends StatefulWidget {
  const TrackingHeadQuickEditor({
    super.key,
    required this.repository,
    this.initialDate,
  });

  final GrowthRepository repository;
  final DateTime? initialDate;

  @override
  State<TrackingHeadQuickEditor> createState() =>
      _TrackingHeadQuickEditorState();
}

class _TrackingHeadQuickEditorState extends State<TrackingHeadQuickEditor> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  late DateTime _day = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  String? _validateValue(String? input) {
    final raw = (input ?? '').trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw) ||
        value == null ||
        !value.isFinite ||
        value <= 0 ||
        value > 999.99) {
      return 'Nhập số lớn hơn 0, tối đa 2 chữ số thập phân.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final first = DateUtils.dateOnly(
      widget.repository.dateOfBirth ?? DateTime(1900),
    );
    final last = DateUtils.dateOnly(DateTime.now());
    final chosen = await pickTrackingDate(
      context,
      initialDate: _day.isBefore(first)
          ? first
          : _day.isAfter(last)
          ? last
          : _day,
      firstDate: first,
      lastDate: last,
      helpText: 'Chọn ngày đo vòng đầu',
    );
    if (chosen != null && mounted) setState(() => _day = chosen);
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.refreshMeasurements();
      final existing = (await widget.repository.measurements(
        GrowthMetric.headCircumference,
      )).any((item) => DateUtils.isSameDay(item.measuredAt, _day));
      await widget.repository.saveMeasurement(
        GrowthMetric.headCircumference,
        GrowthMeasurementDraft(
          value: double.parse(_value.text.trim().replaceAll(',', '.')),
          measuredAt: _day,
        ),
      );
      if (mounted) Navigator.pop(context, existing);
    } catch (error) {
      if (mounted) setState(() => _error = trackingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        scrolledUnderElevation: 0,
        title: const Text('Cập nhật vòng đầu nhanh'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nên đo vòng đầu nhẹ nhàng, đúng vị trí lớn nhất quanh đầu của bé để kết quả chính xác hơn.',
                      style: TextStyle(
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _value,
                  enabled: !_busy,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Vòng đầu',
                    suffixText: 'cm',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: _validateValue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Ngày đo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${DateUtils.isSameDay(_day, DateTime.now()) ? 'Hôm nay, ' : ''}${trackingDate(_day)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _busy ? null : _pickDate,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu và xem kết quả'),
            ),
          ],
        ),
      ),
    ),
  );
}

class TrackingAssessmentScreen extends StatefulWidget {
  const TrackingAssessmentScreen({
    super.key,
    required this.repository,
    required this.kind,
    this.selectedId,
  });
  final GrowthRepository repository;
  final String kind;
  final String? selectedId;
  @override
  State<TrackingAssessmentScreen> createState() =>
      _TrackingAssessmentScreenState();
}

class _TrackingAssessmentScreenState extends State<TrackingAssessmentScreen> {
  late String? _selectedId = widget.selectedId;
  late Future<Map<String, dynamic>> _data = _load();
  Future<Map<String, dynamic>> _load() =>
      widget.repository.parentAssessment(widget.kind, selectedId: _selectedId);
  void _reload() => setState(() {
    _data = _load();
    _data.ignore();
  });
  Future<void> _updateBmiMeasurements() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrackingBmiQuickEditor(
          repository: widget.repository,
          initialDate: DateTime.now(),
        ),
      ),
    );
    if (saved != null && mounted) {
      _selectedId = null;
      _reload();
      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Số đo trong ngày đã có và đã được cập nhật dữ liệu mới.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateHeadMeasurement() async {
    final overwritten = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrackingHeadQuickEditor(
          repository: widget.repository,
          initialDate: DateTime.now(),
        ),
      ),
    );
    if (overwritten != null && mounted) {
      _selectedId = null;
      _reload();
      if (overwritten) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Số đo vòng đầu trong ngày đã có và đã được cập nhật dữ liệu mới.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showMeasurementDetails(Map source) async {
    final metric = switch (source['metric']) {
      'weight' => GrowthMetric.weight,
      'height' => GrowthMetric.lengthHeight,
      _ => GrowthMetric.headCircumference,
    };
    final measuredOn = DateTime.tryParse(
      source['measuredOn']?.toString() ?? '',
    );
    if (measuredOn == null) return;
    final method = source['measurePosition'] == 'lying'
        ? GrowthMeasurementMethod.recumbent
        : source['measurePosition'] == 'standing'
        ? GrowthMeasurementMethod.standing
        : null;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              switch (metric) {
                GrowthMetric.weight => 'Chi tiết cân nặng',
                GrowthMetric.lengthHeight => 'Chi tiết chiều cao',
                GrowthMetric.headCircumference => 'Chi tiết vòng đầu',
              },
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            _measurementDetailRow(
              'Số đo',
              '${trackingValue(source['value'])} ${source['unit']}',
            ),
            const Divider(height: 24),
            _measurementDetailRow('Ngày đo', trackingDate(measuredOn)),
            if (method != null) ...[
              const Divider(height: 24),
              _measurementDetailRow(
                'Cách đo',
                method == GrowthMeasurementMethod.recumbent
                    ? 'Đo nằm'
                    : 'Đo đứng',
              ),
            ],
            if ((source['note']?.toString().trim() ?? '').isNotEmpty) ...[
              const Divider(height: 24),
              _measurementDetailRow('Ghi chú', source['note'].toString()),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _measurementDetailRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 90,
        child: Text(label, style: const TextStyle(color: Color(0xFF667085))),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    ],
  );

  Color _bmiColor(String? code) => switch (code) {
    'WITHIN_RANGE' => AppColors.primary,
    'RISK_OVERWEIGHT' => const Color(0xFF9A6700),
    'THINNESS' || 'OVERWEIGHT' => const Color(0xFFB45309),
    'SEVERE_THINNESS' || 'OBESITY' => const Color(0xFFB42318),
    _ => const Color(0xFF475467),
  };

  Color _rangeColor(Map range) {
    final value = range['color']?.toString().replaceFirst('#', '');
    final parsed = value == null ? null : int.tryParse('FF$value', radix: 16);
    return parsed == null ? const Color(0xFF98A2B3) : Color(parsed);
  }

  double? _visualNumber(dynamic value) {
    if (value is num) {
      final number = value.toDouble();
      return number.isFinite ? number : null;
    }
    final number = double.tryParse(value?.toString() ?? '');
    return number != null && number.isFinite ? number : null;
  }

  List<Map> _visualRanges(Map result, String title) {
    final raw = result['visualRanges'];
    if (raw is List) return raw.whereType<Map>().toList();
    if (raw is Map) {
      final section = title.toLowerCase() == 'bmi' ? raw['bmi'] : raw['head'];
      if (section is List) return section.whereType<Map>().toList();
    }
    return const [];
  }

  Map _visualScale(Map result) {
    final direct = result['visualScale'];
    if (direct is Map) return direct;
    final ranges = result['visualRanges'];
    if (ranges is Map && ranges['scale'] is Map) {
      return ranges['scale'] as Map;
    }
    return const {};
  }

  Widget _growthScale(num? zScore, String? code, Map result, String title) {
    final ranges = _visualRanges(result, title);
    final scale = _visualScale(result);
    if (ranges.isEmpty) {
      return const SizedBox.shrink();
    }
    final lowerBounds = ranges
        .map((range) => _visualNumber(range['zMin']))
        .whereType<double>();
    final upperBounds = ranges
        .map((range) => _visualNumber(range['zMax']))
        .whereType<double>();
    final scaleMin =
        _visualNumber(scale['zMin']) ??
        (lowerBounds.isEmpty
            ? -4
            : lowerBounds.reduce((a, b) => a < b ? a : b));
    final scaleMax =
        _visualNumber(scale['zMax']) ??
        (upperBounds.isEmpty ? 4 : upperBounds.reduce((a, b) => a > b ? a : b));
    if (!scaleMin.isFinite || !scaleMax.isFinite || scaleMax <= scaleMin) {
      return const SizedBox.shrink();
    }
    final span = scaleMax - scaleMin;
    final activeRange = ranges
        .where((range) => range['code'] == code)
        .firstOrNull;
    final activeColor = activeRange == null
        ? const Color(0xFF475467)
        : _rangeColor(activeRange);
    final position = zScore == null
        ? null
        : ((zScore.clamp(scaleMin, scaleMax).toDouble() - scaleMin) / span);
    return Semantics(
      label:
          'Thang đánh giá $title. Kết quả của bé: ${result['summary'] ?? 'Đang theo dõi'}${zScore == null ? '' : ', Z-score $title ${trackingValue(zScore)}'}',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final markerCenter = constraints.maxWidth * (position ?? 0);
              final bubbleWidth = title == 'vòng đầu' ? 120.0 : 86.0;
              final bubbleLeft = (markerCenter - bubbleWidth / 2).clamp(
                0.0,
                constraints.maxWidth - bubbleWidth,
              );
              final arrowLeft = (markerCenter - 14).clamp(
                0.0,
                constraints.maxWidth - 28,
              );
              return SizedBox(
                height: 62,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Row(
                          children: [
                            for (final range in ranges)
                              Expanded(
                                flex:
                                    (((_visualNumber(range['zMax']) ??
                                                    scaleMax) -
                                                (_visualNumber(range['zMin']) ??
                                                    scaleMin)) /
                                            span *
                                            1000)
                                        .round()
                                        .clamp(1, 1000)
                                        .toInt(),
                                child: Container(
                                  height: 12,
                                  color: _rangeColor(range).withValues(
                                    alpha: range['code'] == code ? 1 : 0.38,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (position != null) ...[
                      Positioned(
                        left: bubbleLeft,
                        top: 0,
                        child: Container(
                          width: bubbleWidth,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Z-score $title',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${zScore! >= 0 ? '+' : ''}${trackingValue(zScore)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: arrowLeft,
                        top: 28,
                        child: Icon(
                          Icons.arrow_drop_down,
                          size: 28,
                          color: activeColor,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Row(
            children: [
              for (final range in ranges)
                Expanded(
                  flex:
                      (((_visualNumber(range['zMax']) ?? scaleMax) -
                                  (_visualNumber(range['zMin']) ?? scaleMin)) /
                              span *
                              1000)
                          .round()
                          .clamp(1, 1000)
                          .toInt(),
                  child: Text(
                    range['label']?.toString() ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bmiScale(Map result) => _growthScale(
    _visualNumber(result['zScore']),
    result['classificationCode']?.toString(),
    result,
    'BMI',
  );

  Widget _bmiResultCard(Map result) {
    final bmi = result['bmi'] as num?;
    final code = result['classificationCode']?.toString();
    final color = _bmiColor(code);
    final sources = (result['sources'] as List? ?? []).cast<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TÌNH TRẠNG HIỆN TẠI',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result['summary']?.toString() ?? 'Chưa có nhận xét',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHỈ SỐ BMI',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: trackingValue(bmi),
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(
                      text: ' kg/m²',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _bmiScale(result),
              if (sources.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Text(
                  'Số đo dùng để tính',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final source in sources)
                      Material(
                        color: const Color(0xFFF5F7F6),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showMeasurementDetails(source),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${source['metric'] == 'weight' ? 'Cân nặng' : 'Chiều cao'}: ${trackingValue(source['value'])} ${source['unit']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: Color(0xFF667085),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: color, size: 21),
                  const SizedBox(width: 9),
                  const Text(
                    'BỐ MẸ NÊN LÀM',
                    style: TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result['action']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickBmiActions() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'CẬP NHẬT SỐ ĐO',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Đo lại cân nặng và chiều cao',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Nên đo cả hai trong cùng một lần để cập nhật BMI.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _updateBmiMeasurements,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nhập số đo mới'),
        ),
      ],
    ),
  );

  Widget _bmiResult(Map result, {bool previous = false}) {
    final ready = result['status'] == 'READY';
    final measuredOn = DateTime.tryParse(
      result['measuredOn']?.toString() ?? '',
    );
    if (previous) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: Color(0xFF667085), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Lần trước${measuredOn == null ? '' : ' · ${trackingDate(measuredOn)}'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              result['summary']?.toString() ?? 'Chưa có kết quả',
              style: TextStyle(
                color: _bmiColor(result['classificationCode']?.toString()),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ready)
          _bmiResultCard(result)
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              result['summary']?.toString() ?? 'Chưa tính được kết quả',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        if (widget.repository.canEdit) ...[
          const SizedBox(height: 20),
          _quickBmiActions(),
        ],
      ],
    );
  }

  Widget _missingBmi(
    Map<String, dynamic> data,
    DateTime? anchorDate,
    bool recent,
  ) {
    final missingWeight = data['missingMetric'] == 'weight';
    final title = anchorDate == null
        ? 'Thêm số đo đầu tiên'
        : recent
        ? 'Thiếu ${missingWeight ? 'cân nặng' : 'chiều cao'}'
        : 'Cập nhật số đo mới';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cần cân nặng và chiều cao đo trong vòng 1 ngày để xem kết quả.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085), height: 1.35),
              ),
              if (anchorDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Số đo gần nhất: ${trackingDate(anchorDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.repository.canEdit) ...[
          const SizedBox(height: 18),
          _quickBmiActions(),
        ],
      ],
    );
  }

  String _headLabel(String? code) => switch (code) {
    'VERY_LOW_HC' => 'Vòng đầu rất nhỏ',
    'LOW_HC' => 'Vòng đầu nhỏ',
    'WITHIN_RANGE' => 'Vòng đầu phù hợp',
    'HIGH_HC' => 'Vòng đầu lớn',
    'VERY_HIGH_HC' => 'Vòng đầu rất lớn',
    _ => 'Đang theo dõi',
  };

  Color _headColor(String? code) => switch (code) {
    'WITHIN_RANGE' => const Color(0xFF177565),
    'LOW_HC' || 'HIGH_HC' => const Color(0xFFB45309),
    'VERY_LOW_HC' || 'VERY_HIGH_HC' => const Color(0xFFB42318),
    _ => const Color(0xFF475467),
  };

  Widget _headScale(Map result) => _growthScale(
    _visualNumber(result['zScore']),
    result['classificationCode']?.toString(),
    result,
    'vòng đầu',
  );

  /*
  Widget _headScaleLegacy(num? zScore, String? code) {
    final color = _headColor(code);
    final position = zScore == null
        ? null
        : (zScore.clamp(-4, 4).toDouble() + 4) / 8;
    return Semantics(
      label:
          'Thang đánh giá vòng đầu. Kết quả: ${_headLabel(code)}${zScore == null ? '' : ', Z-score vòng đầu ${trackingValue(zScore)}'}',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final markerCenter = constraints.maxWidth * (position ?? 0);
              const bubbleWidth = 108.0;
              final bubbleLeft = (markerCenter - bubbleWidth / 2).clamp(
                0.0,
                constraints.maxWidth - bubbleWidth,
              );
              final arrowLeft = (markerCenter - 14).clamp(
                0.0,
                constraints.maxWidth - 28,
              );
              return SizedBox(
                height: 62,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 12,
                                color: const Color(0xFFB42318).withValues(
                                  alpha: code == 'VERY_LOW_HC' ? 1 : 0.4,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 12,
                                color: const Color(0xFFE07916).withValues(
                                  alpha: code == 'LOW_HC' ? 1 : 0.4,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Container(
                                height: 12,
                                color: const Color(0xFF179B80).withValues(
                                  alpha: code == 'WITHIN_RANGE' ? 1 : 0.4,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 12,
                                color: const Color(0xFFE07916).withValues(
                                  alpha: code == 'HIGH_HC' ? 1 : 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (position != null) ...[
                      Positioned(
                        left: bubbleLeft,
                        child: Container(
                          width: bubbleWidth,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Z-score vòng đầu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${zScore! >= 0 ? '+' : ''}${trackingValue(zScore)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: arrowLeft,
                        top: 28,
                        child: Icon(
                          Icons.arrow_drop_down,
                          size: 28,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Row(
            children: [
              for (final range in ranges)
                Expanded(
                  flex: ((((range['zMax'] as num?)?.toDouble() ??
                                  scaleMax) -
                              ((range['zMin'] as num?)?.toDouble() ??
                                  scaleMin)) /
                          span *
                          1000)
                      .round()
                      .clamp(1, 1000),
                  child: Text(
                    range['label']?.toString() ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  }*/

  Widget _headResult(Map result) {
    final code = result['classificationCode']?.toString();
    final ranges = _visualRanges(result, 'vòng đầu');
    final activeRange = ranges
        .where((range) => range['code'] == code)
        .firstOrNull;
    final color = activeRange == null
        ? _headColor(code)
        : _rangeColor(activeRange);
    final sources = (result['sources'] as List? ?? []).cast<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TÌNH TRẠNG HIỆN TẠI',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result['summary']?.toString() ?? _headLabel(code),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHỈ SỐ VÒNG ĐẦU',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              if (sources.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: trackingValue(sources.first['value']),
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const TextSpan(
                        text: ' cm',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _headScale(result),
              if (sources.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showMeasurementDetails(sources.first),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Xem chi tiết số đo vòng đầu',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: color),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.purpleSurfaceLight,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: color, size: 21),
                  const SizedBox(width: 9),
                  const Text(
                    'BỐ MẸ NÊN LÀM',
                    style: TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result['action']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (widget.repository.canEdit) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _updateHeadMeasurement,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Cập nhật vòng đầu'),
          ),
        ],
      ],
    );
  }

  Widget _result(Map result, {bool previous = false}) {
    if (widget.kind == 'bmi') return _bmiResult(result, previous: previous);
    if (!previous) return _headResult(result);
    final sources = (result['sources'] as List? ?? []).cast<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (previous)
          const Padding(
            padding: EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              'Tình trạng lần trước',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6F4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            result['summary']?.toString() ?? 'Chưa có nhận xét',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Mẹ nên làm gì?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          result['action']?.toString() ?? '',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 20),
        const Text(
          'Số đo được sử dụng',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        for (final source in sources)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${switch (source['metric']) {
                'weight' => 'Cân nặng',
                'height' => 'Chiều dài/cao',
                _ => 'Vòng đầu',
              }}: ${trackingValue(source['value'])} ${source['unit']}',
            ),
            subtitle: Text(
              trackingDate(DateTime.parse(source['measuredOn'].toString())),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      title: Text(
        widget.kind == 'bmi' ? 'Tình trạng cân nặng' : 'Tình trạng vòng đầu',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('Chưa tải được tình trạng. Thử lại'),
            ),
          );
        }
        final data = snapshot.data!;
        if (data['preview'] == true) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Đây là dữ liệu minh họa. Đăng nhập và chọn hồ sơ trẻ để xem tình trạng từ số đo đã lưu.',
            ),
          );
        }
        final current = data['current'] as Map?;
        final previous = data['previous'] as Map?;
        final anchor = data['anchor'] as Map?;
        final anchorDate = DateTime.tryParse(
          anchor?['measuredOn']?.toString() ?? '',
        );
        final recent =
            anchorDate == null ||
            DateUtils.dateOnly(DateTime.now()).difference(anchorDate).inDays <=
                1;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (current != null)
              _result(current)
            else if (widget.kind == 'bmi')
              _missingBmi(data, anchorDate, recent)
            else ...[
              Text(
                'Chưa có số đo vòng đầu',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ghi vòng đầu để xem nhận xét theo tuổi và giới tính.',
              ),
              if (anchor != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${_selectedId == null ? 'Số đo gần nhất' : 'Lần đo đang xem'}: ${trackingDate(anchorDate!)}',
                  ),
                ),
              const SizedBox(height: 20),
              if (widget.repository.canEdit)
                FilledButton(
                  onPressed: _updateHeadMeasurement,
                  child: Text(recent ? 'Bổ sung số đo' : 'Ghi số đo mới'),
                ),
            ],
            if (current != null && current['status'] != 'READY')
              TextButton(onPressed: _reload, child: const Text('Thử tính lại')),
            if (previous != null && widget.kind != 'bmi')
              _result(previous, previous: true),
          ],
        );
      },
    ),
  );
}
