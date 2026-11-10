import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../services/demo_store.dart';
import 'assessment_models.dart';
import 'assessment_reminders.dart';

abstract class AssessmentRepository {
  bool get isDemo;
  Future<Map<String, dynamic>> overview(String childId);
  Future<Map<String, dynamic>> history(
    String childId, {
    int? age,
    int offset = 0,
  });
  Future<AssessmentAttempt> start(
    String childId,
    String requestId, {
    bool guidance = false,
  });
  Future<AssessmentAttempt> load(String childId, String id);
  Future<AssessmentAttempt> save(
    String childId,
    AssessmentAttempt attempt,
    Map<String, String> answers,
    String? regression,
    String? concern,
  );
  Future<AssessmentAttempt> complete(
    String childId,
    AssessmentAttempt attempt,
  );
}

AssessmentRepository assessmentRepository() =>
    AuthService.instance.demoMode || !AuthService.instance.signedIn
    ? DemoAssessmentRepository()
    : ApiAssessmentRepository();

class ApiAssessmentRepository implements AssessmentRepository {
  ApiAssessmentRepository({AuthService? auth})
    : _auth = auth ?? AuthService.instance;
  final AuthService _auth;
  @override
  bool get isDemo => false;
  String path(String child, [String suffix = '']) =>
      '/children/$child/assessment$suffix';
  String get tz => 'tz=${DateTime.now().timeZoneOffset.inMinutes}';
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      return await _auth.authorizedRequest(method, path, body: body);
    } on AuthException catch (e) {
      throw AssessmentProblem(switch (e.code) {
        'HTTP_409' => 'Bài đã thay đổi hoặc bé đã sang mốc mới. Hãy tải lại để xem dữ liệu mới nhất.',
        'HTTP_503' =>
          'Chưa có nội dung đang xuất bản cho mốc này. Vui lòng thử lại sau.',
        'HTTP_403' => 'Bạn chỉ có quyền xem đánh giá của bé.',
        'HTTP_404' =>
          'Không tìm thấy bài đánh giá hoặc bạn không có quyền truy cập.',
        'HTTP_422' =>
          'Bài chưa đủ thông tin. Kiểm tra các đáp án và hai câu hỏi bổ sung.',
        'NETWORK_ERROR' => 'Chưa kết nối được máy chủ. Đáp án chưa lưu vẫn được giữ trên màn hình.',
        _ => e.toString(),
      }, conflict: e.code == 'HTTP_409');
    }
  }

  @override
  Future<Map<String, dynamic>> overview(String c) async {
    final value = await request('GET', path(c, '/overview?$tz'));
    AssessmentReminders.instance.put(c, value);
    return value;
  }

  @override
  Future<Map<String, dynamic>> history(String c, {int? age, int offset = 0}) =>
      request(
        'GET',
        path(c, '/assessments?offset=$offset${age == null ? '' : '&age=$age'}'),
      );
  @override
  Future<AssessmentAttempt> start(
    String c,
    String id, {
    bool guidance = false,
  }) async => AssessmentAttempt(
    await request('POST', path(c, '/assessments?$tz'), {
      'id': id,
      'chronological_guidance_confirmed': guidance,
    }),
  );
  @override
  Future<AssessmentAttempt> load(String c, String id) async =>
      AssessmentAttempt(await request('GET', path(c, '/assessments/$id?$tz')));
  @override
  Future<AssessmentAttempt> save(
    String c,
    AssessmentAttempt a,
    Map<String, String> answers,
    String? regression,
    String? concern,
  ) async => AssessmentAttempt(
    await request('PATCH', path(c, '/assessments/${a.id}?$tz'), {
      'expected_version': a.version,
      'answers': answers,
      'regression': regression,
      'caregiver_concern': concern,
    }),
  );
  @override
  Future<AssessmentAttempt> complete(String c, AssessmentAttempt a) async =>
      AssessmentAttempt(
        await request('POST', path(c, '/assessments/${a.id}/complete?$tz'), {
          'expected_version': a.version,
        }),
      );
}

/// Only fictional demo sessions use this device-local repository. Never a fallback
/// for failed authenticated requests. Each child/account has its own stored history.
class DemoAssessmentRepository implements AssessmentRepository {
  DemoAssessmentRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  @override
  bool get isDemo => true;
  String key(String c) =>
      'assessment_demo_v1/${DemoStore.instance.parent['id']}/$c';
  Future<List<Map<String, dynamic>>> rows(String c) async {
    final p = await SharedPreferences.getInstance();
    var raw = p.getString(key(c));
    final legacyKey = key(c).replaceFirst('assessment_demo_v1/', 'development_demo_v1/');
    if (raw == null) {
      raw = p.getString(legacyKey);
      if (raw != null && await p.setString(key(c), raw)) {
        await p.remove(legacyKey);
      }
    }
    return (jsonDecode(raw ?? '[]') as List)
        .map(assessmentMap)
        .toList();
  }

