import 'package:flutter/material.dart';

import 'growth_visuals.dart';
import 'growth_repository.dart';
import 'growth_weight_result.dart';
export 'growth_repository.dart' show GrowthMeasurementDraft;

/// Checkpoint 3: editable in-memory draft, no persistence or WHO calculations.
class GrowthWeightInputScreen extends StatefulWidget {
  const GrowthWeightInputScreen({
    super.key,
    this.easyReadMode = false,
    this.initialDate,
    this.onContinue,
    this.repository,
    this.metric = GrowthMetric.weight,
  });
  final GrowthMetric metric;
  final bool easyReadMode;
  final DateTime? initialDate;
  final ValueChanged<GrowthMeasurementDraft>? onContinue;
  final GrowthRepository? repository;

  @override
  State<GrowthWeightInputScreen> createState() =>
      _GrowthWeightInputScreenState();
}

class _GrowthWeightInputScreenState extends State<GrowthWeightInputScreen> {
  Color get _accent => growthUpdateAccent(widget.metric);
  final _formKey = GlobalKey<FormState>();
  late final _weight = TextEditingController(text: widget.metric.initialValue);
  GrowthMeasurementMethod? get _method {
    final birth = _repository.dateOfBirth;
    if (birth == null || _date.isBefore(DateUtils.dateOnly(birth))) return null;
    final year = birth.year + 2;
    final day = birth.day.clamp(1, DateUtils.getDaysInMonth(year, birth.month));
    final secondBirthday = DateTime(year, birth.month, day);
    return _date.isBefore(secondBirthday)
        ? GrowthMeasurementMethod.recumbent
        : GrowthMeasurementMethod.standing;
  }

  String get _title => widget.metric != GrowthMetric.lengthHeight
      ? widget.metric.title
      : _method == null
      ? widget.metric.title
      : _method == GrowthMeasurementMethod.recumbent
      ? 'Chiều dài'
      : 'Chiều cao';
  String get _lowerTitle => _title.toLowerCase();
  late DateTime _date;
  late final GrowthRepository _repository =
      widget.repository ?? MockGrowthRepository();
  @override
  void initState() {
    super.initState();
    _date = DateUtils.dateOnly(widget.initialDate ?? DateTime(2025, 5, 15));
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  String? _validateWeight(String? input) {
    final raw = (input ?? '').trim();
    if (raw.isEmpty) return 'Nhập $_lowerTitle của bé.';
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(raw) ||
        value == null ||
        !value.isFinite ||
        value <= 0) {
      return 'Nhập số lớn hơn 0, ví dụ ${widget.metric.initialValue}.';
    }
    return null;
  }

  Future<void> _chooseDate() async {
    FocusScope.of(context).unfocus();
    final today = DateUtils.dateOnly(DateTime.now());
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Chọn ngày đo',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      fieldLabelText: 'Ngày đo',
      fieldHintText: 'mm/dd/yyyy',
      errorInvalidText: 'Ngày đo không được ở tương lai.',
    );
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final draft = GrowthMeasurementDraft(
      value: double.parse(_weight.text.trim().replaceAll(',', '.')),
      measuredAt: _date,
      method: widget.metric == GrowthMetric.lengthHeight ? _method : null,
    );
    if (widget.onContinue != null) {
      widget.onContinue!(draft);
    } else {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: RouteSettings(
            name: '/growth/${widget.metric.routeKey}-result',
          ),
          builder: (_) => GrowthWeightResultScreen(
            draft: draft,
            metric: widget.metric,
            repository: _repository,
            easyReadMode: widget.easyReadMode,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final easyRead = widget.easyReadMode;
    final dateText =
        '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Nunito',
          bodyColor: growthInk,
          displayColor: growthInk,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: _accent),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            foregroundColor: growthInk,
            centerTitle: true,
            toolbarHeight: growthMeasurementToolbarHeight(
              context,
              'Cập nhật $_lowerTitle',
            ),
            leading: IconButton(
              tooltip: 'Về chọn chỉ số',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Cập nhật $_lowerTitle',
              maxLines: 6,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: 'Đóng cập nhật',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).popUntil(
                  (route) =>
                      route.isFirst ||
                      (route.settings.name !=
                              '/growth/${widget.metric.routeKey}-input' &&
                          route.settings.name != '/growth/update-selector'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GrowthMeasurementSteps(accent: _accent),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              GrowthAsset(widget.metric.asset, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.metric == GrowthMetric.weight
                                      ? 'Số cân nặng mới'
                                      : '$_title mới',
                                  style: TextStyle(
                                    fontSize: easyRead ? 20 : 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _weight,
                            validator: _validateWeight,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _continue(),
                            style: TextStyle(
                              fontSize: easyRead ? 28 : 24,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              labelText: _title,
                              suffixText: widget.metric.unit,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDCE3DD),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                color: growthInk,
                                size: 26,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Ngày đo',
                                style: TextStyle(
                                  fontSize: easyRead ? 20 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _chooseDate,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: growthInk,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              side: const BorderSide(color: Color(0xFFDCE3DD)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateText,
                                    style: TextStyle(
                                      fontSize: easyRead ? 20 : 16,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!easyRead)
                                const Padding(
                                  padding: EdgeInsets.only(right: 10, top: 16),
                                  child: GrowthAsset('lightbulb', size: 36),
                                ),
                              Expanded(
                                child: Transform.rotate(
                                  angle: easyRead ? 0 : -.055,
                                  child: CustomPaint(
                                    painter: const GrowthNotePaperPainter(),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        22,
                                        24,
                                        28,
                                      ),
                                      child: Text(
                                        widget.metric ==
                                                GrowthMetric.lengthHeight
                                            ? (_method ==
                                                      GrowthMeasurementMethod
                                                          .recumbent
                                                  ? 'Đặt bé nằm thẳng, giữ đầu và chân đúng vị trí để đo chiều dài.'
                                                  : _method ==
                                                        GrowthMeasurementMethod
                                                            .standing
                                                  ? 'Cho bé đứng thẳng, bỏ giày dép và nhìn thẳng khi đo chiều cao.'
                                                  : 'Cập nhật ngày sinh để xác định hướng dẫn đo phù hợp với tuổi.')
                                            : widget.metric.measurementTip,
                                        style: TextStyle(
                                          fontFamily: easyRead
                                              ? 'Nunito'
                                              : 'DancingScript',
                                          fontSize: easyRead ? 20 : 24,
                                          fontWeight: FontWeight.w500,
                                          height: 1.25,
                                          color: const Color(0xFF20365D),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!easyRead)
                            const Align(
                              alignment: Alignment.centerRight,
                              child: GrowthAsset('overview-arrow', size: 48),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: FilledButton(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      minimumSize: Size.fromHeight(easyRead ? 60 : 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tiếp tục',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, size: 26),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
