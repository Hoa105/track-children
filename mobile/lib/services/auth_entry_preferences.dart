import 'package:shared_preferences/shared_preferences.dart';

/// Presentation preference only; never used to establish authentication.
class AuthEntryPreferences {
  static const _seenKey = 'track_children_auth_entry_seen';

  Future<bool> takeFirstVisit() async {
    final preferences = await SharedPreferences.getInstance();
    final first = !(preferences.getBool(_seenKey) ?? false);
    await preferences.setBool(_seenKey, true);
    return first;
  }
}
