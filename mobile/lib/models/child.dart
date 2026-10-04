enum ChildGender { boy, girl }

extension ChildGenderX on ChildGender {
  String get label => this == ChildGender.boy ? 'Bé trai' : 'Bé gái';
}

class Child {
  final String id;
  final String name;
  final ChildGender gender;
  final DateTime dob;
  final bool isPremature;
  final int? gestationalWeeks;
  final double? birthWeightKg;
  final String notes;
  final String? avatarUrl;

  const Child({
    required this.id,
    required this.name,
    required this.gender,
    required this.dob,
    this.isPremature = false,
    this.gestationalWeeks,
    this.birthWeightKg,
    this.notes = '',
    this.avatarUrl,
  });

  /// Human readable age like "18 tháng 12 ngày".
  String ageLabel(DateTime now) {
    final totalDays = now.difference(dob).inDays;
    final months = totalDays ~/ 30;
    final days = totalDays % 30;
    return '$months tháng $days ngày';
  }

  Child copyWith({
    String? name,
    ChildGender? gender,
    DateTime? dob,
    bool? isPremature,
    int? gestationalWeeks,
    double? birthWeightKg,
    String? notes,
    String? avatarUrl,
  }) {
    return Child(
      id: id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      isPremature: isPremature ?? this.isPremature,
      gestationalWeeks: gestationalWeeks ?? this.gestationalWeeks,
      birthWeightKg: birthWeightKg ?? this.birthWeightKg,
      notes: notes ?? this.notes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
