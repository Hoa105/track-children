import '../config/local_backend_config.dart';

/// Backend base URL. Override with `--dart-define=API_BASE_URL=http://<ip>:8000`
/// (thiết bị thật cần IP LAN của máy chạy backend).
String get apiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  return localMobileApiBaseUrl;
}

/// Host-only URL (no `/api/v1`) for the routes still mounted at the backend root:
/// /children/{id}/diary, vaccinations, activities, /me, /dev/profiles.
/// Auth, growth and teeth use [apiBaseUrl] (`/api/v1`).
String get rootApiBaseUrl {
  final url = apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  return url.endsWith('/api/v1')
      ? url.substring(0, url.length - '/api/v1'.length)
      : url;
}

/// Local DemoStore ids → uuid seeded by `python -m app.seed.demo` (backend/app/seed/demo.py).
/// Accounts / children created on the device get a uuid generated once and are
/// registered through PUT /dev/profiles before syncing (DemoStore._serverIds).
const demoServerIds = <String, String>{
  'parent_mother': '00000000-0000-4000-8000-000000000001',
  'parent_father': '00000000-0000-4000-8000-000000000002',
  'child_an': '00000000-0000-4000-8000-000000000101',
  'child_linh': '00000000-0000-4000-8000-000000000102',
  'child_minh': '00000000-0000-4000-8000-000000000103',
};
