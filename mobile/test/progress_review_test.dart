import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/journal/ai_videos_screen.dart';
import 'package:track_children/models/progress_review.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/progress_review_api.dart';

Map<String, dynamic> _insight(String id, {bool canAssess = true}) => {
  'id': id,
  'status': 'done',
  'result': {
    'canAssess': canAssess,
    'videoIssue': canAssess ? '' : 'Video hơi tối',
    'observations': ['Bé bật nhảy'],
    'comment': 'Nhận xét $id',
    'positives': <String>[],
    'nextSteps': <String>[],
    'seeSpecialist': false,
    'specialistNote': '',
  },
};

Map<String, dynamic> _reviewJson(
  String id,
  String summary, {
  List<String> ids = const ['i1', 'i2'],
  String createdAt = '2026-10-02T08:00:00Z',
}) => {
  'id': id,
  'activityRef': 'g0-9',
  'activityGroup': 'gross_motor',
  'activityTitle': 'Nhảy tại chỗ hai chân',
  'insightIds': ids,
  'periodFrom': '2026-09-01T08:00:00Z',
  'periodTo': '2026-10-01T08:00:00Z',
  'createdAt': createdAt,
  'result': {
    'summary': summary,
    'progress': ['Lần sau bé tự nhảy, không cần vịn tay.'],
    'keepPracticing': ['Tiếp đất nhẹ bằng hai chân.'],
    'nextSteps': ['Đặt sợi dây trên sàn để bé nhảy qua.'],
    'activities': ['Nhảy tại chỗ hai chân'],
    'skillsDone': ['Bật nhảy hai chân'],
    'stage': 'Bé đang chuyển từ nhảy vịn tay sang tự nhảy.',
    'strengths': ['Vận động thô: bé hào hứng, tự tin.'],
    'nextRecording': 'Khoảng 2 tuần nữa, quay cùng góc máy.',
    'seeSpecialist': false,
    'specialistNote': '',
  },
  'metrics': [
    {
      'key': 'jump_count',
      'label': 'Số lần bật nhảy hai chân',
      'unit': 'lần',
      'change': 3,
      'points': [
        {'insightId': 'i1', 'at': '2026-09-01T08:00:00Z', 'value': 2},
        {'insightId': 'i2', 'at': '2026-10-01T08:00:00Z', 'value': 5},
      ],
    },
  ],
};

