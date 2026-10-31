import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/activities/activities_screen.dart';
import 'package:track_children/features/activities/activity_journal_screen.dart';
import 'package:track_children/features/journal/journal_screen.dart';
import 'package:track_children/features/journal/video_insight_view.dart';
import 'package:track_children/models/activity.dart';
import 'package:track_children/models/video_insight.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/journal_media.dart';
import 'package:track_children/services/video_insight_api.dart';

import 'fake_media_files.dart';

final _jump = activityCatalog.firstWhere((a) => a.id == 'g0-9');

const _account = VaccinationAccount(
  userId: '00000000-0000-4000-8000-000000000001',
  childId: '00000000-0000-4000-8000-000000000101',
  parent: {},
  child: {},
);

final _doneJson = <String, dynamic>{
  'id': 'insight-1',
  'status': 'done',
  'result': {
    'canAssess': true,
    'videoIssue': '',
    'observations': ['Bé bật nhảy, hai chân cùng rời sàn.'],
    'comment': 'Bé rất hào hứng với trò chơi.',
    'positives': ['Bé tiếp đất bằng cả hai chân'],
    'nextSteps': ['Đặt sợi dây trên sàn để bé nhảy qua.'],
    'seeSpecialist': false,
    'specialistNote': '',
  },
  'evidence': {
    'available': true,
    'metrics': [
      {
        'key': 'jump_count',
        'label': 'Số lần bật nhảy hai chân',
        'value': 3.0,
        'unit': 'lần',
      },
    ],
  },
};

