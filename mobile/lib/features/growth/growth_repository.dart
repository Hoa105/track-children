import 'package:flutter/material.dart';

import 'growth_models.dart';
export 'growth_models.dart';

abstract class GrowthRepository {
  bool get canEdit => true;
  String? get childLabel => null;
  Map<String, dynamic>? get pairingInfo => null;
  DateTime? get dateOfBirth => null;

  Future<void> refreshMeasurements() async {}

  Future<List<GrowthMeasurementDraft>> measurements(GrowthMetric metric) =>
      Future.value(const []);

  Future<void> createRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) => saveMeasurement(metric, draft);

  Future<void> updateRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft original,
    GrowthMeasurementDraft draft,
  ) => Future.error(UnsupportedError('Editing is not available'));

  Future<void> deleteRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) => Future.error(UnsupportedError('Deleting is not available'));

  Future<Map<String, dynamic>> parentAssessment(
    String kind, {
    String? selectedId,
  }) async => {'current': null, 'previous': null, 'preview': true};

  Future<void> saveMeasurement(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) => Future.error(UnsupportedError('Saving is not available'));

  Future<void> saveBmiMeasurements({
    required DateTime measuredAt,
    required double weightKg,
    required double heightCm,
    required GrowthMeasurementMethod heightMethod,
  }) => Future.error(
    UnsupportedError('Saving BMI measurements is not available'),
  );
}

class MockGrowthRepository extends GrowthRepository {
  final List<GrowthMeasurementDraft> _weights = [
    GrowthMeasurementDraft(value: 3.2, measuredAt: DateTime(2024, 5, 15)),
    GrowthMeasurementDraft(value: 6.7, measuredAt: DateTime(2024, 9, 15)),
    GrowthMeasurementDraft(value: 7.6, measuredAt: DateTime(2024, 12, 15)),
    GrowthMeasurementDraft(value: 7.7, measuredAt: DateTime(2025, 1, 15)),
    GrowthMeasurementDraft(value: 8, measuredAt: DateTime(2025, 2, 15)),
    GrowthMeasurementDraft(value: 8.2, measuredAt: DateTime(2025, 3, 15)),
    GrowthMeasurementDraft(value: 8.5, measuredAt: DateTime(2025, 4, 15)),
  ];

  final List<GrowthMeasurementDraft> _lengths = [
    GrowthMeasurementDraft(
      value: 50,
      measuredAt: DateTime(2024, 5, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 64,
      measuredAt: DateTime(2024, 9, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 68.5,
      measuredAt: DateTime(2024, 12, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 70,
      measuredAt: DateTime(2025, 1, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 72,
      measuredAt: DateTime(2025, 2, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 73.5,
      measuredAt: DateTime(2025, 3, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 75,
      measuredAt: DateTime(2025, 4, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
  ];

  final List<GrowthMeasurementDraft> _heads = [
    GrowthMeasurementDraft(value: 43.5, measuredAt: DateTime(2025, 1, 15)),
    GrowthMeasurementDraft(value: 44, measuredAt: DateTime(2025, 2, 15)),
    GrowthMeasurementDraft(value: 44.2, measuredAt: DateTime(2025, 3, 15)),
    GrowthMeasurementDraft(value: 45, measuredAt: DateTime(2025, 4, 15)),
  ];

  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);

  List<GrowthMeasurementDraft> _entries(GrowthMetric metric) =>
      switch (metric) {
        GrowthMetric.weight => _weights,
        GrowthMetric.lengthHeight => _lengths,
        GrowthMetric.headCircumference => _heads,
      };

  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => List.unmodifiable(_entries(metric));

  @override
  Future<void> createRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    if (_entries(
      metric,
    ).any((entry) => DateUtils.isSameDay(entry.measuredAt, draft.measuredAt))) {
      throw StateError('MEASUREMENT_EXISTS');
    }
    await saveMeasurement(metric, draft);
  }

  @override
  Future<void> updateRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft original,
    GrowthMeasurementDraft draft,
  ) async {
    final entries = _entries(metric);
    if (entries.any(
      (entry) =>
          !identical(entry, original) &&
          DateUtils.isSameDay(entry.measuredAt, draft.measuredAt),
    )) {
      throw StateError('MEASUREMENT_EXISTS');
    }
    if (!entries.contains(original)) throw StateError('RESOURCE_NOT_FOUND');
    await saveMeasurement(metric, draft);
    if (!DateUtils.isSameDay(original.measuredAt, draft.measuredAt)) {
      entries.remove(original);
    }
  }

  @override
  Future<void> deleteRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    if (!_entries(metric).remove(draft)) {
      throw StateError('RESOURCE_NOT_FOUND');
    }
  }

  @override
  Future<void> saveMeasurement(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    if (metric == GrowthMetric.lengthHeight && draft.method == null) {
      throw ArgumentError('Measurement method is required');
    }
    _save(_entries(metric), draft);
  }

  @override
  Future<void> saveBmiMeasurements({
    required DateTime measuredAt,
    required double weightKg,
    required double heightCm,
    required GrowthMeasurementMethod heightMethod,
  }) async {
    _save(
      _weights,
      GrowthMeasurementDraft(value: weightKg, measuredAt: measuredAt),
    );
    _save(
      _lengths,
      GrowthMeasurementDraft(
        value: heightCm,
        measuredAt: measuredAt,
        method: heightMethod,
      ),
    );
  }

  void _save(
    List<GrowthMeasurementDraft> entries,
    GrowthMeasurementDraft draft,
  ) {
    final day = DateUtils.dateOnly(draft.measuredAt);
    if (!draft.value.isFinite ||
        draft.value <= 0 ||
        day.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      throw ArgumentError('Invalid measurement');
    }
    entries
      ..removeWhere((entry) => DateUtils.isSameDay(entry.measuredAt, day))
      ..add(
        GrowthMeasurementDraft(
          value: draft.value,
          measuredAt: day,
          method: draft.method,
        ),
      )
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }
}
