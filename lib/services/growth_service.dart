import '../models/growth_record.dart';

abstract class GrowthService {
  Future<List<GrowthMetricSeries>> getSeriesForChild(String childId);
  Future<void> addRecord(GrowthRecord record);
  Future<List<GrowthRecord>> getRecords(String childId, GrowthMetricType type);
}

/// Seeded verbatim from the prototype's `metrics` array
/// (prototype_reference.md § "Growth metrics mock data").
class MockGrowthService implements GrowthService {
  final Map<GrowthMetricType, List<GrowthRecord>> _records = {
    GrowthMetricType.weight: [
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.weight, value: 10.8, percentile: 52, date: DateTime.now()),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.weight, value: 10.5, percentile: 51, date: DateTime.now().subtract(const Duration(days: 30))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.weight, value: 10.1, percentile: 49, date: DateTime.now().subtract(const Duration(days: 60))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.weight, value: 9.4, percentile: 47, date: DateTime.now().subtract(const Duration(days: 90))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.weight, value: 8.1, percentile: 44, date: DateTime.now().subtract(const Duration(days: 120))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.weight, value: 6.8, percentile: 40, date: DateTime.now().subtract(const Duration(days: 150))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.weight, value: 5.2, percentile: 38, date: DateTime.now().subtract(const Duration(days: 180))),
    ],
    GrowthMetricType.height: [
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.height, value: 82, percentile: 48, date: DateTime.now()),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.height, value: 79, percentile: 47, date: DateTime.now().subtract(const Duration(days: 30))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.height, value: 76, percentile: 46, date: DateTime.now().subtract(const Duration(days: 60))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.height, value: 72, percentile: 45, date: DateTime.now().subtract(const Duration(days: 90))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.height, value: 68, percentile: 43, date: DateTime.now().subtract(const Duration(days: 120))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.height, value: 64, percentile: 41, date: DateTime.now().subtract(const Duration(days: 150))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.height, value: 58, percentile: 39, date: DateTime.now().subtract(const Duration(days: 180))),
    ],
    GrowthMetricType.headCircumference: [
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.headCircumference, value: 47, percentile: 55, date: DateTime.now()),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.headCircumference, value: 46, percentile: 54, date: DateTime.now().subtract(const Duration(days: 30))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.headCircumference, value: 45, percentile: 53, date: DateTime.now().subtract(const Duration(days: 60))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.headCircumference, value: 43, percentile: 51, date: DateTime.now().subtract(const Duration(days: 90))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.headCircumference, value: 41, percentile: 49, date: DateTime.now().subtract(const Duration(days: 120))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.headCircumference, value: 39, percentile: 47, date: DateTime.now().subtract(const Duration(days: 150))),
      GrowthRecord(childId: 'c1', metricType: GrowthMetricType.headCircumference, value: 36, percentile: 44, date: DateTime.now().subtract(const Duration(days: 180))),
    ],
  };

  final List<GrowthMetricSeries> _series = const [
    GrowthMetricSeries(
      type: GrowthMetricType.weight,
      currentValueLabel: '10,8',
      percentile: 52,
      axisLabels: ['14kg', '10kg', '6kg'],
      points: [84, 74, 64, 56, 48, 40, 36],
    ),
    GrowthMetricSeries(
      type: GrowthMetricType.height,
      currentValueLabel: '82',
      percentile: 48,
      axisLabels: ['90cm', '78cm', '64cm'],
      points: [88, 78, 68, 58, 50, 42, 38],
    ),
    GrowthMetricSeries(
      type: GrowthMetricType.headCircumference,
      currentValueLabel: '47',
      percentile: 55,
      axisLabels: ['50cm', '46cm', '40cm'],
      points: [80, 66, 54, 46, 40, 34, 30],
    ),
  ];

  @override
  Future<List<GrowthMetricSeries>> getSeriesForChild(String childId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _series;
  }

  @override
  Future<void> addRecord(GrowthRecord record) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _records[record.metricType]!.insert(0, record);
  }

  @override
  Future<List<GrowthRecord>> getRecords(String childId, GrowthMetricType type) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _records[type]!;
  }
}
