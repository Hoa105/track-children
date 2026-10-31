import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/journal_api.dart';
import 'package:track_children/services/journal_media.dart';

import 'fake_media_files.dart';

/// Only registers profiles; vaccination calls are not used here.
class _Linker implements VaccinationRemote {
  @override
  Future<void> link(VaccinationAccount account) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// In-memory backend keyed by backend child uuid; files keyed by media id.
class _FakeJournal implements JournalRemote {
  _FakeJournal(this.files);

  final FakeMediaFiles files;
  final entries = <String, Map<String, Map<String, dynamic>>>{};
  final deleted = <String>{};
  final uploads = <String, List<int>>{};
  var urlRequests = 0;
  bool offline = false;
  int? uploadError;

  Map<String, Map<String, dynamic>> _of(VaccinationAccount account) {
    if (offline) throw ApiException(0, 'offline');
    return entries.putIfAbsent(account.childId, () => {});
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(VaccinationAccount account) async =>
      [
        for (final e in _of(account).values)
          {
            ...e,
            'media': [
              for (final m in e['media'] as List)
                if (uploads.containsKey(m['id']))
                  {
                    ...m as Map,
                    'uploaded': true,
                    'url': 'http://minio/${m['id']}?old',
                    'expiresAt': '2000-01-01T00:00:00Z',
                  },
            ],
          },
      ];

  @override
  Future<void> save(
    VaccinationAccount account,
    Map<String, dynamic> entry,
  ) async {
    final saved = _of(account);
    final id = entry['id'] as String;
    if (deleted.contains(id)) throw ApiException(410, 'Nhật ký này đã bị xóa');
    final media = [
      for (final m in entry['media'] as List? ?? [])
        if (m['rejected'] == null) {'id': m['id'], 'type': m['type']},
    ];
    // Backend xóa file không còn trong danh sách
    final before = saved[id]?['media'] as List? ?? [];
    for (final m in before) {
      if (!media.any((x) => x['id'] == m['id'])) uploads.remove(m['id']);
    }
    saved[id] = {
      for (final key in ['id', 'date', 'note', 'mood', 'domains'])
        if (entry[key] != null) key: entry[key],
      'media': media,
    };
  }

  @override
  Future<void> remove(VaccinationAccount account, String entryId) async {
    final entry = _of(account).remove(entryId);
    for (final m in entry?['media'] as List? ?? []) {
      uploads.remove(m['id']);
    }
    deleted.add(entryId);
  }

  @override
  Future<void> uploadMedia(
    VaccinationAccount account,
    String entryId,
    Map<String, dynamic> media,
  ) async {
    _of(account);
    if (uploadError != null) throw ApiException(uploadError!, 'Quá lớn');
    uploads[media['id'] as String] = files.files[media['path']]!;
  }

  @override
  Future<(String, DateTime)> mediaUrl(
    VaccinationAccount account,
    String entryId,
    String mediaId,
  ) async {
    _of(account);
    urlRequests++;
    return (
      'http://minio/$mediaId?fresh',
      DateTime.now().add(const Duration(hours: 1)),
    );
  }
}

Map<String, dynamic> _entry(
  String id,
  String note, {
  String day = '28',
  List<Map<String, dynamic>> media = const [],
}) => {
  'id': id,
  'date': '2026-10-${day}T09:00:00.000',
  'note': note,
  'mood': 'Vui vẻ',
  'domains': ['Ngôn ngữ'],
  'media': media,
};

void main() {
  late _FakeJournal server;
  late FakeMediaFiles files;
  late String an;
  DemoStore store() => DemoStore.instance;
  List<String> notes() => [
    for (final e in store().journalEntries(an)) e['note'] as String,
  ];
  Map<String, dynamic> entry(String id) =>
      store().journalEntries(an).firstWhere((e) => e['id'] == id);
  bool pending(String id) => entry(id)['pendingSync'] != null;
  List<Map> mediaOf(String id) => (entry(id)['media'] as List).cast<Map>();

  Future<Map<String, dynamic>> photo(List<int> bytes) async {
    final id = DemoStore.newMediaId();
    final path = await files.keepBytes(bytes, id, '.jpg');
    return {'id': id, 'type': 'image', 'path': path, 'uploaded': false};
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    JournalMediaFiles.instance = files = FakeMediaFiles();
    server = _FakeJournal(files);
    DemoStore.vaccinationRemote = _Linker();
    DemoStore.journalRemote = server;
    await store().login('demo@trackchildren.vn', DemoStore.password);
    an = store().children.first['id'] as String;
  });

  tearDown(() {
    DemoStore.vaccinationRemote = null;
    DemoStore.journalRemote = null;
    JournalMediaFiles.instance = JournalMediaFiles();
  });

  test(
    'first sync uploads entries written before the backend existed',
    () async {
      final before = notes();
      expect(before, isNotEmpty); // nhật ký mẫu trên máy
      expect(await store().syncJournal(an), isTrue);
      final onServer = server.entries.values.single.values;
      expect([for (final e in onServer) e['note']], unorderedEquals(before));
      expect(notes(), unorderedEquals(before));
      expect(
        store().journalEntries(an).any((e) => e['pendingSync'] != null),
        isFalse,
      );
    },
  );

