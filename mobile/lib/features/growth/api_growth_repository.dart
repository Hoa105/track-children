import '../../services/auth_service.dart';
import '../../services/demo_store.dart';
import 'growth_repository.dart';
import 'remote_growth_repository.dart';

class _GrowthChildCache {
  Future<GrowthDocument>? tracking;
  final Map<String, Future<Map<String, dynamic>>> assessments = {};
  bool canEdit = false;
  String? childLabel;
  String? gender;
  DateTime? birth;

  void clear() {
    tracking = null;
    assessments.clear();
  }
}

class ApiGrowthRepository extends GrowthRepository {
  ApiGrowthRepository({RemoteGrowthRepository? remote})
    : remote =
          remote ??
          RemoteGrowthRepository(
            DemoStore.instance.serverChildId(
                  DemoStore.instance.child?['id'] as String? ?? '',
                ) ??
                '',
          ),
      _gender = DemoStore.instance.child?['gender']?.toString(),
      _birth = DateTime.tryParse(
        DemoStore.instance.child?['date_of_birth']?.toString() ?? '',
      ) {
    final cached = _cache;
    if (cached != null) {
      _canEdit = cached.canEdit;
      _childLabel = cached.childLabel;
      _gender = cached.gender ?? _gender;
      _birth = cached.birth ?? _birth;
      _tracking = cached.tracking;
    }
  }

  static final Map<String, _GrowthChildCache> _sharedCaches = {};

  static void clearSharedCache() => _sharedCaches.clear();

  _GrowthChildCache? get _cache {
    final owner = AuthService.instance.user?['id']?.toString();
    if (owner == null || owner.isEmpty || remote.childId.isEmpty) return null;
    return _sharedCaches.putIfAbsent(
      '$owner:${remote.childId}',
      _GrowthChildCache.new,
    );
  }

  final RemoteGrowthRepository remote;
  Future<GrowthDocument>? _tracking;
  final Map<String, Future<Map<String, dynamic>>> _localAssessments = {};
  bool _canEdit = false;
  String? _childLabel;
  String? _gender;
  DateTime? _birth;

  void _invalidateCache() {
    _tracking = null;
    _localAssessments.clear();
    _cache?.clear();
  }

  void _syncProfile(GrowthDocument doc) {
    _birth = DateTime.tryParse(doc.child['dateOfBirth']?.toString() ?? '');
    _canEdit = doc.canEdit;
    _childLabel = doc.child['fullName']?.toString();
    final rawSex = (doc.child['sex'] ?? doc.child['gender'])?.toString();
    if (rawSex != null && rawSex.isNotEmpty) _gender = rawSex;
    final cached = _cache;
    if (cached != null) {
      cached.birth = _birth;
      cached.canEdit = _canEdit;
      cached.childLabel = _childLabel;
      cached.gender = _gender;
    }
  }

  @override
  bool get canEdit => _cache?.canEdit ?? _canEdit;

  @override
  String? get childId => remote.childId.isEmpty ? null : remote.childId;

  @override
  String? get childLabel => _cache?.childLabel ?? _childLabel;

  @override
  String? get childGender => _cache?.gender ?? _gender;

  @override
  DateTime? get dateOfBirth => _cache?.birth ?? _birth;

  @override
  bool get hasCachedData =>
      (_cache?.tracking ?? _tracking) != null &&
      ['bmi', 'head'].every(
        (kind) => (_cache?.assessments ?? _localAssessments).containsKey(kind),
      );

  Future<GrowthDocument> _trackingData() {
    if (!remote.isCurrentContext) {
      return Future.error(AuthException('SESSION_CHANGED', {}));
    }
    final cached = _cache;
    final existing = cached?.tracking ?? _tracking;
    if (existing != null) return existing;
    late final Future<GrowthDocument> future;
    future = remote.tracking().then(
      (doc) {
        _syncProfile(doc);
        return doc;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_tracking, future)) _tracking = null;
        if (identical(cached?.tracking, future)) cached?.tracking = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _tracking = future;
    if (cached != null) cached.tracking = future;
    return future;
  }

  @override
  Future<void> refreshMeasurements({bool force = false}) async {
    if (force) _invalidateCache();
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
    _invalidateCache();
  }

  @override
  Future<void> updateRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft original,
    GrowthMeasurementDraft draft,
  ) async {
    if (original.id == null) throw StateError('Missing measurement ID');
    await remote.updateRecord(original.id!, _recordBody(metric, draft));
    _invalidateCache();
  }

  @override
  Future<void> deleteRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    if (draft.id == null) throw StateError('Missing measurement ID');
    await remote.delete(draft.id!);
    _invalidateCache();
  }

  @override
  Future<Map<String, dynamic>> parentAssessment(
    String kind, {
    String? selectedId,
    bool force = false,
  }) {
    if (!remote.isCurrentContext) {
      return Future.error(AuthException('SESSION_CHANGED', {}));
    }
    if (selectedId != null) {
      return remote.assessment(kind, selectedId: selectedId).then((doc) {
        _syncProfile(doc);
        return doc.data;
      });
    }
    final store = _cache?.assessments ?? _localAssessments;
    if (force) store.remove(kind);
    final existing = store[kind];
    if (existing != null) return existing;
    late final Future<Map<String, dynamic>> future;
    future = remote.assessment(kind).then(
      (doc) {
        _syncProfile(doc);
        return doc.data;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(store[kind], future)) store.remove(kind);
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    store[kind] = future;
    return future;
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
    _invalidateCache();
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
    _invalidateCache();
  }
}
