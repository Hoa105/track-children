import '../models/child.dart';

abstract class ChildService {
  Future<List<Child>> getChildren();
  Future<Child> updateChild(Child child);
  Future<Child> addChild(Child child);
}

class MockChildService implements ChildService {
  final List<Child> _children = [
    Child(
      id: 'c1',
      name: 'Nguyễn Bảo Minh',
      gender: ChildGender.boy,
      dob: DateTime.now().subtract(const Duration(days: 18 * 30 + 12)),
      notes: '',
    ),
    Child(
      id: 'c2',
      name: 'Nguyễn Bảo An',
      gender: ChildGender.girl,
      dob: DateTime.now().subtract(const Duration(days: 5 * 30 + 2)),
      notes: '',
    ),
  ];

  @override
  Future<List<Child>> getChildren() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_children);
  }

  @override
  Future<Child> updateChild(Child child) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _children.indexWhere((c) => c.id == child.id);
    if (index != -1) {
      _children[index] = child;
    }
    return child;
  }

  @override
  Future<Child> addChild(Child child) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final created = Child(
      id: 'c${_children.length + 1}',
      name: child.name,
      gender: child.gender,
      dob: child.dob,
      isPremature: child.isPremature,
      gestationalWeeks: child.gestationalWeeks,
      birthWeightKg: child.birthWeightKg,
      notes: child.notes,
      avatarUrl: child.avatarUrl,
    );
    _children.add(created);
    return created;
  }
}
