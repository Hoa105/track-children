import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'vaccination_remote.dart';
import 'who_bmi_reference.dart';
import '../models/tooth.dart';
import '../models/activity.dart';

export 'vaccination_remote.dart';

/// Local, fictional test database. Never authenticates against a real service.
/// Vaccination records are the exception: with [vaccinationRemote] set they are
/// saved to the backend first and cached here.
class DemoStore extends ChangeNotifier {
  DemoStore({DateTime? today}) : _data = _fixture(today ?? DateTime.now());
  static DemoStore _instance = DemoStore();
  static DemoStore get instance => _instance;
  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance = DemoStore();
  }

  /// Set in main(); null (as in tests) keeps vaccination records local only.
  static VaccinationRemote? vaccinationRemote;

  static const storageKey = 'synchronized_demo_v1';
  static const password = 'TreXanh123';
  Map<String, dynamic> _data;
  bool _loaded = false;
  Future<void>? _loading;
  Future<void>? _queue;
  Map<String, dynamic> _copy(Map value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  List<Map<String, dynamic>> get _parents =>
      (_data['parents'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _children =>
      (_data['children'] as List).cast<Map<String, dynamic>>();
  bool get signedIn => _data['parentId'] != null;
  Map<String, dynamic> get parent => _copy(
    _parents.firstWhere(
      (p) => p['id'] == _data['parentId'],
      orElse: () => _parents.first,
    ),
  );
  List<Map<String, dynamic>> get children => _children
      .where((c) => c['parentId'] == _data['parentId'])
      .map(_copy)
      .toList();
  Map<String, dynamic>? get child {
    final available = children;
    if (available.isEmpty) return null;
    return available.firstWhere(
      (c) => c['id'] == _data['childId'],
      orElse: () => available.first,
    );
  }

  Map<String, dynamic>? childById(String id) {
    final found = children.where((c) => c['id'] == id);
    return found.isEmpty ? null : found.first;
  }

  String? childIdForName(String name) {
    final match = children.where((c) => c['full_name'] == name);
    return match.isEmpty ? null : match.first['id'] as String;
  }

  Future<void> initialize() =>
      _loaded ? Future.value() : _loading ??= _initialize();
  Future<void> _initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null) _data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _write(void Function(Map<String, dynamic>) change) {
    final previous = _queue;
    final operation = (() async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          /* A failed write must not block later writes. */
        }
      }
      final next = _copy(_data);
      change(next);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, jsonEncode(next))) {
        throw StateError('Không lưu được dữ liệu test');
      }
      _data = next;
      notifyListeners();
    })();
    _queue = operation;
    return operation.whenComplete(() {
      if (identical(_queue, operation)) _queue = null;
    });
  }

  Future<bool> login(String email, String pass) async {
    await initialize();
    final matches = _parents.where(
      (p) =>
          (p['email'] as String).toLowerCase() == email.trim().toLowerCase() &&
          p['password'] == pass,
    );
    if (matches.isEmpty) return false;
    final id = matches.first['id'];
    await _write((d) {
      d['parentId'] = id;
      d['childId'] = null;
    });
    return true;
  }

  Future<void> logout() => _write((d) {
    d['parentId'] = null;
    d['childId'] = null;
  });

  /// Local feature cache for a server-authenticated user, without credentials.
  Future<void> bindAuthenticatedUser(Map<String, dynamic> user) => _write((d) {
    final parents = d['parents'] as List;
    final existing = parents.where((p) => p['id'] == user['id']).firstOrNull;
    parents.removeWhere((p) => p['id'] == user['id']);
    parents.add(<String, dynamic>{
      ...?existing,
      ...user,
      'role': user['relationship'] ?? 'guardian',
      'notifications': existing?['notifications'] ?? true,
      'biometric': existing?['biometric'] ?? false,
    });
    d['parentId'] = user['id'];
    d['childId'] = null;
  });

  Future<void> clearAuthenticatedCache() => _write((d) {
    // Child features are still local: do not delete authored data on logout.
    // Clear active selections; reads remain scoped to the authenticated owner.
    d['parentId'] = null;
    d['childId'] = null;
  });
  Future<void> selectChild(String id) {
    if (childById(id) == null) {
      throw StateError('Hồ sơ không thuộc tài khoản hiện tại');
    }
    return _write((d) => d['childId'] = id);
  }

  Future<void> saveParent(Map<String, Object?> fields) => _write((d) {
    final p = (d['parents'] as List).firstWhere(
      (p) => p['id'] == d['parentId'],
    );
    if ((d['parents'] as List).any(
      (other) =>
          other['id'] != p['id'] &&
          other['email'].toString().toLowerCase() ==
              fields['email'].toString().toLowerCase(),
    )) {
      throw StateError('Email đã được dùng');
    }
    p.addAll(fields);
  });
  Future<void> register(Map<String, Object?> fields) => _write((d) {
    if ((d['parents'] as List).any(
      (p) =>
          p['email'].toString().toLowerCase() ==
          fields['email'].toString().toLowerCase(),
    )) {
      throw StateError('Email đã được dùng');
    }
    final id = 'parent_${DateTime.now().microsecondsSinceEpoch}';
    (d['parents'] as List).add({
      'id': id,
      ...fields,
      'notifications': true,
      'biometric': false,
    });
    d['parentId'] = id;
    d['childId'] = null;
  });
  Future<String> saveChild(String? id, Map<String, Object?> fields) async {
    final childId = id ?? 'child_${DateTime.now().microsecondsSinceEpoch}';
    if (id != null && childById(id) == null) {
      throw StateError('Không có quyền sửa hồ sơ');
    }
    await _write((d) {
      final list = d['children'] as List;
      if (id == null) {
        list.add({
          'id': childId,
          'parentId': d['parentId'],
          'records': [],
          'members': [],
          'pending': [],
          ...fields,
        });
      } else {
        list.firstWhere((c) => c['id'] == id).addAll(fields);
      }
      if (id == null) d['childId'] = childId;
    });
    return childId;
  }

  List<Map<String, dynamic>> records(String id) =>
      ((childById(id)?['records'] ?? []) as List)
          .map((r) => _copy(r as Map))
          .toList();
  Future<void> addRecord(String id, Map<String, dynamic> record) {
    if (childById(id) == null) throw StateError('Không có quyền sửa số đo');
    return _write((d) {
      final c = (d['children'] as List).firstWhere((c) => c['id'] == id);
      (c['records'] as List).add({
        ...record,
        '_sequence': (c['records'] as List).length + 1,
      });
      (c['records'] as List).sort((a, b) {
        final dateOrder = a['date'].toString().compareTo(b['date'].toString());
        return dateOrder != 0
            ? dateOrder
            : ((a['_sequence'] ?? 0) as int).compareTo(
                (b['_sequence'] ?? 0) as int,
              );
      });
    });
  }

  List<Map<String, dynamic>> journalEntries(String childId) {
    final child = childById(childId);
    if (child == null) return [];
    final saved = child['journalEntries'] as List?;
    final legacy = child['journal'] as Map?;
    final entries = saved != null
        ? saved.map((e) => _copy(e as Map)).toList()
        : legacy == null
        ? <Map<String, dynamic>>[]
        : [
            {
              ..._copy(legacy),
              'id': 'legacy_$childId',
              'note': legacy['title'] ?? '',
              'mood': 'Vui vẻ',
              'domains': <String>[],
            },
          ];
    entries.sort(
      (a, b) => b['date'].toString().compareTo(a['date'].toString()),
    );
    return entries;
  }

  Future<void> saveJournalEntry(String childId, Map<String, dynamic> entry) {
    if (childById(childId) == null) {
      throw StateError('Không có quyền sửa nhật ký');
    }
    final entries = journalEntries(childId);
    final value = {...entry, 'childId': childId};
    final index = entries.indexWhere((e) => e['id'] == entry['id']);
    if (index < 0) {
      entries.add(value);
    } else {
      entries[index] = value;
    }
    return _saveJournalEntries(childId, entries);
  }

  Future<void> deleteJournalEntry(String childId, String entryId) {
    if (childById(childId) == null) {
      throw StateError('Không có quyền sửa nhật ký');
    }
    return _saveJournalEntries(
      childId,
      journalEntries(childId)..removeWhere((e) => e['id'] == entryId),
    );
  }

  Future<void> _saveJournalEntries(
    String childId,
    List<Map<String, dynamic>> entries,
  ) {
    entries.sort(
      (a, b) => b['date'].toString().compareTo(a['date'].toString()),
    );
    return saveChild(childId, {
      'journalEntries': entries,
      'journal': entries.isEmpty
          ? null
          : {
              ...entries.first,
              'title': entries.first['note'],
              'category':
                  (entries.first['domains'] as List?)?.join(' · ') ?? 'Nhật ký',
            },
    }).then((_) {});
  }

  Set<String> completedActivities(String childId) => Set<String>.from(
    childById(childId)?['completedActivities'] as List? ?? [],
  );

  Set<String> get favoriteActivities =>
      Set<String>.from(parent['favoriteActivities'] as List? ?? []);

  Future<void> setActivityDone(String childId, String activityId, bool done) {
    if (childById(childId) == null) {
      throw StateError('Không có quyền sửa hồ sơ');
    }
    if (!activityCatalog.any((a) => a.id == activityId)) {
      throw ArgumentError('Hoạt động không tồn tại');
    }
    return _write((d) {
      final child = (d['children'] as List).firstWhere(
        (c) => c['id'] == childId,
      );
      final ids = Set<String>.from(child['completedActivities'] as List? ?? []);
      done ? ids.add(activityId) : ids.remove(activityId);
      child['completedActivities'] = ids.toList();
    });
  }

  Future<void> setActivityFavorite(String activityId, bool favorite) {
    if (!signedIn) throw StateError('Vui lòng đăng nhập');
    if (!activityCatalog.any((a) => a.id == activityId)) {
      throw ArgumentError('Hoạt động không tồn tại');
    }
    final parentId = parent['id'];
    return _write((d) {
      final account = (d['parents'] as List).firstWhere(
        (p) => p['id'] == parentId,
      );
      final ids = Set<String>.from(
        account['favoriteActivities'] as List? ?? [],
      );
      favorite ? ids.add(activityId) : ids.remove(activityId);
      account['favoriteActivities'] = ids.toList();
    });
  }

  Map<String, DateTime> teeth(String id) => {
    for (final r in (childById(id)?['teeth'] ?? []) as List)
      r['toothId'] as String: DateTime.parse(r['date'] as String),
  };

  List<Map<String, dynamic>> vaccinations(String id) =>
      ((childById(id)?['vaccinations'] ?? []) as List)
          .map((r) => _copy(r as Map))
          .toList();

  Future<void> saveVaccination(String id, Map<String, dynamic> record) {
    return saveVaccinations(id, [record]);
  }

  Future<void> saveVaccinations(String id, List<Map<String, dynamic>> records) {
    final child = childById(id);
    if (child == null) throw StateError('Không có quyền sửa hồ sơ');
    final dob = DateTime.parse(child['date_of_birth'] as String);
    final now = DateTime.now();
    final ids = <String>{};
    for (final record in records) {
      if (!ids.add(record['id'] as String)) {
        throw ArgumentError('Mũi tiêm bị trùng');
      }
      final date = DateTime.parse(record['date'] as String);
      if (date.isBefore(DateTime(dob.year, dob.month, dob.day)) ||
          (record['given'] == true &&
              date.isAfter(DateTime(now.year, now.month, now.day)))) {
        throw ArgumentError('Ngày tiêm không hợp lệ');
      }
    }
    return _pushVaccinations(
      id,
      (remote, account) => remote.save(account, records),
    ).then(
      (_) => _write((d) {
        final c = (d['children'] as List).firstWhere((c) => c['id'] == id);
        final list = c.putIfAbsent('vaccinations', () => <dynamic>[]) as List;
        list.removeWhere((r) => ids.contains(r['id']));
        list.addAll(records.map((record) => Map<String, dynamic>.from(record)));
      }),
    );
  }

  Future<void> removeVaccination(String id, String doseId) {
    if (childById(id) == null) throw StateError('Không có quyền sửa hồ sơ');
    return _pushVaccinations(
      id,
      (remote, account) => remote.remove(account, doseId),
    ).then(
      (_) => _write((d) {
        final c = (d['children'] as List).firstWhere((c) => c['id'] == id);
        (c['vaccinations'] as List?)?.removeWhere((r) => r['id'] == doseId);
      }),
    );
  }

  /// {vaccine code: followed?} — only vaccines whose default the parent changed.
  Map<String, bool> vaccinePlans(String id) => {
    for (final e in ((childById(id)?['vaccinePlans'] ?? {}) as Map).entries)
      e.key as String: e.value as bool,
  };

  /// `null` resets a vaccine to its default.
  Future<void> saveVaccinePlans(String id, Map<String, bool?> plans) {
    if (childById(id) == null) throw StateError('Không có quyền sửa hồ sơ');
    return _pushVaccinations(
      id,
      (remote, account) => remote.savePlans(account, plans),
    ).then(
      (_) => _write((d) {
        final c = (d['children'] as List).firstWhere((c) => c['id'] == id);
        final saved = Map<String, dynamic>.from(
          c['vaccinePlans'] as Map? ?? {},
        );
        plans.forEach(
          (code, value) =>
              value == null ? saved.remove(code) : saved[code] = value,
        );
        c['vaccinePlans'] = saved;
      }),
    );
  }

  /// Backend uuids for local parent / child ids: the seeded demo ids, else a
  /// uuid generated once on this device (registered via VaccinationRemote.link).
  Future<Map<String, String>> _serverIds(List<String> localIds) async {
    String? known(String id) =>
        demoServerIds[id] ?? (_data['serverIds'] as Map?)?[id] as String?;
    if (localIds.any((id) => known(id) == null)) {
      await _write((d) {
        final saved = Map<String, dynamic>.from(d['serverIds'] as Map? ?? {});
        for (final id in localIds) {
          if (demoServerIds[id] == null) saved[id] ??= _uuidV4();
        }
        d['serverIds'] = saved;
      });
    }
    return {for (final id in localIds) id: known(id)!};
  }

  static String _uuidV4() {
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<VaccinationAccount?> _account(String childId) async {
    final parentId = _data['parentId'] as String?;
    final child = childById(childId);
    if (parentId == null || child == null) return null;
    final ids = await _serverIds([parentId, childId]);
    return VaccinationAccount(
      userId: ids[parentId]!,
      childId: ids[childId]!,
      parent: parent,
      child: child,
    );
  }

  /// Saves to the backend first, so a failed request leaves the local book unchanged.
  Future<void> _pushVaccinations(
    String childId,
    Future<void> Function(VaccinationRemote remote, VaccinationAccount account)
    push,
  ) async {
    final remote = vaccinationRemote;
    if (remote == null) return;
    final account = await _account(childId);
    if (account == null) return;
    await remote.link(account);
    await push(remote, account);
  }

  /// Replaces the cached vaccination book and plans with the backend copy.
  ///
  /// The first sync of a child on this device uploads what was saved only
  /// locally (before the backend was reachable). Records the backend rejects
  /// stay on the device (`localOnly`). Returns false when offline (the cache is kept).
  Future<bool> syncVaccinations(String childId) async {
    final remote = vaccinationRemote;
    if (remote == null) return false;
    final account = await _account(childId);
    if (account == null) return false;
    final parentId = _data['parentId'];
    final firstSync = !((_data['vaccinationSynced'] as List?) ?? const [])
        .contains(childId);
    final kept = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> records;
    Map<String, bool> plans;
    try {
      await remote.link(account);
      (records, plans) = await (
        remote.fetch(account),
        remote.fetchPlans(account),
      ).wait;
      if (firstSync) {
        final onServer = {for (final r in records) r['id']};
        final localOnly = vaccinations(childId)
            .where((r) => !onServer.contains(r['id']))
            .toList();
        for (final record in localOnly) {
          try {
            await remote.save(account, [record]);
          } on ApiException catch (e) {
            if (!e.rejected) rethrow;
            kept.add({...record, 'localOnly': true});
          }
        }
        final localPlans = {
          for (final e in vaccinePlans(childId).entries)
            if (!plans.containsKey(e.key)) e.key: e.value,
        };
        if (localPlans.isNotEmpty) await remote.savePlans(account, localPlans);
        if (localOnly.isNotEmpty || localPlans.isNotEmpty) {
          (records, plans) = await (
            remote.fetch(account),
            remote.fetchPlans(account),
          ).wait;
        }
      }
    } catch (_) {
      return false;
    }
    if (_data['parentId'] != parentId || childById(childId) == null) {
      return false;
    }
    await _write((d) {
      final c = (d['children'] as List).firstWhere((c) => c['id'] == childId);
      final stayLocal = [
        ...(c['vaccinations'] as List? ?? const []).where(
          (r) => r['localOnly'] == true,
        ),
        ...kept,
      ];
      final serverIds = {for (final r in records) r['id']};
      c['vaccinations'] = [
        ...records,
        ...stayLocal.where((r) => !serverIds.contains(r['id'])),
      ];
      c['vaccinePlans'] = plans;
      final synced = Set<String>.from(d['vaccinationSynced'] as List? ?? []);
      d['vaccinationSynced'] = (synced..add(childId)).toList();
    });
    return true;
  }

  Future<void> saveTooth(String id, String toothId, DateTime date) {
    final child = childById(id);
    if (child == null) throw StateError('Không có quyền sửa hồ sơ');
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final dob = DateTime.parse(child['date_of_birth'] as String);
    if (!PrimaryTooth.all.any((t) => t.id == toothId) ||
        day.isBefore(DateTime(dob.year, dob.month, dob.day)) ||
        day.isAfter(DateTime(now.year, now.month, now.day))) {
      throw ArgumentError('Ngày mọc hoặc vị trí răng không hợp lệ');
    }
    return _write((d) {
      final c = (d['children'] as List).firstWhere((c) => c['id'] == id);
      final records = c.putIfAbsent('teeth', () => <dynamic>[]) as List;
      records.removeWhere((r) => r['toothId'] == toothId);
      records.add({'toothId': toothId, 'date': day.toIso8601String()});
    });
  }

  Future<void> removeTooth(String id, String toothId) {
    if (childById(id) == null) throw StateError('Không có quyền sửa hồ sơ');
    return _write((d) {
      final c = (d['children'] as List).firstWhere((c) => c['id'] == id);
      (c['teeth'] as List?)?.removeWhere((r) => r['toothId'] == toothId);
    });
  }

  Future<void> saveSharing(
    String id,
    List<Map<String, dynamic>> members,
    List<String> pending,
  ) => saveChild(id, {'members': members, 'pending': pending}).then((_) {});
  String ageLabel(Map<String, dynamic> c) =>
      '${WhoBmiReference.ageMonths(DateTime.parse(c['date_of_birth'] as String), DateTime.now())} tháng';
  double? latest(String id, int metric) {
    final found = records(id).where((r) => r['v$metric'] != null);
    return found.isEmpty ? null : (found.last['v$metric'] as num).toDouble();
  }

  Future<void> resetFixtures() async {
    final next = _fixture(DateTime.now());
    await _write((d) {
      d.clear();
      d.addAll(next);
    });
  }

  static Map<String, dynamic> _fixture(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    Map<String, dynamic> baby(
      String id,
      String parent,
      String name,
      String gender,
      int months,
      List<List<double>> measures,
    ) {
      final birthMonth = DateTime(today.year, today.month - months);
      final birth = DateTime(
        birthMonth.year,
        birthMonth.month,
        today.day.clamp(
          1,
          DateTime(birthMonth.year, birthMonth.month + 1, 0).day,
        ),
      );
      return {
        'id': id,
        'parentId': parent,
        'full_name': name,
        'gender': gender,
        'date_of_birth': birth.toIso8601String(),
        'gestational_weeks': 40,
        'birth_weight_kg': 3.2,
        'teeth': [
          for (final t in PrimaryTooth.all)
            if (t.eruptionMonths.$1 <= months)
              {
                'toothId': t.id,
                'date': DateTime(
                  birth.year,
                  birth.month + t.eruptionMonths.$1,
                  birth.day,
                ).toIso8601String(),
              },
        ],
        'care': {
          'Lượng sữa': months < 12 ? '3/5 bữa' : '2/3 bữa',
          'Tiêm chủng': months < 12 ? 'Còn 1 mũi' : 'Đã cập nhật',
          'Mọc răng': months < 12 ? '2 răng' : '16 răng',
          'Hoạt động': months < 12 ? 'Đạt 2/5' : 'Đạt 4/5',
          'Nhật ký': '1 ghi chú',
        },
        'journal': {
          'childId': id,
          'title': months < 12 ? '$name tập bò' : '$name tự xúc ăn',
          'category': 'Phát triển',
          'date': today.toIso8601String(),
        },
        'records': List.generate(
          measures.length,
          (i) => {
            'date': today
                .subtract(Duration(days: (measures.length - 1 - i) * 28))
                .toIso8601String(),
            'v0': measures[i][0],
            'v1': measures[i][1],
            'v2': measures[i][2],
          },
        ),
        'members': [
          {
            'name': 'Lê Thị Mai',
            'role': 'Bà ngoại',
            'contact': 'ba.mai@example.test',
            'avatar': 'M',
            'permissions': {
              'Lượng sữa': 'view',
              'Tiêm chủng': 'view',
              'Mọc răng': 'view',
              'Nhật ký': 'edit',
              'Hoạt động': 'view',
            },
          },
        ],
        'pending': ['Lời mời · nguoi.cham@example.test'],
      };
    }

    return {
      'version': 1,
      'parentId': null,
      'childId': null,
      'parents': [
        {
          'id': 'parent_mother',
          'fullName': 'Nguyễn Thị Hoa',
          'username': 'hoa_nguyen',
          'email': 'demo@trackchildren.vn',
          'phone': '0900000001',
          'role': 'mother',
          'password': password,
          'notifications': true,
          'biometric': false,
        },
        {
          'id': 'parent_father',
          'fullName': 'Trần Minh Đức',
          'username': 'duc_tran',
          'email': 'bo@trackchildren.vn',
          'phone': '0900000002',
          'role': 'father',
          'password': password,
          'notifications': false,
          'biometric': false,
        },
      ],
      'children': [
        baby('child_an', 'parent_mother', 'Bảo An', 'male', 8, [
          [6.5, 62, 40.5],
          [6.9, 63.5, 41.2],
          [7.2, 65, 41.8],
          [7.6, 66.2, 42.3],
          [7.9, 67.4, 42.8],
          [8.1, 68, 43.2],
          [8.4, 69.5, 43.7],
        ]),
        baby('child_linh', 'parent_mother', 'Gia Linh', 'female', 30, [
          [11.2, 85, 47],
          [11.4, 85.8, 47.2],
          [11.6, 86.6, 47.4],
          [11.9, 87.4, 47.6],
          [12.1, 88.2, 47.8],
          [12.3, 89, 48],
          [12.5, 89.8, 48.2],
        ]),
        baby('child_minh', 'parent_father', 'Minh Khang', 'male', 14, [
          [8, 69, 43],
          [8.2, 70, 43.5],
          [8.5, 71, 44],
          [8.7, 72, 44.4],
          [9, 73, 44.8],
          [9.2, 74, 45.1],
          [9.5, 75, 45.5],
        ]),
      ],
    };
  }
}

mixin DemoStoreBinding<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    DemoStore.instance.addListener(_refreshDemo);
  }

  void _refreshDemo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DemoStore.instance.removeListener(_refreshDemo);
    super.dispose();
  }
}
