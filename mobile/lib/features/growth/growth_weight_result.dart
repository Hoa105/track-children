import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_visuals.dart';

/// Checkpoint 4: review the actual draft; saving updates the shared mock store.
class GrowthWeightResultScreen extends StatefulWidget {
  const GrowthWeightResultScreen({
    required this.draft,
    required this.repository,
    this.easyReadMode = false,
    this.metric = GrowthMetric.weight,
    super.key,
  });
  final GrowthMeasurementDraft draft;
  final GrowthRepository repository;
  final GrowthMetric metric;
  final bool easyReadMode;

  @override
  State<GrowthWeightResultScreen> createState() =>
      _GrowthWeightResultScreenState();
}

class _GrowthWeightResultScreenState extends State<GrowthWeightResultScreen> {
  Color get _accent => growthUpdateAccent(widget.metric);
  late final Future<GrowthMeasurementDraft?> _previous;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _previous = widget.repository.measurementBefore(
      widget.metric,
      widget.draft.measuredAt,
    );
    _previous.ignore();
  }

  void _close() => Navigator.of(context).popUntil(
    (route) =>
        route.isFirst ||
        !(route.settings.name == '/growth/update-selector' ||
            GrowthMetric.values.any(
              (metric) =>
                  route.settings.name == '/growth/${metric.routeKey}-input' ||
                  route.settings.name == '/growth/${metric.routeKey}-result',
            )),
  );

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveMeasurement(widget.metric, widget.draft);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Chưa lưu được số đo. Bạn thử lại nhé.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final easy = widget.easyReadMode;
    final large = MediaQuery.textScalerOf(context).scale(20) > 30;
    final date = widget.draft.measuredAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: Colors.white,
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Nunito',
          bodyColor: const Color(0xFF172A4B),
          displayColor: const Color(0xFF172A4B),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: _accent),
      ),
      child: Builder(
        builder: (context) => PopScope(
          canPop: !_saving,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              foregroundColor: const Color(0xFF172A4B),
              centerTitle: true,
              toolbarHeight: growthMeasurementToolbarHeight(
                context,
                'Cập nhật ${widget.metric.lowerTitle}',
              ),
              leading: IconButton(
                tooltip: _saved ? 'Về tổng quan' : 'Sửa số đo',
                onPressed: _saving
                    ? null
                    : (_saved ? _close : () => Navigator.of(context).pop()),
                icon: const Icon(Icons.chevron_left),
              ),
              title: Text(
                'Cập nhật ${widget.metric.lowerTitle}',
                maxLines: 6,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  tooltip: 'Đóng kết quả',
                  onPressed: _saving ? null : _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GrowthMeasurementSteps(
                            activeStep: _saved ? 3 : 2,
                            accent: _accent,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: GrowthAsset(
                              growthUpdateSmile(widget.metric),
                              size: easy ? 100 : 120,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _saved
                                ? 'Đã lưu ${widget.metric.lowerTitle} mới!'
                                : 'Đã cập nhật ${widget.metric.lowerTitle} mới!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: easy ? 22 : 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: Text(
                                  '${formatGrowthValue(widget.draft.value)} ${widget.metric.unit}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: easy ? 36 : 32,
                                    color: _accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (!easy)
                                const Positioned(
                                  right: 16,
                                  child: GrowthAsset('heart', size: 20),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ngày đo: $dateText',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: easy ? 18 : 14,
                              color: const Color(0xFF62738D),
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (widget.metric == GrowthMetric.lengthHeight)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                widget.draft.method ==
                                        GrowthMeasurementMethod.standing
                                    ? 'Cách đo: Chiều cao đứng'
                                    : 'Cách đo: Chiều dài nằm',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: easy ? 18 : 14),
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!easy)
                                Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: GrowthAsset(
                                    growthUpdateSmile(widget.metric),
                                    size: 42,
                                  ),
                                ),
                              Expanded(
                                child: Transform.rotate(
                                  angle: easy ? 0 : -.055,
                                  child: Text(
                                    _saved
                                        ? 'Mỗi cột mốc nhỏ đều là một bước tiến lớn!'
                                        : 'Thêm một cột mốc nhỏ trên hành trình lớn khôn của con!',
                                    style: TextStyle(
                                      fontFamily: easy
                                          ? 'Nunito'
                                          : 'DancingScript',
                                      fontSize: easy ? 20 : 23,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF20365D),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!easy)
                            const Align(
                              alignment: Alignment.centerRight,
                              child: GrowthAsset('overview-arrow', size: 36),
                            ),
                          const SizedBox(height: 20),
                          FutureBuilder<GrowthMeasurementDraft?>(
                            future: _previous,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const LinearProgressIndicator(
                                  semanticsLabel: 'Đang đọc lần đo trước',
                                );
                              }
                              final previous = snapshot.data;
                              final methodsDiffer =
                                  widget.metric == GrowthMetric.lengthHeight &&
                                  previous != null &&
                                  previous.method != widget.draft.method;
                              final change = previous == null || methodsDiffer
                                  ? null
                                  : double.parse(
                                      (widget.draft.value - previous.value)
                                          .toStringAsFixed(3),
                                    );
                              final amount = change == null
                                  ? ''
                                  : widget.metric == GrowthMetric.weight
                                  ? '${(change.abs() * 1000).round()} g'
                                  : '${formatGrowthValue(change.abs())} cm';
                              final delta = methodsDiffer
                                  ? 'Khác cách đo'
                                  : change == null
                                  ? 'Chưa có lần đo trước'
                                  : change == 0
                                  ? 'Không đổi so với lần trước'
                                  : '${change > 0 ? 'Tăng' : 'Giảm'} $amount';
                              final difference = Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GrowthAsset(
                                    change == null || change == 0
                                        ? widget.metric.asset
                                        : change > 0
                                        ? 'arrow-up'
                                        : 'arrow-down',
                                    size: 30,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Transform.rotate(
                                      angle: easy ? 0 : -.12,
                                      child: CustomPaint(
                                        painter: const GrowthNotePaperPainter(),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            14,
                                            14,
                                            18,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                snapshot.hasError
                                                    ? 'Chưa tải được lần đo trước'
                                                    : delta,
                                                style: TextStyle(
                                                  fontFamily: easy
                                                      ? 'Nunito'
                                                      : 'DancingScript',
                                                  fontSize: easy ? 20 : 22,
                                                  fontWeight: easy
                                                      ? FontWeight.w800
                                                      : FontWeight.w700,
                                                  height: 1.2,
                                                  color: const Color(
                                                    0xFF20365D,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                methodsDiffer
                                                    ? 'Chưa so sánh mức thay đổi.'
                                                    : previous == null
                                                    ? 'Chưa đủ dữ liệu so sánh.'
                                                    : _relativeMeasurementInterval(
                                                        previous.measuredAt,
                                                        widget.draft.measuredAt,
                                                      ),
                                                style: TextStyle(
                                                  fontFamily: easy
                                                      ? 'Nunito'
                                                      : 'DancingScript',
                                                  fontSize: easy ? 18 : 16,
                                                  height: 1.3,
                                                  color: const Color(
                                                    0xFF20365D,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                              final velocity = Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const GrowthAsset('overview-chart', size: 30),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Transform.rotate(
                                      angle: easy ? 0 : -.12,
                                      child: CustomPaint(
                                        painter: const GrowthNotePaperPainter(),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            14,
                                            14,
                                            18,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Chưa có tham chiếu',
                                                style: TextStyle(
                                                  fontFamily: easy
                                                      ? 'Nunito'
                                                      : 'DancingScript',
                                                  fontSize: easy ? 20 : 22,
                                                  fontWeight: easy
                                                      ? FontWeight.w800
                                                      : FontWeight.w700,
                                                  height: 1.2,
                                                  color: const Color(
                                                    0xFF20365D,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'tốc độ tăng trưởng',
                                                style: TextStyle(
                                                  fontFamily: easy
                                                      ? 'Nunito'
                                                      : 'DancingScript',
                                                  fontSize: easy ? 18 : 16,
                                                  height: 1.3,
                                                  color: const Color(
                                                    0xFF20365D,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                              return LayoutBuilder(
                                builder: (context, constraints) =>
                                    easy || large || constraints.maxWidth < 300
                                    ? Column(
                                        children: [
                                          difference,
                                          const SizedBox(height: 20),
                                          velocity,
                                        ],
                                      )
                                    : Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: difference),
                                          const SizedBox(width: 12),
                                          Expanded(child: velocity),
                                        ],
                                      ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Chưa có dữ liệu WHO để đánh giá tình trạng ${widget.metric.lowerTitle}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: easy ? 18 : 13,
                              height: 1.4,
                              color: const Color(0xFF62738D),
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFFB87921),
                                  ),
                                ),
                              ),
                            ),
                          if (_saved)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  'Đã lưu số đo trong phiên này.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _accent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Biểu đồ chi tiết sẽ được triển khai sau khi duyệt giao diện này.',
                                        ),
                                      ),
                                    ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF20365D),
                            side: const BorderSide(color: Color(0xFF627C94)),
                            minimumSize: Size.fromHeight(easy ? 56 : 44),
                          ),
                          child: const Text(
                            'Xem biểu đồ chi tiết',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _saving ? null : (_saved ? _close : _save),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            minimumSize: Size.fromHeight(easy ? 60 : 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_saving)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              if (!_saving)
                                Icon(
                                  _saved ? Icons.arrow_back : Icons.check,
                                  size: 22,
                                ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _saving
                                      ? 'Đang lưu…'
                                      : _saved
                                      ? 'Về tổng quan'
                                      : 'Lưu kết quả',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

String _relativeMeasurementInterval(DateTime previous, DateTime current) {
  var months =
      (current.year - previous.year) * 12 + current.month - previous.month;
  if (current.day < previous.day) months--;
  if (months > 0) return 'so với $months tháng trước';
  final days = DateTime.utc(current.year, current.month, current.day)
      .difference(DateTime.utc(previous.year, previous.month, previous.day))
      .inDays;
  return days > 0 ? 'so với $days ngày trước' : 'so với lần đo cùng ngày';
}