  Future<void> write(String c, List<Map<String, dynamic>> data) async {
    final p = await SharedPreferences.getInstance();
    if (!await p.setString(key(c), jsonEncode(data))) {
      throw const AssessmentProblem(
        'Chưa lưu được trên thiết bị. Vui lòng thử lại.',
      );
    }
  }

  DateTime birth(String c) => DateTime.parse(
    DemoStore.instance.childById(c)!['date_of_birth'] as String,
  );
  int? age(String c) => assessmentAge(birth(c), _clock());
  Future<List<Map<String, dynamic>>> bank() async =>
      (jsonDecode(
                await rootBundle.loadString(
                  'assets/assessment/demo-bank.json',
                ),
              )['rows']
              as List)
          .map(assessmentMap)
          .toList();
  AssessmentAttempt present(Map<String, dynamic> row, String c) =>
      AssessmentAttempt({
        ...row,
        'editable':
            row['status'] == 'in_progress' && row['age_months'] == age(c),
      });
  @override
  Future<Map<String, dynamic>> overview(String c) async {
    final data = await rows(c), a = age(c), b = birth(c);
    final questions = (await bank())
        .where((x) => x['kind'] == 'skill' && x['age_months'] == a)
        .toList();
    final drafts = data.where((x) => x['status'] == 'in_progress').toList();
    final current = drafts.where((x) => x['age_months'] == a);
    final completed = data.where((x) => x['status'] == 'completed').toList()
      ..sort(
        (a, b) => (b['completed_at'] as String).compareTo(
          a['completed_at'] as String,
        ),
      );
    final Map<String, dynamic> value = {
      'age_months': a,
      'completed_milestones': completed
          .map((x) => x['age_months'])
          .toSet()
          .toList(),
      'latest_completed': completed
          .where((x) => x['age_months'] == a)
          .map((x) => {'id': x['id']})
          .firstOrNull,
      'can_edit': true,
      'guidance_required': false,
      'set': a == null ? null : {'id': 'demo-$a', 'count': questions.length},
      'draft': current.isEmpty ? null : present(current.last, c).data,
      'past_drafts': drafts
          .where((x) => x['age_months'] != a)
          .map((x) => {'id': x['id'], 'age_months': x['age_months']})
          .toList(),
      'today': _clock().toIso8601String(),
      'milestones': [
        for (var i = 0; i < assessmentAges.length; i++)
          {
            'age_months': assessmentAges[i],
            'opens_on': monthAnniversary(
              b,
              assessmentAges[i],
            ).toIso8601String(),
            'closes_on': monthAnniversary(
              b,
              i + 1 < assessmentAges.length ? assessmentAges[i + 1] : 61,
            ).toIso8601String(),
          },
      ],
    };
    AssessmentReminders.instance.put(c, value);
    return value;
  }

  @override
  Future<Map<String, dynamic>> history(
    String c, {
    int? age,
    int offset = 0,
  }) async {
    final data = (await rows(c))
        .where((x) => x['status'] == 'completed')
        .toList();
    data.sort(
      (a, b) =>
          (b['completed_at'] as String).compareTo(a['completed_at'] as String),
    );
    final filtered = data
        .where((x) => age == null || x['age_months'] == age)
        .toList();
    return {
      'items': filtered
          .skip(offset)
          .take(20)
          .map(
            (x) => {
              'id': x['id'],
              'age_months': x['age_months'],
              'completed_at': x['completed_at'],
              'attempt_number': data
                  .where(
                    (p) =>
                        p['age_months'] == x['age_months'] &&
                        (p['completed_at'] as String).compareTo(
                              x['completed_at'] as String,
                            ) <=
                            0,
                  )
                  .length,
              'summary': x['result']['sections']['overview'],
            },
          )
          .toList(),
      'has_more': filtered.length > offset + 20,
    };
  }

  @override
  Future<AssessmentAttempt> load(String c, String id) async =>
      present((await rows(c)).firstWhere((x) => x['id'] == id), c);
  @override
  Future<AssessmentAttempt> start(
    String c,
    String id, {
    bool guidance = false,
  }) async {
    final data = await rows(c), a = age(c);
    final prior = data.where(
      (x) =>
          x['id'] == id ||
          (x['status'] == 'in_progress' && x['age_months'] == a),
    );
    if (prior.isNotEmpty) return present(prior.last, c);
    if (a == null) {
      throw const AssessmentProblem(
        'Hiện chưa có mốc phù hợp với tuổi của bé.',
      );
    }
    final qs = (await bank())
        .where((x) => x['kind'] == 'skill' && x['age_months'] == a)
        .toList();
    final row = {
      'id': id,
      'age_months': a,
      'status': 'in_progress',
      'started_at': _clock().toIso8601String(),
      'completed_at': null,
      'version': 1,
      'answers': <String, String>{},
      'regression': null,
      'caregiver_concern': null,
      'questions': qs
          .map(
            (q) => {
              'id': q['stable_code'],
              'code': q['stable_code'],
              'domain': q['app_domain'],
              'payload': q['payload'],
              'source_refs': q['source_refs'],
            },
          )
          .toList(),
      'result': null,
    };
    data.add(row);
    await write(c, data);
    return present(row, c);
  }

