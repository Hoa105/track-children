import '../models/app_user.dart';

abstract class AuthService {
  AppUser get currentUser;
  Future<void> updateProfile({String? name, String? username, String? email});

  /// Days between a deletion request and the actual erase (F01.6) — signing
  /// back in during this window cancels the request.
  static const deletionGracePeriod = Duration(days: 30);

  /// When the pending deletion will be carried out, null if none.
  DateTime? get deletionScheduledAt;

  /// Schedules the account and personal data for deletion. Profiles the user
  /// owns must already be handed over or marked for deletion by the caller.
  Future<DateTime> requestAccountDeletion({required String password, String? reason});
}

/// Seeded with a placeholder real account (name "Mai") since this prototype
/// has no real registration/login backend — [LoginScreen] registration
/// overwrites these fields via [updateProfile] instead of creating a
/// separate account record.
class MockAuthService implements AuthService {
  AppUser _currentUser = AppUser(name: 'Mai', username: 'mai_mom', email: 'mai@gmail.com');

  DateTime? _deletionScheduledAt;

  @override
  AppUser get currentUser => _currentUser;

  @override
  DateTime? get deletionScheduledAt => _deletionScheduledAt;

  @override
  Future<DateTime> requestAccountDeletion({required String password, String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Mock: the backend verifies the password and records the reason.
    if (password.length < 6) throw ArgumentError('Mật khẩu không đúng');
    return _deletionScheduledAt = DateTime.now().add(AuthService.deletionGracePeriod);
  }

  @override
  Future<void> updateProfile({String? name, String? username, String? email}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _currentUser = AppUser(
      name: name ?? _currentUser.name,
      username: username ?? _currentUser.username,
      email: email ?? _currentUser.email,
    );
  }
}
