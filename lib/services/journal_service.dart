import '../models/assessment_domain.dart';
import '../models/journal_entry.dart';

abstract class JournalService {
  Future<List<JournalEntry>> getEntries(String childId);
  Future<void> addEntry(JournalEntry entry);
  Future<void> updateEntry(JournalEntry entry);
}

/// Seeded verbatim from prototype_reference.md § "Journal (Nhật ký) entries".
class MockJournalService implements JournalService {
  final List<JournalEntry> _entries = [
    JournalEntry(
      id: 'j1',
      childId: 'c1',
      date: DateTime(2026, 8, 15),
      mood: JournalMood.happy,
      domains: const [AssessmentDomain.fineMotor],
      note: 'Bé tự cầm thìa ăn hết bát cháo!',
    ),
    JournalEntry(
      id: 'j2',
      childId: 'c1',
      date: DateTime(2026, 8, 10),
      mood: JournalMood.happy,
      domains: const [AssessmentDomain.language],
      note: 'Bé gọi "bà" rất rõ khi bà đến chơi.',
    ),
    JournalEntry(
      id: 'j3',
      childId: 'c1',
      date: DateTime(2026, 8, 3),
      mood: JournalMood.normal,
      domains: const [AssessmentDomain.socialEmotional],
      note: 'Lần đầu bé chơi cùng bạn ở công viên.',
    ),
  ];

  @override
  Future<List<JournalEntry>> getEntries(String childId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _entries.where((e) => e.childId == childId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> addEntry(JournalEntry entry) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _entries.add(entry);
  }

  @override
  Future<void> updateEntry(JournalEntry entry) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
    }
  }
}
