enum ParentRole {
  mother('Mẹ'),
  father('Bố'),
  grandfather('Ông'),
  grandmother('Bà'),
  guardian('Người giám hộ khác');

  const ParentRole(this.label);

  final String label;

  // The current registration API accepts mother, father, or guardian.
  String get registrationValue => switch (this) {
    grandfather || grandmother => 'guardian',
    _ => name,
  };
}
