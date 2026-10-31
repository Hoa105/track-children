import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_api.dart';
import 'api_config.dart';
import 'journal_api.dart';
import 'journal_media.dart';
import 'vaccination_remote.dart';
import 'video_insight_api.dart';
import 'who_bmi_reference.dart';
import '../models/tooth.dart';
import '../models/activity.dart';
import '../models/video_insight.dart';

export 'vaccination_remote.dart';

/// Local, fictional test database. Never authenticates against a real service.
/// Vaccination records are the exception: with [vaccinationRemote] set they are
/// saved to the backend first and cached here. Diary entries are saved here
/// first and copied to the backend ([journalRemote]).
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

  /// Set in main(); null disables AI comments on diary videos.
  static VideoInsightRemote? videoInsightRemote;

  /// Set in main(); null (as in tests) keeps "Đã làm" / "Yêu thích" local only.
  static ActivityRemote? activityRemote;

  /// Set in main(); null (as in tests) keeps the diary on this device only.
  static JournalRemote? journalRemote;

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

  static List<Map<String, dynamic>> _mediaOf(Map? entry) => [
    for (final m in (entry?['media'] as List? ?? const []))
      Map<String, dynamic>.from(m as Map),
  ];

  /// Photo / video still to be uploaded from this device.
  static bool _mediaPending(Map m) =>
      m['uploaded'] != true && m['rejected'] == null && m['path'] != null;

  /// Id for a new journal photo / video (diary_media.id on the backend).
  static String newMediaId() => _uuidV4();

  Future<void> _removeFiles(Iterable<Map> media) async {
    for (final m in media) {
      if (m['path'] != null) {
        await JournalMediaFiles.instance.remove(m['path'] as String);
      }
    }
  }

  /// Saved on this device first (works offline), then sent to the backend in
  /// the background: the entry, then its photos / videos (`media` items with a
  /// local `path`). Until the backend confirms them the entry keeps
  /// `pendingSync` / the items `uploaded: false`, and [syncJournal] sends them again.
  Future<void> saveJournalEntry(
    String childId,
    Map<String, dynamic> entry,
  ) async {
    if (childById(childId) == null) {
      throw StateError('Không có quyền sửa nhật ký');
    }
    final before = journalEntries(childId)
        .where((e) => e['id'] == entry['id'])
        .firstOrNull;
    final value = {
      ...entry,
      'childId': childId,
      'pendingSync': '${DateTime.now().microsecondsSinceEpoch}',
    };
    await _writeJournal(childId, (entries, _) {
      final index = entries.indexWhere((e) => e['id'] == entry['id']);
      index < 0 ? entries.add(value) : entries[index] = value;
    });
    final kept = {for (final m in _mediaOf(value)) m['id']};
    await _removeFiles(_mediaOf(before).where((m) => !kept.contains(m['id'])));
    unawaited(_pushJournal(childId));
  }

  Future<void> deleteJournalEntry(String childId, String entryId) async {
    if (childById(childId) == null) {
      throw StateError('Không có quyền sửa nhật ký');
    }
    final before = journalEntries(childId)
        .where((e) => e['id'] == entryId)
        .firstOrNull;
    await _writeJournal(childId, (entries, deleted) {
      entries.removeWhere((e) => e['id'] == entryId);
      deleted.add(entryId);
    });
    await _removeFiles(_mediaOf(before));
    unawaited(_pushJournal(childId));
  }

  /// Edits the journal of [childId] in one write: entries plus ids deleted on
  /// this device that the backend has not confirmed yet (`journalDeleted`).
  Future<void> _writeJournal(
    String childId,
    void Function(List<Map<String, dynamic>> entries, Set<String> deleted)
    change,
  ) {
    final entries = journalEntries(childId);
    return _write((d) {
      final c = (d['children'] as List).firstWhere((c) => c['id'] == childId);
      final saved = c['journalEntries'] as List?;
      // Đọc lại trong lượt ghi để không đè thay đổi vừa xếp hàng trước
      final current = saved == null
          ? entries
          : [for (final e in saved) _copy(e as Map)];
      final deleted = Set<String>.from(c['journalDeleted'] as List? ?? []);
      change(current, deleted);
      current.sort(
        (a, b) => b['date'].toString().compareTo(a['date'].toString()),
      );
      c['journalEntries'] = current;
      c['journalDeleted'] = deleted.toList();
      c['journal'] = current.isEmpty
          ? null
          : {
              ...current.first,
              'title': current.first['note'],
              'category':
                  (current.first['domains'] as List?)?.join(' · ') ?? 'Nhật ký',
            };
    });
  }

  final _journalPushes = <String, Future<bool>>{};

  /// Sends pending saves / deletes / files of [childId]; one run per child at
  /// a time. False when offline or not linked (pending items are kept).
  Future<bool> _pushJournal(String childId) =>
      _journalPushes[childId] ??= _pushJournalNow(childId).whenComplete(() {
        // Không trả về Future đã xóa: whenComplete sẽ chờ chính nó
        _journalPushes.remove(childId);
      });

  Future<bool> _pushJournalNow(String childId) async {
    final remote = journalRemote;
    if (remote == null) return false;
    try {
      final account = await linkedAccount(childId);
      if (account == null) return false;
      // Mỗi bản (id + token) / mỗi file gửi 1 lần / lượt; bản sửa trong lúc
      // gửi được gửi tiếp
      final triedSaves = <String>{}, triedUploads = <String>{};
      String saveKey(Map e) => '${e['id']}@${e['pendingSync']}';
      while (true) {
        final child = childById(childId);
        if (child == null) return false;
        final deletes = [
          for (final id in (child['journalDeleted'] as List? ?? []))
            if (triedSaves.add('delete:$id')) id as String,
        ];
        final work = journalEntries(childId).where((e) {
          final save =
              e['pendingSync'] != null && !triedSaves.contains(saveKey(e));
          return save ||
              _mediaOf(
                e,
              ).any((m) => _mediaPending(m) && !triedUploads.contains(m['id']));
        }).toList();
        if (deletes.isEmpty && work.isEmpty) return true;
        for (final id in deletes) {
          await remote.remove(account, id);
          await _writeJournal(childId, (_, deleted) => deleted.remove(id));
        }
        for (final entry in work) {
          final token = entry['pendingSync'];
          if (token != null && triedSaves.add(saveKey(entry))) {
            bool sameVersion(Map<String, dynamic> e) =>
                e['id'] == entry['id'] && e['pendingSync'] == token;
            try {
              await remote.save(account, entry);
            } on ApiException catch (e) {
              // 410: đã xóa ở máy khác → bỏ trên máy này
              if (e.statusCode == 410) {
                await _writeJournal(
                  childId,
                  (entries, _) => entries.removeWhere(sameVersion),
                );
                await _removeFiles(_mediaOf(entry));
              }
              // Dữ liệu bị từ chối: giữ trên máy, lần đồng bộ sau gửi lại
              if (!e.rejected) rethrow;
              continue;
            }
            await _writeJournal(childId, (entries, _) {
              for (final e in entries.where(sameVersion)) {
                e.remove('pendingSync');
              }
            });
          }
          for (final media in _mediaOf(entry).where(_mediaPending)) {
            if (triedUploads.add(media['id'] as String)) {
              await _uploadJournalMedia(
                remote,
                account,
                childId,
                entry['id'] as String,
                media,
              );
            }
          }
        }
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _uploadJournalMedia(
    JournalRemote remote,
    VaccinationAccount account,
    String childId,
    String entryId,
    Map<String, dynamic> media,
  ) async {
    String? rejected;
    if (!await JournalMediaFiles.instance.exists(media['path'] as String)) {
      rejected = 'Không còn file trên máy';
    } else {
      try {
        await remote.uploadMedia(account, entryId, media);
      } on ApiException catch (e) {
        if (!e.rejected) rethrow;
        // Quá lớn / sai loại file: gửi lại cũng vậy. Lỗi 4xx khác thử lại sau.
        if (e.statusCode != 413 && e.statusCode != 415) return;
        rejected = e.message;
      }
    }
    await _writeJournal(childId, (entries, _) {
      for (final e in entries.where((e) => e['id'] == entryId)) {
        // Gửi lại nhật ký để backend bỏ file bị từ chối khỏi danh sách
        if (rejected != null) e['pendingSync'] = 'rejected-${media['id']}';
        e['media'] = [
          for (final m in _mediaOf(e))
            m['id'] == media['id']
                ? {
                    ...m,
                    if (rejected == null)
                      'uploaded': true
                    else
                      'rejected': rejected,
                  }
                : m,
        ];
      }
    });
  }

  /// Ảnh lưu base64 trong nhật ký (trước khi có MinIO) → file + media item.
  Future<void> _convertLegacyPhotos(String childId) async {
    for (final e in journalEntries(childId).where((e) => e['photo'] != null)) {
      final id = newMediaId();
      final String path;
      try {
        path = await JournalMediaFiles.instance.keepBytes(
          base64Decode(e['photo'] as String),
          id,
          '.jpg',
        );
      } catch (_) {
        continue;
      }
      await _writeJournal(childId, (entries, _) {
        for (final x in entries.where(
          (x) => x['id'] == e['id'] && x['photo'] == e['photo'],
        )) {
          x
            ..remove('photo')
            ..['media'] = [
              ..._mediaOf(x),
              {'id': id, 'type': 'image', 'path': path, 'uploaded': false},
            ]
            ..['pendingSync'] = 'photo-$id';
        }
      });
    }
  }

  /// Sends what is saved only on this device, then replaces the cached diary
  /// with the backend copy (entries still pending stay as on this device;
  /// local copies of uploaded files are kept for offline viewing).
  ///
  /// The first sync of a child on this device uploads every local entry
  /// (written before the diary was stored on the backend). Returns false when
  /// offline (the cache is kept).
  Future<bool> syncJournal(String childId) async {
    final remote = journalRemote;
    if (remote == null || childById(childId) == null) return false;
    final parentId = _data['parentId'];
    if (!((_data['journalSynced'] as List?) ?? const []).contains(childId)) {
      await _writeJournal(childId, (entries, _) {
        for (final e in entries) {
          e['pendingSync'] ??= 'first-sync';
        }
      });
    }
    await _convertLegacyPhotos(childId);
    final List<Map<String, dynamic>> server;
    try {
      if (!await _pushJournal(childId)) return false;
      final account = await linkedAccount(childId);
      if (account == null) return false;
      server = await remote.fetch(account);
    } catch (_) {
      return false;
    }
    if (_data['parentId'] != parentId || childById(childId) == null) {
      return false;
    }
    final dropped = <Map>[];
    await _writeJournal(childId, (entries, deleted) {
      final local = {for (final e in entries) e['id']: e};
      final pending = entries.where((e) => e['pendingSync'] != null).toList();
      final pendingIds = {for (final e in pending) e['id']};
      final merged = [
        for (final e in server)
          if (!pendingIds.contains(e['id']) && !deleted.contains(e['id']))
            {
              ...e,
              'childId': childId,
              'media': _mergeMedia(_mediaOf(local[e['id']]), _mediaOf(e)),
            },
        ...pending,
      ];
      final keptIds = {
        for (final e in merged)
          for (final m in _mediaOf(e)) m['id'],
      };
      for (final e in entries) {
        dropped.addAll(_mediaOf(e).where((m) => !keptIds.contains(m['id'])));
      }
      entries
        ..clear()
        ..addAll(merged);
    });
    await _removeFiles(dropped);
    await _write((d) {
      final synced = Set<String>.from(d['journalSynced'] as List? ?? []);
      d['journalSynced'] = (synced..add(childId)).toList();
    });
    return true;
  }

  /// Backend files (with local `path` when this device has a copy) plus
  /// local files not uploaded yet.
  static List<Map<String, dynamic>> _mergeMedia(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> server,
  ) {
    final paths = {for (final m in local) m['id']: m['path']};
    final serverIds = {for (final m in server) m['id']};
    return [
      for (final m in server) {...m, 'path': ?paths[m['id']]},
      ...local.where(
        (m) =>
            !serverIds.contains(m['id']) &&
            (_mediaPending(m) || m['rejected'] != null),
      ),
    ];
  }

  final _mediaUrls = <String, (String, DateTime)>{};

  /// Download link for a photo / video not on this device (renewed before it
  /// expires). Null when offline.
  Future<String?> journalMediaUrl(
    String childId,
    String entryId,
    Map media,
  ) async {
    bool fresh(DateTime? t) =>
        t != null && t.isAfter(DateTime.now().add(const Duration(minutes: 1)));
    final id = media['id'] as String;
    final cached = _mediaUrls[id];
    if (cached != null && fresh(cached.$2)) return cached.$1;
    if (media['url'] != null &&
        fresh(DateTime.tryParse(media['expiresAt'] as String? ?? ''))) {
      return media['url'] as String;
    }
    final remote = journalRemote;
    if (remote == null) return null;
    try {
      final account = await linkedAccount(childId);
      if (account == null) return null;
      final link = await remote.mediaUrl(account, entryId, id);
      _mediaUrls[id] = link;
      return link.$1;
    } catch (_) {
      return null;
    }
  }

  Set<String> completedActivities(String childId) => Set<String>.from(
    childById(childId)?['completedActivities'] as List? ?? [],
  );

  Set<String> get favoriteActivities =>
      Set<String>.from(parent['favoriteActivities'] as List? ?? []);

  /// Library activities (uuid ids) are saved to the backend first, so a failed
  /// request leaves the local state unchanged. Bundled ideas stay local.
  Future<void> setActivityDone(
    String childId,
    String activityId,
    bool done,
  ) async {
    if (childById(childId) == null) {
      throw StateError('Không có quyền sửa hồ sơ');
    }
    if (!activityCatalog.any((a) => a.id == activityId)) {
      throw ArgumentError('Hoạt động không tồn tại');
    }
    final remote = activityRemote;
    if (remote != null && _uuid.hasMatch(activityId)) {
      final account = await linkedAccount(childId);
      if (account != null) await remote.setDone(account, activityId, done);
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

  Future<void> setActivityFavorite(String activityId, bool favorite) async {
    if (!signedIn) throw StateError('Vui lòng đăng nhập');
    if (!activityCatalog.any((a) => a.id == activityId)) {
      throw ArgumentError('Hoạt động không tồn tại');
    }
    final parentId = parent['id'];
    final remote = activityRemote;
    final anyChild = child;
    // Yêu thích theo phụ huynh; cần 1 bé để đăng ký tài khoản (PUT /dev/profiles).
    if (remote != null && anyChild != null && _uuid.hasMatch(activityId)) {
      final account = await linkedAccount(anyChild['id'] as String);
      if (account != null) {
        await remote.setFavorite(account, activityId, favorite);
      }
    }
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

  /// Replaces the library part of [childId]'s "Đã làm" and the parent's
  /// favorites with the backend copy; bundled ideas (non-uuid ids) are kept.
  ///
  /// The first sync on this device uploads what was marked only locally.
  /// Returns false when offline (the cache is kept).
  Future<bool> syncActivities(String childId) async {
    final remote = activityRemote;
    if (remote == null) return false;
    final parentId = _data['parentId'];
    final Set<String> done, favorites;
    try {
      final account = await linkedAccount(childId);
      if (account == null) return false;
      Future<Set<String>> fetch() => remote.fetchDone(account);
      final synced = Set<String>.from(_data['activitySynced'] as List? ?? []);
      final keys = (child: 'child:$childId', parent: 'parent:$parentId');
      var serverDone = await fetch();
      var serverFavorites = await remote.fetchFavorites(account);
      if (!synced.contains(keys.child)) {
        final localOnly = completedActivities(childId)
            .where((id) => _uuid.hasMatch(id) && !serverDone.contains(id));
        for (final id in localOnly) {
          await remote.setDone(account, id, true);
        }
        if (localOnly.isNotEmpty) serverDone = await fetch();
      }
      if (!synced.contains(keys.parent)) {
        final localOnly = favoriteActivities.where(
          (id) => _uuid.hasMatch(id) && !serverFavorites.contains(id),
        );
        for (final id in localOnly) {
          await remote.setFavorite(account, id, true);
        }
        if (localOnly.isNotEmpty) {
          serverFavorites = await remote.fetchFavorites(account);
        }
      }
      (done, favorites) = (serverDone, serverFavorites);
    } catch (_) {
      return false;
    }
    if (_data['parentId'] != parentId || childById(childId) == null) {
      return false;
    }
    List<String> merge(List? local, Set<String> server) => [
      ...?local?.cast<String>().where((id) => !_uuid.hasMatch(id)),
      ...server,
    ];
    await _write((d) {
      final c = (d['children'] as List).firstWhere((c) => c['id'] == childId);
      c['completedActivities'] = merge(c['completedActivities'] as List?, done);
      final account = (d['parents'] as List).firstWhere(
        (p) => p['id'] == parentId,
      );
      account['favoriteActivities'] = merge(
        account['favoriteActivities'] as List?,
        favorites,
      );
      d['activitySynced'] = {
        ...?(d['activitySynced'] as List?)?.cast<String>(),
        'child:$childId',
        'parent:$parentId',
      }.toList();
    });
    return true;
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

  /// Backend uuids for local parent / child ids: ids that already are backend
  /// uuids (server-authenticated user), the seeded demo ids, else a uuid
  /// generated once on this device (registered via VaccinationRemote.link).
  Future<Map<String, String>> _serverIds(List<String> localIds) async {
    String? known(String id) => _uuid.hasMatch(id)
        ? id
        : demoServerIds[id] ?? (_data['serverIds'] as Map?)?[id] as String?;
    if (localIds.any((id) => known(id) == null)) {
      await _write((d) {
        final saved = Map<String, dynamic>.from(d['serverIds'] as Map? ?? {});
        for (final id in localIds) {
          if (known(id) == null) saved[id] ??= _uuidV4();
        }
        d['serverIds'] = saved;
      });
    }
    return {for (final id in localIds) id: known(id)!};
  }

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

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

  /// Backend identity of the signed-in parent + [childId], registered on the
  /// backend first (dev: PUT /dev/profiles). Null when offline-only (tests) or
  /// the child is not this parent's.
  Future<VaccinationAccount?> linkedAccount(String childId) async {
    final remote = vaccinationRemote;
    if (remote == null) return null;
    final account = await _account(childId);
    if (account == null) return null;
    await remote.link(account);
    return account;
  }

  /// Fetches the latest AI comment for a journal entry and caches it in the
  /// entry (`insight`). Null when the entry has no AI request or offline-only.
  Future<VideoInsight?> refreshJournalInsight(
    String childId,
    String entryId,
  ) async {
    final remote = videoInsightRemote;
    final entry = journalEntries(childId)
        .where((e) => e['id'] == entryId)
        .firstOrNull;
    final saved = entry?['insight'] as Map?;
    if (remote == null || entry == null || saved == null) return null;
    final account = await linkedAccount(childId);
    if (account == null) return null;
    final insight = await remote.fetch(account, saved['id'] as String);
    // Polling: chỉ lưu (và gửi lên backend) khi nhận xét thay đổi
    if (jsonEncode(saved) != jsonEncode(insight.toJson())) {
      await saveJournalEntry(childId, {...entry, 'insight': insight.toJson()});
    }
    return insight;
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
