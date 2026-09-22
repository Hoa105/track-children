/// The logged-in parent's own account — separate from [Child], which
/// tracks the children being monitored. `name` is the real name used for
/// greetings; `username` is the public handle shown on community posts and
/// wherever the account itself (not the person) is referenced.
class AppUser {
  String name;
  String username;
  String email;

  AppUser({required this.name, required this.username, required this.email});
}
