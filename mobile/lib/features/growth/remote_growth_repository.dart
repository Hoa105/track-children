import '../../services/auth_service.dart';
import '../../services/demo_store.dart';

typedef GrowthTransport = Future<Map<String, dynamic>> Function(
  String method,
  String path, {
  Map<String, dynamic>? body,
});

/// Immutable server snapshot. Domain calculations stay on the server.
class GrowthDocument {
  GrowthDocument(Map<String, dynamic> value)
    : data = _freeze(value) as Map<String, dynamic> {
    if (data['meta'] is! Map ||
        data['child'] is! Map ||
        (data['meta'] as Map)['schemaVersion'] != '1') {
      throw const FormatException('Invalid growth response');
    }
  }
  final Map<String, dynamic> data;
  Map<String, dynamic> get child =>
      Map<String, dynamic>.from(data['child'] as Map);
  bool get canEdit => child['growthAccess'] == 'edit';
  List<Map<String, dynamic>> list(String field) => ((data[field] ?? []) as List)
      .map((x) => Map<String, dynamic>.from(x as Map))
      .toList();
}

dynamic _freeze(dynamic value) => value is Map
    ? Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key.toString(), _freeze(item))),
      )
    : value is List
    ? List<dynamic>.unmodifiable(value.map(_freeze))
    : value;

class RemoteGrowthRepository {
  RemoteGrowthRepository(
    this.childId, {
    GrowthTransport? transport,
    bool Function()? contextIsCurrent,
  }) {
    final owner = AuthService.instance.user?['id'];
    _send = transport ?? AuthService.instance.authorizedRequest;
    _contextCheck =
        contextIsCurrent ??
        (transport != null
            ? () => true
            : () =>
                  owner != null &&
                  AuthService.instance.user?['id'] == owner &&
                  DemoStore.instance.child?['id'] == childId);
  }
  final String childId;
  late final GrowthTransport _send;
  late final bool Function() _contextCheck;
  bool get isCurrentContext => _contextCheck();
  String get base => '/children/$childId/growth';

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!isCurrentContext) throw AuthException('SESSION_CHANGED', {});
    final result = await _send(method, path, body: body);
    if (!isCurrentContext) throw AuthException('SESSION_CHANGED', {});
    return result;
  }

  Future<GrowthDocument> _get(
    String suffix, [
    Map<String, String> query = const {},
  ]) async {
    final uri = Uri(
      path: '$base$suffix',
      queryParameters: query.isEmpty ? null : query,
    );
    final result = GrowthDocument(await _request('GET', uri.toString()));
    if (result.child['id'] != childId) {
      throw const FormatException('Child mismatch');
    }
    return result;
  }

  Future<GrowthDocument> overview() => _get('');
  Future<GrowthDocument> detail(
    String metric, {
    Map<String, String> query = const {},
  }) => _get('/metrics/$metric', query);
  Future<GrowthDocument> velocity(
    String metric, {
    String mode = 'actual',
    int? period,
    Map<String, String> query = const {},
  }) => _get('/metrics/$metric/velocity', {
    ...query,
    'mode': mode,
    if (period != null) 'intervalMonths': '$period',
  });
  Future<GrowthDocument> day(String day) => _get('/days/$day');
  Future<GrowthDocument> save(String day, Map<String, dynamic> body) async {
    final result = await _request('PUT', '$base/days/$day', body: body);
    if (result['measurementSaved'] != true || result['day'] is! Map) {
      throw const FormatException('Invalid save response');
    }
    return GrowthDocument(Map<String, dynamic>.from(result['day'] as Map));
  }

  Future<void> delete(String id) async {
    await _request('DELETE', '$base/measurements/$id');
  }
}
