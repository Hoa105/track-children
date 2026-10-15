import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'who_bmi_reference.dart';

/// Local, fictional test database. Never authenticates against a real service.
class DemoStore extends ChangeNotifier {
  DemoStore({DateTime? today}) : _data = _fixture(today ?? DateTime.now());
  static DemoStore _instance = DemoStore();
  static DemoStore get instance => _instance;
  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance = DemoStore();
  }

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
