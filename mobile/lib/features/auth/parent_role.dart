enum ParentRole {
  mother('Mẹ'),
  father('Bố'),
  grandfather('Ông'),
  grandmother('Bà'),
  guardian('Người giám hộ khác');

  const ParentRole(this.label);

  final String label;

  String get registrationValue =>
      this == ParentRole.guardian ? 'other_guardian' : name;
}
