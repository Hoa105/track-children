/// Who a backend call is made for: backend uuids plus the local profile maps,
/// so the remote can register the parent + child before syncing.
class VaccinationAccount {
  const VaccinationAccount({
    required this.userId,
    required this.childId,
    required this.parent,
    required this.child,
  });

  /// account.users / child.children uuids on the backend.
  final String userId, childId;

  /// DemoStore maps (`fullName`, `email` / `full_name`, `date_of_birth`, `gender`).
  final Map<String, dynamic> parent, child;
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  /// 0 = no response (offline / timeout).
  final int statusCode;
  final String message;

  /// The backend refused the data itself; retrying the same request won't help.
  bool get rejected => statusCode >= 400 && statusCode < 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Backend storage for a child's vaccination book (implemented by VaccinationApi).
abstract class VaccinationRemote {
  /// Makes sure the parent + child exist on the backend (dev: PUT /dev/profiles).
  Future<void> link(VaccinationAccount account);
  Future<List<Map<String, dynamic>>> fetch(VaccinationAccount account);
  Future<void> save(
    VaccinationAccount account,
    List<Map<String, dynamic>> records,
  );
  Future<void> remove(VaccinationAccount account, String doseId);

  /// Vaccines the child follows / skips (only entries that differ from the default).
  Future<Map<String, bool>> fetchPlans(VaccinationAccount account);
  Future<void> savePlans(VaccinationAccount account, Map<String, bool?> plans);
}