class _LinkOnly implements VaccinationRemote {
  int links = 0;
  @override
  Future<void> link(VaccinationAccount account) async => links++;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeInsights implements VideoInsightRemote {
  final submitted = <Map<String, Object?>>[];
  var fetches = 0;

  @override
  Future<VideoInsight> submit(
    VaccinationAccount account, {
    required List<int> video,
    required String filename,
    required ChildActivity activity,
    required List<(String, String)> guide,
    required String note,
  }) async {
    submitted.add({
      'bytes': video.length,
      'filename': filename,
      'activity': activity.id,
      'note': note,
      'guide': guide.length,
    });
    return const VideoInsight(id: 'insight-1', status: 'pending');
  }

  @override
  Future<VideoInsight> fetch(VaccinationAccount account, String id) async {
    fetches++;
    return VideoInsight.fromJson(_doneJson);
  }
}

void main() {
  late _FakeInsights insights;
  late FakeMediaFiles media;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
    insights = _FakeInsights();
    DemoStore.vaccinationRemote = _LinkOnly();
    DemoStore.videoInsightRemote = insights;
    JournalMediaFiles.instance = media = FakeMediaFiles();
  });

  tearDown(() {
    DemoStore.vaccinationRemote = null;
    DemoStore.videoInsightRemote = null;
    JournalMediaFiles.instance = JournalMediaFiles();
  });

  /// Opens [page] on top of a blank route so screens can pop when they save.
  Widget host(Widget page, {double textScale = 1}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => page),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  Future<void> open(
    WidgetTester tester,
    Widget page, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(host(page, textScale: textScale));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Scrolls down until [finder] is built, then fully into view.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        150,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Finder button(String text) => find
      .ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      )
      .first;

  final journal = ActivityJournalScreen(
    childId: 'child_an',
    activity: _jump,
    guide: activitySections(_jump),
    pickVideo: (_) async => XFile.fromData(
      Uint8List(2048),
      name: 'clip.mp4',
      path: 'clip.mp4',
      length: 2048,
    ),
  );

  testWidgets('sends video to AI, saves entry and shows the result', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);
    await open(tester, journal, textScale: 1.6);

    const send = 'Gửi cho AI nhận xét';
    bool enabled() =>
        tester.widget<ButtonStyleButton>(button(send)).onPressed != null;

    await tester.tap(find.text('Chọn video'));
    await tester.pumpAndSettle();
    expect(find.text('clip.mp4'), findsOneWidget);
    await reveal(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Bé nhảy 3 lần');
    await reveal(tester, find.text(send));
    // Chưa đồng ý gửi video cho AI → chưa gửi được
    expect(enabled(), isFalse);
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await reveal(tester, find.text(send));
    expect(enabled(), isTrue);
    await tester.tap(find.text(send));
    await tester.pump();
    await tester.pump();

    expect(insights.submitted.single, {
      'bytes': 2048,
      'filename': 'clip.mp4',
      'activity': 'g0-9',
      'note': 'Bé nhảy 3 lần',
      'guide': activitySections(_jump).length,
    });
    expect(find.textContaining('AI đang xem video'), findsOneWidget);
    var entry = DemoStore.instance.journalEntries('child_an').first;
    expect(entry['activityId'], 'g0-9');
    expect(entry['domains'], ['Vận động thô']);
    expect((entry['insight'] as Map)['status'], 'pending');
    // Video được giữ trong nhật ký (bản sao trên máy, chờ tải lên máy chủ)
    final video = (entry['media'] as List).single as Map;
    expect(video['type'], 'video');
    expect(video['uploaded'], isFalse);
    expect(media.files[video['path']], hasLength(2048));

    await tester.pump(pollInterval);
    await tester.pumpAndSettle();
    expect(insights.fetches, 1);
    expect(find.text('Quan sát'), findsOneWidget);
    expect(find.text('Bé bật nhảy, hai chân cùng rời sàn.'), findsOneWidget);
    expect(find.text('Gợi ý tiếp theo'), findsOneWidget);
    expect(find.text('Số lần bật nhảy hai chân: 3 lần'), findsOneWidget);
    expect(tester.takeException(), isNull);
    entry = DemoStore.instance.journalEntries('child_an').first;
    expect((entry['insight'] as Map)['status'], 'done');
  });

  testWidgets('save without AI needs a note and keeps the activity', (
    tester,
  ) async {
    await open(tester, journal);
    const saveOnly = 'Chỉ lưu nhật ký, không cần AI';
    await reveal(tester, find.text(saveOnly));
    await tester.tap(find.text(saveOnly));
    await tester.pump();
    expect(find.text('Hãy ghi lại một khoảnh khắc của bé.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(ActivityJournalScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    await reveal(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Bé thích nhảy');
    await reveal(tester, find.text(saveOnly));
    await tester.tap(find.text(saveOnly));
    await tester.pumpAndSettle();
    final entry = DemoStore.instance.journalEntries('child_an').first;
    expect(entry['note'], 'Bé thích nhảy');
    expect(entry['activityName'], _jump.name);
    expect(entry.containsKey('insight'), isFalse);
    expect(insights.submitted, isEmpty);
  });

  testWidgets('journal detail shows AI result and editing keeps it', (
    tester,
  ) async {
    await DemoStore.instance.saveJournalEntry('child_an', {
      'id': 'with-ai',
      'date': '2099-01-01T00:00:00',
      'note': 'Bé nhảy',
      'mood': 'Vui vẻ',
      'domains': ['Vận động thô'],
      'activityId': 'g0-9',
      'activityName': _jump.name,
      'insight': _doneJson,
    });
    final entry = DemoStore.instance
        .journalEntries('child_an')
        .firstWhere((e) => e['id'] == 'with-ai');
    await open(tester, JournalEditorScreen(childId: 'child_an', entry: entry));
    expect(find.text('Nhận xét của AI'), findsOneWidget);
    expect(find.text('Bé rất hào hứng với trò chơi.'), findsOneWidget);
    expect(insights.fetches, 0); // đã xong thì không gọi lại

    await tester.tap(find.byTooltip('Sửa nhật ký'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'Bé nhảy giỏi');
    await reveal(tester, find.text('Lưu nhật ký'));
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    final saved = DemoStore.instance
        .journalEntries('child_an')
        .firstWhere((e) => e['id'] == 'with-ai');
    expect(saved['note'], 'Bé nhảy giỏi');
    expect(saved['activityId'], 'g0-9');
    expect((saved['insight'] as Map)['status'], 'done');
  });

  testWidgets('rejected and unassessable results explain what to do', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              VideoInsightView(
                insight: VideoInsight(
                  id: 'a',
                  status: 'rejected',
                  message: 'Video quá tối để quan sát.',
                ),
              ),
              VideoInsightView(
                insight: VideoInsight(
                  id: 'b',
                  status: 'done',
                  result: InsightResult(
                    canAssess: false,
                    videoIssue: 'Không thấy bé trong khung hình.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Video quá tối để quan sát.'), findsOneWidget);
    expect(find.text('Không thấy bé trong khung hình.'), findsOneWidget);
  });

  test('json round trip keeps result and evidence', () {
    final insight = VideoInsight.fromJson(_doneJson);
    final again = VideoInsight.fromJson(insight.toJson());
    expect(again.result!.nextSteps, insight.result!.nextSteps);
    expect(again.evidence.single.valueLabel, '3');
    expect(
      VideoInsight.fromJson({
        'id': 'x',
        'status': 'done',
        'evidence': {'available': false, 'reason': 'no pose'},
      }).evidence,
      isEmpty,
    );
  });

  test('api sends multipart with activity, consent and dev identity', () async {
    late http.BaseRequest sent;
    late String body;
    final api = VideoInsightApi(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        sent = request;
        body = utf8.decode(request.bodyBytes, allowMalformed: true);
        return http.Response.bytes(
          utf8.encode(jsonEncode({'id': 'i', 'status': 'pending'})),
          202,
        );
      }),
    );
    final insight = await api.submit(
      _account,
      video: [1, 2, 3],
      filename: 'clip.mp4',
      activity: _jump,
      guide: const [('Mục tiêu', 'Bé nhảy')],
      note: 'ghi chú',
    );
    expect(insight.status, 'pending');
    expect(
      sent.url.toString(),
      'http://api.test/children/${_account.childId}/diary/video-insights',
    );
    expect(sent.headers['X-User-Id'], _account.userId);
    expect(body, contains('name="consent"'));
    expect(body, contains('"group":"gross_motor"'));
    expect(body, contains('filename="clip.mp4"'));

    final failing = VideoInsightApi(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'detail': 'Chỉ nhận file video'})),
          415,
        ),
      ),
    );
    expect(
      () => failing.fetch(_account, 'i'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('video'),
        ),
      ),
    );
  });
}
