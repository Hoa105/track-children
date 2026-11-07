import 'dart:math';

const assessmentAges = [2, 4, 6, 9, 12, 15, 18, 24, 30, 36, 48, 60];
const assessmentDomains = {
  'gross_motor': 'Vận động thô',
  'fine_motor': 'Vận động tinh',
  'language_communication': 'Ngôn ngữ và giao tiếp',
  'cognitive': 'Nhận thức',
  'social_emotional': 'Cảm xúc và xã hội',
};
const assessmentAnswers = {
  'achieved': 'Đã làm được',
  'not_yet': 'Chưa làm được',
  'not_observed': 'Chưa quan sát',
};
DateTime monthAnniversary(DateTime birth, int months) {
  final m = DateTime(birth.year, birth.month + months, 1);
  final last = DateTime(m.year, m.month + 1, 0).day;
  return DateTime(m.year, m.month, min(birth.day, last));
}

int? assessmentAge(DateTime birth, DateTime now) {
  if (now.isBefore(birth) || !now.isBefore(monthAnniversary(birth, 61))) {
    return null;
  }
  for (final m in assessmentAges.reversed) {
    if (!now.isBefore(monthAnniversary(birth, m))) return m;
  }
  return null;
}

String assessmentDate(dynamic raw, {bool time = false}) {
  if (raw == null) return '—';
  final d = DateTime.parse(raw.toString()).toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}${time ? ' · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : ''}';
}

String assessmentId() {
  final r = Random.secure();
  final bytes = List.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

Map<String, dynamic> assessmentMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

class AssessmentAttempt {
  AssessmentAttempt(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  int get age => data['age_months'] as int;
  int get version => data['version'] as int;
  bool get completed => data['status'] == 'completed';
  bool get editable => data['editable'] == true;
  List<Map<String, dynamic>> get questions =>
      (data['questions'] as List).map(assessmentMap).toList();
  Map<String, String> get answers =>
      Map<String, String>.from(data['answers'] as Map);
  String? get regression => data['regression'] as String?;
  String? get concern => data['caregiver_concern'] as String?;
  Map<String, dynamic>? get result =>
      data['result'] == null ? null : assessmentMap(data['result']);
}

class AssessmentProblem implements Exception {
  const AssessmentProblem(this.message, {this.conflict = false});
  final String message;
  final bool conflict;
  @override
  String toString() => message;
}
