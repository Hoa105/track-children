/// A caregiver's relationship to the child — used at registration, in
/// account settings and when inviting someone to a child's profile (F23).
enum ParentRole {
  mother('Mẹ'),
  father('Bố'),
  guardian('Người giám hộ khác');

  const ParentRole(this.label);
  final String label;
}