  @override
  Future<AssessmentAttempt> save(
    String c,
    AssessmentAttempt a,
    Map<String, String> answers,
    String? regression,
    String? concern,
  ) async {
    final data = await rows(c), row = data.firstWhere((x) => x['id'] == a.id);
    if (!present(row, c).editable || row['version'] != a.version) {
      throw const AssessmentProblem(
        'Bài đã thay đổi hoặc bé đã sang mốc mới.',
        conflict: true,
      );
    }
    row.addAll({
      'answers': answers,
      'regression': regression,
      'caregiver_concern': concern,
      'version': a.version + 1,
    });
    await write(c, data);
    return present(row, c);
  }

  @override
  Future<AssessmentAttempt> complete(String c, AssessmentAttempt a) async {
    final data = await rows(c), row = data.firstWhere((x) => x['id'] == a.id);
    if (row['status'] == 'completed') return present(row, c);
    if (!present(row, c).editable || row['version'] != a.version) {
      throw const AssessmentProblem(
        'Bài đã thay đổi hoặc bé đã sang mốc mới.',
        conflict: true,
      );
    }
    if (a.answers.length != a.questions.length ||
        a.regression == null ||
        a.concern == null) {
      throw const AssessmentProblem(
        'Hãy trả lời đủ các kỹ năng và hai câu hỏi bổ sung.',
      );
    }
    row.addAll({
      'status': 'completed',
      'completed_at': _clock().toIso8601String(),
      'version': a.version + 1,
      'result': _demoResult(a),
    });
    await write(c, data);
    return present(row, c);
  }

  Map<String, dynamic> _demoResult(AssessmentAttempt a) {
    final counts = {
      for (final k in assessmentAnswers.keys)
        k: a.answers.values.where((v) => v == k).length,
    };
    final n = counts['not_yet']!, o = counts['not_observed']!;
    final contact = n > 0 || a.regression != 'no' || a.concern == 'yes';
    final notes = [
      for (final q in a.questions)
        if (a.answers[q['code']] != 'achieved')
          {
            'question_id': q['code'],
            'skill_name':
                q['payload']['skill_name'] ?? q['payload']['question_vi'],
            'domain': q['domain'],
            'status': a.answers[q['code']],
          },
    ];
    final domains = a.questions
        .where((q) => a.answers[q['code']] == 'not_yet')
        .map((q) => (assessmentDomains[q['domain']] ?? '').toLowerCase())
        .toSet()
        .join(', ');
    final paragraphs = [
      {
        'id': 'skills',
        'text': n > 0
            ? 'Kết quả bài đánh giá ghi nhận bé còn kỹ năng chưa làm được về $domains.'
            : o > 0
            ? 'Các kỹ năng chưa quan sát còn thiếu thông tin để nhận xét đầy đủ khả năng của bé.'
            : 'Kết quả bài đánh giá ghi nhận bé đã làm được tất cả kỹ năng được hỏi ở mốc ${a.age} tháng.',
      },
      if (a.regression == 'yes')
        {
          'id': 'regression',
          'text': 'Thông tin bổ sung có ghi nhận mất kỹ năng từng có, cần được bác sĩ đánh giá sớm.',
        },
      if (a.concern == 'yes')
        {
          'id': 'concern',
          'text':
              'Lo ngại về phát triển cần được xem xét cùng kết quả kỹ năng.',
        },
      {
        'id': 'scope',
        'text': 'Đây là kết quả minh họa trong chế độ trải nghiệm, không dùng để đánh giá trẻ thực tế.',
      },
    ];
    return {
      'sections': {
        'overview': {'total': a.questions.length, ...counts},
        'skills_to_note': {'total': notes.length, 'all': notes},
        'overall_comment': {'paragraphs': paragraphs, 'sources': []},
        'next_steps': {
          'action_plan': {
            'actions': [
              if (contact)
                {
                  'id': 'contact',
                  'body': 'Trao đổi với bác sĩ hoặc nhân viên y tế có chuyên môn về các kỹ năng cần chú ý và những điều gia đình băn khoăn.',
                  'items': [],
                },
              if (contact)
                {
                  'id': 'prepare',
                  'body': '',
                  'items': [
                    'Các kỹ năng bé chưa làm được và thời điểm quan sát.',
                    'Những thay đổi về kỹ năng hoặc điều gia đình lo ngại.',
                    'Kết quả bài đánh giá này.',
                  ],
                },
              if (o > 0)
                {
                  'id': 'observe',
                  'body': 'Tạo cơ hội quan sát những kỹ năng chưa rõ trong sinh hoạt thường ngày. Không cần chờ quan sát đủ mới trao đổi với bác sĩ nếu có lo ngại.',
                  'items': [],
                },
              if (!contact && o == 0)
                {
                  'id': 'continue',
                  'body': 'Tiếp tục vui chơi, trò chuyện và theo dõi bé; chia sẻ kết quả trong lần khám định kỳ.',
                  'items': [],
                },
            ],
            'observation_timing': '',
          },
        },
      },
    };
  }
}
