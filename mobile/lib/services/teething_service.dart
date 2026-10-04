import '../models/child.dart';
import '../models/tooth.dart';

abstract class TeethingService {
  /// Erupted teeth for [child], keyed by [PrimaryTooth.id].
  Future<Map<String, ToothRecord>> getRecords(Child child);
  Future<void> saveRecord(ToothRecord record);
  Future<void> removeRecord(String childId, String toothId);
}

class MockTeethingService implements TeethingService {
  final List<ToothRecord> _records = [];
  final Set<String> _seededChildren = {};

  /// Demo data, seeded lazily because dob is relative to now. A few pairs
  /// have only one side erupted so the add screen's disabled side shows up:
  /// - c1 (~18 tháng): all incisors + upper first molars, plus only the right
  ///   lower first molar and only the left upper canine.
  /// - c2 (~5 tháng): only the right lower central incisor.
  void _seed(Child child) {
    if (!_seededChildren.add(child.id)) return;
    for (final tooth in PrimaryTooth.all) {
      final erupted = switch (child.id) {
        'c1' => tooth.type == ToothType.centralIncisor ||
            tooth.type == ToothType.lateralIncisor ||
            (tooth.type == ToothType.firstMolar && tooth.jaw == Jaw.upper) ||
            (tooth.type == ToothType.firstMolar && tooth.jaw == Jaw.lower && tooth.side == JawSide.right) ||
            (tooth.type == ToothType.canine && tooth.jaw == Jaw.upper && tooth.side == JawSide.left),
        'c2' => tooth.type == ToothType.centralIncisor && tooth.jaw == Jaw.lower && tooth.side == JawSide.right,
        _ => false,
      };
      if (!erupted) continue;
      final (from, _) = tooth.eruptionMonths;
      _records.add(ToothRecord(
        childId: child.id,
        toothId: tooth.id,
        eruptedDate: DateTime(child.dob.year, child.dob.month + from, child.dob.day),
      ));
    }
  }

  @override
  Future<Map<String, ToothRecord>> getRecords(Child child) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _seed(child);
    return {
      for (final r in _records.where((r) => r.childId == child.id)) r.toothId: r,
    };
  }

  @override
  Future<void> saveRecord(ToothRecord record) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _records.removeWhere((r) => r.childId == record.childId && r.toothId == record.toothId);
    _records.add(record);
  }

  @override
  Future<void> removeRecord(String childId, String toothId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _records.removeWhere((r) => r.childId == childId && r.toothId == toothId);
  }
}
