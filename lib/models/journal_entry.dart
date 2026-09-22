import 'assessment_domain.dart';

enum JournalMood { happy, normal, fussy }

extension JournalMoodX on JournalMood {
  String get label => switch (this) {
        JournalMood.happy => 'Vui vẻ',
        JournalMood.normal => 'Bình thường',
        JournalMood.fussy => 'Quấy',
      };
}

class JournalEntry {
  final String id;
  final String childId;
  final DateTime date;
  final String? photoPath;
  final JournalMood mood;
  final List<AssessmentDomain> domains;
  final String note;

  const JournalEntry({
    required this.id,
    required this.childId,
    required this.date,
    this.photoPath,
    required this.mood,
    required this.domains,
    required this.note,
  });

  JournalEntry copyWith({
    DateTime? date,
    String? photoPath,
    JournalMood? mood,
    List<AssessmentDomain>? domains,
    String? note,
  }) =>
      JournalEntry(
        id: id,
        childId: childId,
        date: date ?? this.date,
        photoPath: photoPath ?? this.photoPath,
        mood: mood ?? this.mood,
        domains: domains ?? this.domains,
        note: note ?? this.note,
      );
}