class _LinkOnly implements VaccinationRemote {
  @override
  Future<void> link(VaccinationAccount account) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeReviews implements ProgressReviewRemote {
  final created = <List<String>>[];
  Object? error;
  List<ProgressReview> history = [
    ProgressReview.fromJson(_reviewJson('r2', 'Bé nhảy tự tin hơn.')),
    ProgressReview.fromJson(
      _reviewJson(
        'r1',
        'Lần đánh giá tháng trước.',
        createdAt: '2026-09-02T08:00:00Z',
      ),
    ),
  ];

  @override
  Future<ProgressReview> create(
    VaccinationAccount account,
    List<String> insightIds,
  ) async {
    created.add(insightIds);
    if (error != null) throw error!;
    return ProgressReview.fromJson(
      _reviewJson(
        'r3',
        'Đánh giá mới nhất.',
        ids: insightIds,
        createdAt: '2026-11-06T08:00:00Z',
      ),
    );
  }

  @override
  Future<List<ProgressReview>> list(
    VaccinationAccount account, {
    String? activityRef,
  }) async => history;
}

void main() {
  late _FakeReviews reviews;
  late String childId;

  /// Màn cao để ListView dựng hết kết quả, lịch sử và danh sách video.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
    childId = DemoStore.instance.child!['id'] as String;
    DemoStore.vaccinationRemote = _LinkOnly();
    DemoStore.progressReviewRemote = reviews = _FakeReviews();
  });

  tearDown(() {
    DemoStore.vaccinationRemote = null;
    DemoStore.progressReviewRemote = null;
  });

  Future<void> addEntry(
    String id,
    String date,
    Map<String, dynamic> insight, {
    String activityId = 'g0-9',
    String activityName = 'Nhảy tại chỗ hai chân',
  }) => DemoStore.instance.saveJournalEntry(childId, {
    'id': id,
    'date': date,
    'note': 'Chơi cùng bé',
    'mood': 'Vui vẻ',
    'domains': <String>[],
    'activityId': activityId,
    'activityName': activityName,
    'insight': insight,
  });

  /// i1, i2 nhảy; i3 nhảy nhưng video tối; i4 kể chuyện.
  Future<void> addVideos() async {
    await addEntry('e1', '2026-09-01', _insight('i1'));
    await addEntry('e2', '2026-10-01', _insight('i2'));
    await addEntry('e3', '2026-10-03', _insight('i3', canAssess: false));
    await addEntry(
      'e4',
      '2026-10-05',
      _insight('i4'),
      activityId: 'g5-1',
      activityName: 'Kể chuyện cùng bé',
    );
  }

  Future<void> open(WidgetTester tester) async {
    tall(tester);
    await tester.pumpWidget(
      MaterialApp(home: AiVideosScreen(childId: childId)),
    );
    await tester.pumpAndSettle();
  }

  FilledButton reviewButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.text('Đánh giá tổng hợp').last,
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets(
    'shows the time range and latest review; history on its own screen',
    (tester) async {
      await addVideos();
      await open(tester);

      expect(reviews.created, isEmpty); // mở màn không gọi AI
      expect(find.text('01/09/2026 – 05/10/2026'), findsOneWidget);
      expect(
        find.text('3 video AI đã nhận xét · 2 hoạt động trong khoảng này'),
        findsOneWidget,
      );
      expect(find.text('Kết quả gần nhất'), findsOneWidget);
      // Chỉ kết quả gần nhất, lịch sử nằm ở màn khác
      expect(find.text('Bé nhảy tự tin hơn.'), findsOneWidget);
      expect(find.text('Lần đánh giá tháng trước.'), findsNothing);
      expect(find.text('1. Tổng quan quá trình phát triển'), findsOneWidget);
      expect(find.text('2. Sự tiến bộ theo thời gian'), findsOneWidget);
      expect(find.text('3. Điểm mạnh và kỹ năng cần hỗ trợ'), findsOneWidget);
      expect(find.text('4. Những dấu hiệu cần chú ý'), findsOneWidget);
      expect(find.textContaining('Chưa thấy dấu hiệu nào'), findsOneWidget);
      expect(find.text('5. Kế hoạch chăm sóc và luyện tập'), findsOneWidget);
      expect(
        find.text('Bé đang chuyển từ nhảy vịn tay sang tự nhảy.'),
        findsOneWidget,
      );
      expect(
        find.text('Khoảng 2 tuần nữa, quay cùng góc máy.'),
        findsOneWidget,
      );
      expect(find.text('Lịch sử (2)'), findsOneWidget);
      expect(find.text('Video trong khoảng này (4)'), findsOneWidget);
      expect(find.text('Kể chuyện cùng bé'), findsOneWidget);
      expect(find.text('Video hơi tối'), findsOneWidget);

      await tester.tap(find.text('Lịch sử (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử đánh giá (2)'), findsOneWidget);
      expect(find.text('Bé nhảy tự tin hơn.'), findsOneWidget); // dòng lịch sử

      await tester.tap(find.text('Lần đánh giá tháng trước.'));
      await tester.pumpAndSettle();
      expect(find.text('Đánh giá ngày 02/09/2026'), findsOneWidget);
      expect(find.text('Lần đánh giá tháng trước.'), findsOneWidget);
      expect(find.text('1. Tổng quan quá trình phát triển'), findsOneWidget);
    },
  );

  testWidgets('one review over every usable video of all activities', (
    tester,
  ) async {
    await addVideos();
    await open(tester);

    await tester.tap(find.text('Đánh giá tổng hợp').last);
    await tester.pumpAndSettle();
    expect(reviews.created.single, ['i4', 'i2', 'i1']); // mới nhất trước
    expect(find.text('Lịch sử (3)'), findsOneWidget);
    expect(find.text('Kết quả gần nhất'), findsOneWidget);
    expect(find.text('Đánh giá mới nhất.'), findsOneWidget);

    await tester.tap(find.text('Lịch sử (3)'));
    await tester.pumpAndSettle();
    expect(
      find.text('3 video quay 01/09/2026 – 05/10/2026'),
      findsOneWidget, // dòng lịch sử của lần mới
    );
  });

  testWidgets('the chosen range limits videos and the review', (tester) async {
    await addVideos();
    await open(tester);

    await tester.tap(find.text('01/09/2026 – 05/10/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined)); // nhập ngày
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '09/15/2026');
    await tester.enterText(find.byType(TextField).at(1), '10/05/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('15/09/2026 – 05/10/2026'), findsOneWidget);
    expect(
      find.text('2 video AI đã nhận xét · 2 hoạt động trong khoảng này'),
      findsOneWidget,
    );
    expect(find.text('Video trong khoảng này (3)'), findsOneWidget);

    await tester.tap(find.text('Đánh giá tổng hợp').last);
    await tester.pumpAndSettle();
    expect(reviews.created.single, ['i4', 'i2']);

    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('01/09/2026 – 05/10/2026'), findsOneWidget);
  });

  testWidgets('needs two usable videos in the range', (tester) async {
    await addEntry('e1', '2026-09-01', _insight('i1'));
    await addEntry('e2', '2026-09-02', _insight('i2', canAssess: false));
    await open(tester);
    expect(find.textContaining('cần ít nhất 2 video'), findsOneWidget);
    expect(reviewButton(tester).onPressed, isNull);
  });

  testWidgets('empty history and AI errors are shown', (tester) async {
    reviews.history = [];
    reviews.error = ApiException(
      503,
      'AI đang bận, ba mẹ thử lại sau ít phút nhé',
    );
    await addVideos();
    await open(tester);
    expect(find.textContaining('Chưa có lần đánh giá nào'), findsOneWidget);

    await tester.tap(find.text('Đánh giá tổng hợp').last);
    await tester.pumpAndSettle();
    expect(
      find.text('AI đang bận, ba mẹ thử lại sau ít phút nhé'),
      findsOneWidget,
    );

    reviews.error = null;
    await tester.tap(find.text('Đánh giá tổng hợp').last);
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử (1)'), findsOneWidget);
    expect(
      find.text('AI đang bận, ba mẹ thử lại sau ít phút nhé'),
      findsNothing,
    );
  });

  testWidgets('no analysed video yet', (tester) async {
    await open(tester);
    expect(find.text('Chưa có video nào được AI nhận xét'), findsOneWidget);
    expect(find.text('Đánh giá tổng hợp'), findsNothing);
  });
}
