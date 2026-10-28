import 'package:flutter/material.dart';

import 'growth_visuals.dart';
import 'growth_repository.dart';
export 'growth_repository.dart';
import 'growth_update_selector.dart';
import 'growth_weight_detail.dart';
import 'growth_stature_detail.dart';
import 'growth_head_detail.dart';
import 'growth_bmi_detail.dart';

import '../navigation/app_bottom_navigation_bar.dart';

class GrowthOverview extends StatefulWidget {
  const GrowthOverview({super.key, this.repository, this.onNavigation});
  final GrowthRepository? repository;
  final ValueChanged<String>? onNavigation;
  @override
  State<GrowthOverview> createState() => _GrowthOverviewState();
}

class _GrowthOverviewState extends State<GrowthOverview> {
  late Future<List<GrowthMetricViewData>> _data;
  // A lazy initializer also works for State objects retained by hot reload.
  late final GrowthRepository _repository =
      widget.repository ?? MockGrowthRepository();
  bool _easyRead = false;
  int _months = 3;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = _repository.loadOverview();
    // A retry can fail before the next frame attaches FutureBuilder's listener.
    // Keep the original future for the error UI while handling early errors.
    _data.ignore();
  }

  void _pending(String destination) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$destination sẽ được triển khai sau khi duyệt tổng quan.',
        ),
      ),
    );
  }

  Future<void> _openUpdateSelector() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/growth/update-selector'),
        builder: (_) => GrowthUpdateSelectorScreen(
          easyReadMode: _easyRead,
          repository: _repository,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _openWeightDetail() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/growth/weight-detail'),
        builder: (_) => GrowthWeightDetailScreen(
          repository: _repository,
          easyReadMode: _easyRead,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _openStatureDetail() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/growth/length-detail'),
        builder: (_) => GrowthStatureDetailScreen(
          repository: _repository,
          easyReadMode: _easyRead,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Future<void> _openBmiDetail() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/growth/bmi-detail'),
        builder: (_) => GrowthBmiDetailScreen(
          repository: _repository,
          easyReadMode: _easyRead,
        ),
      ),
    );
    if (mounted) setState(() => _data = _repository.loadOverview());
  }

  Future<void> _openHeadDetail() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/growth/head-detail'),
        builder: (_) => GrowthHeadDetailScreen(
          repository: _repository,
          easyReadMode: _easyRead,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'Nunito',
        bodyColor: growthInk,
        displayColor: growthInk,
      ),
      colorScheme: ColorScheme.fromSeed(seedColor: growthGreen),
    ),
    child: Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: AppBottomNavigationBar(
        selected: 'Theo dõi',
        onTap: (destination) {
          if (destination == 'Theo dõi') return;
          if (destination == 'Tạo ghi chép') {
            _openUpdateSelector();
            return;
          }
          if (widget.onNavigation != null) {
            widget.onNavigation!(destination);
          } else if (destination == 'Trang chủ' &&
              Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            _pending(destination);
          }
        },
      ),
      body: SafeArea(
        child: FutureBuilder<List<GrowthMetricViewData>>(
          future: _data,
          builder: (context, snapshot) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const GrowthAsset('overview-chart', size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tăng trưởng',
                          style: TextStyle(
                            fontSize: _easyRead ? 28 : 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Tùy chọn hiển thị',
                        onSelected: (_) =>
                            setState(() => _easyRead = !_easyRead),
                        itemBuilder: (_) => [
                          CheckedPopupMenuItem(
                            value: 'read',
                            checked: _easyRead,
                            child: const Text('Chế độ dễ đọc'),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz, color: growthInk),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Transform.rotate(
                            angle: _easyRead ? 0 : -0.085,
                            child: CustomPaint(
                              painter: const GrowthNotePaperPainter(),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  24,
                                  24,
                                ),
                                child: Text(
                                  '4 chỉ số chính\ngiúp theo dõi sự lớn khôn\ncủa con mỗi ngày',
                                  style: TextStyle(
                                    fontFamily: _easyRead
                                        ? 'Nunito'
                                        : 'DancingScript',
                                    fontSize: _easyRead ? 20 : 25,
                                    fontWeight: FontWeight.w500,
                                    height: 1.15,
                                    color: const Color(0xFF20365D),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!_easyRead) ...[
                          const SizedBox(width: 12),
                          const GrowthAsset('overview-arrow', size: 48),
                          const GrowthAsset('overview-trend', size: 42),
                        ],
                      ],
                    ),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Đang tải số đo',
                        ),
                      ),
                    )
                  else if (snapshot.hasError)
                    Column(
                      children: [
                        const Text('Chưa tải được số đo.'),
                        TextButton(
                          onPressed: () => setState(_reload),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    )
                  else if (!snapshot.hasData || snapshot.data!.isEmpty)
                    const Column(
                      children: [
                        GrowthAsset('no-measurements', size: 96),
                        Text('Chưa có số đo'),
                      ],
                    )
                  else ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked =
                            constraints.maxWidth < 300 ||
                            _easyRead ||
                            MediaQuery.textScalerOf(context).scale(15) > 21;
                        final tiles = [
                          for (final metric in snapshot.data!)
                            GrowthMetricTile(
                              data: metric,
                              easyRead: _easyRead,
                              onTap: metric.asset == 'weight'
                                  ? _openWeightDetail
                                  : metric.asset == 'height'
                                  ? _openStatureDetail
                                  : metric.asset == 'head'
                                  ? _openHeadDetail
                                  : metric.asset == 'bmi'
                                  ? _openBmiDetail
                                  : () => _pending(
                                      'Chi tiết ${metric.title.toLowerCase()}',
                                    ),
                            ),
                        ];
                        return stacked
                            ? Column(
                                children: [
                                  for (final tile in tiles)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: tile,
                                    ),
                                ],
                              )
                            : Column(
                                children: [
                                  for (var i = 0; i < tiles.length; i += 2)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(child: tiles[i]),
                                            if (i + 1 < tiles.length) ...[
                                              const VerticalDivider(
                                                width: 16,
                                                color: Color(0xFFEEF0EC),
                                              ),
                                              Expanded(child: tiles[i + 1]),
                                            ] else
                                              const Expanded(child: SizedBox()),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: growthGreen,
                      minimumSize: Size.fromHeight(_easyRead ? 60 : 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _openUpdateSelector,
                    child: const Row(
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cập nhật chỉ số mới',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          'Xu hướng gần đây',
                          style: TextStyle(
                            fontSize: _easyRead ? 20 : 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _months,
                          underline: const SizedBox(),
                          borderRadius: BorderRadius.circular(12),
                          items: const [
                            DropdownMenuItem(value: 3, child: Text('3 tháng')),
                            DropdownMenuItem(value: 1, child: Text('1 tháng')),
                          ],
                          onChanged: (value) =>
                              setState(() => _months = value!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label:
                          'Xu hướng số đo trong $_months tháng. Mỗi đường dùng thang riêng; không dùng để đối chiếu WHO.',
                      child: ExcludeSemantics(
                        child: SizedBox(
                          height: 110,
                          child: CustomPaint(
                            painter: _TrendPainter(
                              snapshot.data!,
                              months: _months,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final label
                            in (_months == 3
                                ? ['Th1', 'Th2', 'Th3', 'Hiện tại']
                                : ['Đầu tháng', 'Hiện tại']))
                          Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: growthMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        for (final metric in snapshot.data!)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: metric.color, size: 9),
                              const SizedBox(width: 5),
                              Text(
                                metric.title,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Mỗi chỉ số dùng thang riêng để xem xu hướng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: growthMuted),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class GrowthMetricTile extends StatelessWidget {
  const GrowthMetricTile({
    required this.data,
    required this.onTap,
    this.easyRead = false,
    super.key,
  });
  final GrowthMetricViewData data;
  final VoidCallback onTap;
  final bool easyRead;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${data.title}, ${data.value} ${data.unit}. '
        'Z-score trung bình: ${data.averageZScoreText ?? 'chưa có dữ liệu'}. Mở chi tiết.',
    child: ExcludeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            children: [
              GrowthAsset('overview-${data.asset}', size: 42),
              const SizedBox(height: 8),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: easyRead ? 18 : 15),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.value} ${data.unit}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: easyRead ? 36 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'z ~ ${data.averageZScoreText ?? '__'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: growthMuted),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: data.color),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter([data], sparkline: true),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.metrics, {this.sparkline = false, this.months = 3});
  final List<GrowthMetricViewData> metrics;
  final bool sparkline;
  final int months;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (!sparkline) {
      paint.color = const Color(0xFFEEF0EC);
      for (var i = 0; i < 4; i++) {
        final x = 5 + (size.width - 10) * i / 3;
        canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), paint);
      }
    }
    for (var m = 0; m < metrics.length; m++) {
      final metric = metrics[m];
      final values = months == 1
          ? metric.points.sublist(
              (metric.points.length - 2).clamp(0, metric.points.length),
            )
          : metric.points;
      if (values.length < 2) continue;
      final min = metric.points.reduce((a, b) => a < b ? a : b);
      final max = metric.points.reduce((a, b) => a > b ? a : b);
      final path = Path();
      final points = <Offset>[];
      for (var i = 0; i < values.length; i++) {
        final normalized = max == min ? .5 : (values[i] - min) / (max - min);
        final y = sparkline
            ? size.height - 4 - normalized * (size.height - 8)
            : size.height -
                  10 -
                  (normalized * .55 + m * .15) * (size.height - 16);
        final point = Offset(
          5 + i / (values.length - 1) * (size.width - 10),
          y,
        );
        points.add(point);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      paint
        ..color = metric.color
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;
      for (final point in points) {
        canvas.drawCircle(point, 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.metrics != metrics ||
      oldDelegate.months != months ||
      oldDelegate.sparkline != sparkline;
}