  test('saves offline and sends the entry when back online', () async {
    await store().syncJournal(an);
    server.offline = true;
    await store().saveJournalEntry(an, _entry('j1', 'Bé nói "mẹ"'));
    await pumpEventQueue();
    expect(notes(), contains('Bé nói "mẹ"'));
    expect(pending('j1'), isTrue);

    server.offline = false;
    expect(await store().syncJournal(an), isTrue);
    expect(server.entries.values.single['j1']?['note'], 'Bé nói "mẹ"');
    expect(pending('j1'), isFalse);
  });

  test('online save reaches the backend without a manual sync', () async {
    await store().syncJournal(an);
    await store().saveJournalEntry(an, _entry('j2', 'Bé tự xúc ăn'));
    await pumpEventQueue();
    expect(server.entries.values.single['j2']?['domains'], ['Ngôn ngữ']);
    expect(pending('j2'), isFalse);
  });

  test(
    'photos taken offline are uploaded later and kept on the device',
    () async {
      await store().syncJournal(an);
      server.offline = true;
      final image = await photo([1, 2, 3]);
      await store().saveJournalEntry(an, _entry('p1', 'Ảnh', media: [image]));
      await pumpEventQueue();
      expect(server.uploads, isEmpty);

      server.offline = false;
      expect(await store().syncJournal(an), isTrue);
      expect(server.uploads[image['id']], [1, 2, 3]);
      final saved = mediaOf('p1').single;
      expect(saved['uploaded'], isTrue);
      // Sau khi lấy bản trên máy chủ vẫn xem được không cần mạng
      expect(saved['path'], image['path']);
    },
  );

  test('removing a photo or deleting the entry frees local copies', () async {
    await store().syncJournal(an);
    final first = await photo([1]), second = await photo([2]);
    await store().saveJournalEntry(
      an,
      _entry('p2', 'Hai ảnh', media: [first, second]),
    );
    await pumpEventQueue();
    await store().saveJournalEntry(
      an,
      _entry('p2', 'Một ảnh', media: [second]),
    );
    await pumpEventQueue();
    expect(files.files.keys, [second['path']]);
    expect(server.uploads.keys, [second['id']]);

    await store().deleteJournalEntry(an, 'p2');
    await pumpEventQueue();
    expect(files.files, isEmpty);
    expect(server.uploads, isEmpty);
  });

  test('old base64 photos become files and are uploaded', () async {
    await store().saveJournalEntry(an, {
      ..._entry('old', 'Ảnh cũ'),
      'photo': base64Encode([9, 9]),
    });
    expect(await store().syncJournal(an), isTrue);
    expect(entry('old').containsKey('photo'), isFalse);
    final image = mediaOf('old').single;
    expect(server.uploads[image['id']], [9, 9]);
  });

  test('files from another device use a fresh download link', () async {
    await store().syncJournal(an);
    final image = await photo([5]);
    await store().saveJournalEntry(an, _entry('p3', 'Ảnh', media: [image]));
    await pumpEventQueue();
    // Máy khác: không có file trên máy, link trong danh sách đã hết hạn
    files.files.clear();
    await store().syncJournal(an);
    final listed = mediaOf('p3').single;
    final url = await store().journalMediaUrl(an, 'p3', listed);
    expect(url, 'http://minio/${image['id']}?fresh');
    await store().journalMediaUrl(an, 'p3', listed);
    expect(server.urlRequests, 1); // link còn hạn được dùng lại
  });

  test('a file the backend refuses is not sent again', () async {
    await store().syncJournal(an);
    server.uploadError = 413;
    final video = {
      ...await photo([1]),
      'type': 'video',
    };
    await store().saveJournalEntry(
      an,
      _entry('v1', 'Video dài', media: [video]),
    );
    await pumpEventQueue();
    expect(mediaOf('v1').single['rejected'], 'Quá lớn');
    server.uploadError = null;
    await store().syncJournal(an);
    expect(server.uploads, isEmpty);
    // Lần lưu sau không còn gửi file bị từ chối trong danh sách
    expect(server.entries.values.single['v1']?['media'], isEmpty);
  });

  test('deletes made offline are sent later and not brought back', () async {
    await store().saveJournalEntry(an, _entry('j3', 'Bé bò'));
    await store().syncJournal(an);
    server.offline = true;
    await store().deleteJournalEntry(an, 'j3');
    await pumpEventQueue();
    expect(notes(), isNot(contains('Bé bò')));
    expect(await store().syncJournal(an), isFalse);

    server.offline = false;
    expect(await store().syncJournal(an), isTrue);
    expect(server.entries.values.single.containsKey('j3'), isFalse);
    expect(notes(), isNot(contains('Bé bò')));
  });

  test(
    'entries from another device are fetched; deleted ones are dropped',
    () async {
      await store().syncJournal(an);
      final child = server.entries.keys.single;
      server.entries[child]!['other'] = _entry('other', 'Bố ghi', day: '29');
      await store().syncJournal(an);
      expect(notes().first, 'Bố ghi');

      // Máy này sửa bản đã bị xóa ở máy khác → backend trả 410, bỏ trên máy
      server.offline = true;
      await store().saveJournalEntry(
        an,
        _entry('other', 'Sửa trên máy này', day: '29'),
      );
      server.offline = false;
      await server.remove(_account(child), 'other');
      expect(await store().syncJournal(an), isTrue);
      expect(notes(), isNot(contains('Sửa trên máy này')));
    },
  );
}

VaccinationAccount _account(String childId) => VaccinationAccount(
  userId: 'u',
  childId: childId,
  parent: const {},
  child: const {},
);
