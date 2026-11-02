import '../../services/demo_store.dart';
import 'growth_repository.dart';
import 'remote_growth_repository.dart';

class ApiGrowthRepository extends GrowthRepository {
  ApiGrowthRepository({RemoteGrowthRepository? remote})
    : remote =
          remote ??
          RemoteGrowthRepository(
            DemoStore.instance.child?['id'] as String? ?? '',
          ),
      _birth = DateTime.tryParse(
        DemoStore.instance.child?['date_of_birth']?.toString() ?? '',
      );

  final RemoteGrowthRepository remote;
  Future<GrowthDocument>? _tracking;
  bool _canEdit = false;
  String? _childLabel;
  DateTime? _birth;

  @override
  bool get canEdit => _canEdit;

  @override
  String? get childLabel => _childLabel;

  @override
  DateTime? get dateOfBirth => _birth;

  Future<GrowthDocument> _trackingData() =>
      _tracking ??= remote.tracking().then((doc) {
        _birth = DateTime.tryParse(doc.child['dateOfBirth']?.toString() ?? '');
        _canEdit = doc.canEdit;
        _childLabel = doc.child['fullName']?.toString();
        return doc;
      });

  @override
  Future<void> refreshMeasurements() async {
    _tracking = null;
    await _trackingData();
  }

  String _key(GrowthMetric metric) => switch (metric) {
    GrowthMetric.weight => 'weight',
    GrowthMetric.lengthHeight => 'height',
    GrowthMetric.headCircumference => 'head_circumference',
  };

  String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _recordBody(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) => {
    'value': draft.value,
    'measuredOn': _day(draft.measuredAt),
    if (metric == GrowthMetric.lengthHeight)
      'measurePosition': draft.method == GrowthMeasurementMethod.recumbent
          ? 'lying'
          : 'standing',
  };

  @override
  Future<void> createRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    await remote.createRecord({
      'metric': _key(metric),
      ..._recordBody(metric, draft),
    });
    _tracking = null;
  }

  @override
  Future<void> updateRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft original,
    GrowthMeasurementDraft draft,
  ) async {
    if (original.id == null) throw StateError('Missing measurement ID');
    await remote.updateRecord(original.id!, _recordBody(metric, draft));
    _tracking = null;
  }

  @override
  Future<void> deleteRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    if (draft.id == null) throw StateError('Missing measurement ID');
    await remote.delete(draft.id!);
    _tracking = null;
  }

  @override
  Future<Map<String, dynamic>> parentAssessment(
    String kind, {
    String? selectedId,
  }) async {
    final doc = await remote.assessment(kind, selectedId: selectedId);
    _birth = DateTime.tryParse(doc.child['dateOfBirth']?.toString() ?? '');
    _canEdit = doc.canEdit;
    _childLabel = doc.child['fullName']?.toString();
    return doc.data;
  }

  @override
  Future<List<GrowthMeasurementDraft>> measurements(GrowthMetric metric) async {
    final doc = await _trackingData();
    return [
      for (final row
          in doc
              .list('measurements')
              .where((row) => row['metric'] == _key(metric)))
        GrowthMeasurementDraft(
          id: row['id']?.toString(),
          value: (row['value'] as num).toDouble(),
          measuredAt: DateTime.parse(row['measuredOn'] as String),
          method: row['measurePosition'] == 'lying'
              ? GrowthMeasurementMethod.recumbent
              : row['measurePosition'] == 'standing'
              ? GrowthMeasurementMethod.standing
              : null,
        ),
    ];
  }

  @override
  Future<void> saveMeasurement(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    await remote.save(_day(draft.measuredAt), switch (metric) {
      GrowthMetric.weight => {'weightKg': draft.value},
      GrowthMetric.headCircumference => {'headCircumferenceCm': draft.value},
      GrowthMetric.lengthHeight => {
        'height': {
          'value': draft.value,
          'measurePosition': draft.method == GrowthMeasurementMethod.recumbent
              ? 'lying'
              : 'standing',
        },
      },
    });
    _tracking = null;
  }

  @override
  Future<void> saveBmiMeasurements({
    required DateTime measuredAt,
    required double weightKg,
    required double heightCm,
    required GrowthMeasurementMethod heightMethod,
  }) async {
    await remote.save(_day(measuredAt), {
      'weightKg': weightKg,
      'height': {
        'value': heightCm,
        'measurePosition': heightMethod == GrowthMeasurementMethod.recumbent
            ? 'lying'
            : 'standing',
      },
    });
    _tracking = null;
  }
}
