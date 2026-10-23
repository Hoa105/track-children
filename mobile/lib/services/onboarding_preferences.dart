import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  static const _completedKey = 'track_children_onboarding_completed';

  Future<bool> isCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
  }
}
