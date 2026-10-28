import 'package:flutter/material.dart';

import 'growth_visuals.dart';
import 'growth_weight_input.dart';
import 'growth_repository.dart';

export 'growth_models.dart' show GrowthMetric;

/// Screen 2: choosing a metric never writes a measurement.
class GrowthUpdateSelectorScreen extends StatelessWidget {
  const GrowthUpdateSelectorScreen({
    super.key,
    this.easyReadMode = false,
    this.repository,
  });
  final bool easyReadMode;
  final GrowthRepository? repository;

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
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: growthInk,
          leading: IconButton(
            tooltip: 'Về tổng quan tăng trưởng',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left),
          ),
          centerTitle: true,
          title: const Text(
            'Cập nhật chỉ số',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (viewport.maxHeight - 56).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Chọn chỉ số bạn muốn cập nhật',
                          style: TextStyle(
                            fontSize: easyReadMode ? 20 : 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FutureBuilder<List<GrowthMetricViewData>>(
                          future: repository?.loadOverview(),
                          builder: (context, snapshot) => GrowthUpdateSelector(
                            weightValueText:
                                snapshot.data
                                    ?.where((m) => m.asset == 'weight')
                                    .firstOrNull
                                    ?.value ??
                                '8,5',
                            lengthValueText:
                                snapshot.data
                                    ?.where((m) => m.asset == 'height')
                                    .firstOrNull
                                    ?.value ??
                                '75',
                            headValueText:
                                snapshot.data
                                    ?.where((m) => m.asset == 'head')
                                    .firstOrNull
                                    ?.value ??
                                '45',
                            easyReadMode: easyReadMode,
                            onSelect: (metric) {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  settings: RouteSettings(
                                    name: '/growth/${metric.routeKey}-input',
                                  ),
                                  builder: (_) => GrowthWeightInputScreen(
                                    metric: metric,
                                    easyReadMode: easyReadMode,
                                    repository: repository,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Transform.rotate(
                              angle: easyReadMode ? 0 : -.06,
                              child: CustomPaint(
                                painter: const GrowthNotePaperPainter(),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    24,
                                    28,
                                  ),
                                  child: Text(
                                    'Chỉ mất 1 phút\nđể lưu lại cột mốc\nphát triển của con!',
                                    style: TextStyle(
                                      fontFamily: easyReadMode
                                          ? 'Nunito'
                                          : 'DancingScript',
                                      fontSize: easyReadMode ? 20 : 25,
                                      height: 1.2,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF20365D),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!easyReadMode)
                            const Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Column(
                                children: [
                                  GrowthAsset('bamboo-shoot', size: 64),
                                  SizedBox(height: 12),
                                  GrowthAsset('heart', size: 30),
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
      ),
    ),
  );
}

/// C19, shared metric selector. The caller owns navigation and saving.
class GrowthUpdateSelector extends StatelessWidget {
  const GrowthUpdateSelector({
    required this.onSelect,
    this.easyReadMode = false,
    this.enabled = true,
    this.weightValueText = '8,5',
    this.lengthValueText = '75',
    this.headValueText = '45',
    super.key,
  });
  final ValueChanged<GrowthMetric> onSelect;
  final bool easyReadMode, enabled;
  final String weightValueText, lengthValueText, headValueText;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final entry in [
        (
          GrowthMetric.weight,
          'Cân nặng',
          'Cập nhật cân nặng hiện tại của bé',
          'overview-weight',
          '$weightValueText kg',
        ),
        (
          GrowthMetric.lengthHeight,
          'Chiều dài/chiều cao',
          'Cập nhật chiều dài hoặc chiều cao của bé',
          'overview-height',
          '$lengthValueText cm',
        ),
        (
          GrowthMetric.headCircumference,
          'Vòng đầu',
          'Cập nhật vòng đầu hiện tại của bé',
          'overview-head',
          '$headValueText cm',
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            button: true,
            enabled: enabled,
            label: '${entry.$2}. ${entry.$3}. Số đo gần nhất ${entry.$5}',
            child: ExcludeSemantics(
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE9EDE8)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? () => onSelect(entry.$1) : null,
                  child: Padding(
                    padding: EdgeInsets.all(easyReadMode ? 20 : 16),
                    child: Row(
                      children: [
                        GrowthAsset(entry.$4, size: 46),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.$2,
                                style: TextStyle(
                                  fontSize: easyReadMode ? 20 : 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.$3,
                                style: TextStyle(
                                  fontSize: easyReadMode ? 18 : 14,
                                  height: 1.4,
                                  color: growthMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Gần nhất: ${entry.$5}',
                                style: TextStyle(
                                  fontSize: easyReadMode ? 18 : 13,
                                  color: growthGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          size: 22,
                          color: growthGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
