import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/models/activity.dart';
import 'package:track_children/services/activity_api.dart';

const _summary = {
  'id': '7f0c7c1e-0000-5000-8000-000000000001',
  'groupCode': 'gross_motor',
  'title': 'Massage cho bé',
  'summary': null,
  'ageFromMonths': 0,
  'ageToMonths': 3,
  'durationMinutes': null,
  'thumbnailUrl': '/static/activities/g001/main.jpg',
};

void main() {
  tearDown(() => activityCatalogState.value = bundledActivityCatalog);

  test('backend activities replace bundled ideas of the same group only', () {
    applyActivityCatalog([ChildActivity.fromJson(_summary)]);

    final grossMotor = activityCatalog.where((a) => a.groupId == 'g0');
    expect(grossMotor.map((a) => a.name), ['Massage cho bé']);
    expect(grossMotor.single.durationLabel, 'Linh hoạt');
    // Âm nhạc chưa có trong DB nên vẫn giữ ý tưởng soạn sẵn.
    expect(activityCatalog.where((a) => a.groupId == 'g4'), isNotEmpty);
  });

  test('empty backend catalog keeps the bundled one', () {
    applyActivityCatalog([]);
    expect(activityCatalog, same(bundledActivityCatalog));
  });

  test('ActivityApi loads catalog, detail and image urls', () async {
    final api = ActivityApi(
      baseUrl: 'http://host:8000',
      client: MockClient((request) async {
        final body = request.url.path == '/activities'
            ? [_summary]
            : {
                ..._summary,
                'goal': 'Kỹ năng phát triển: Kích thích xúc giác.',
                'materials': 'Một chai sữa dưỡng thể cho bé.',
                'materialItems': ['Một chai sữa dưỡng thể cho bé'],
                'needsAdult': true,
                'lyrics': null,
                'sections': [
                  {'title': 'Chuẩn bị', 'body': '- **Không gian:** Trên giường.'},
                ],
                'steps': [
                  {
                    'number': 1,
                    'title': null,
                    'instruction': 'Xoa bóp da đầu.',
                    'imageUrl': '/static/activities/g001/step-1.jpg',
                  },
                ],
                'media': [
                  {
                    'mediaType': 'image',
                    'url': '/static/activities/g001/main.jpg',
                    'caption': null,
                  },
                ],
              };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final catalog = await api.fetchCatalog();
    expect(catalog.single.remote, isTrue);
    expect(catalog.single.groupId, 'g0');

    final detail = await api.fetchDetail(catalog.single.id);
    expect(detail.steps.single.imageUrl, '/static/activities/g001/step-1.jpg');
    expect(detail.guide.map((s) => s.$1), [
      'Mục tiêu',
      'Chuẩn bị',
      'Các bước thực hiện',
    ]);
    expect(
      api.imageUrl(detail.media.single),
      'http://host:8000/static/activities/g001/main.jpg',
    );
  });
}
