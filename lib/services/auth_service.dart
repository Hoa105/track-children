import '../models/app_user.dart';

abstract class AuthService {
  AppUser get currentUser;
  Future<void> updateProfile({String? name, String? username, String? email});
}

/// Seeded with a placeholder real account (name "Mai") since this prototype
/// has no real registration/login backend — [LoginScreen] registration
/// overwrites these fields via [updateProfile] instead of creating a
/// separate account record.
class MockAuthService implements AuthService {
  AppUser _currentUser = AppUser(name: 'Mai', username: 'mai_mom', email: 'mai@gmail.com');

  @override
  AppUser get currentUser => _currentUser;

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
