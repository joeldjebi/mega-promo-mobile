import 'package:shared_preferences/shared_preferences.dart';

class AppOnboardingService {
  static const _seenKey = 'app_intro_onboarding_seen_v1';

  const AppOnboardingService._();

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
