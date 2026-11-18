import 'package:shared_preferences/shared_preferences.dart';

/// Các cài đặt nhỏ lưu trên máy.
class AppPreferences {
  static const _onboardingSeen = 'onboarding_seen';

  /// Ba màn giới thiệu chỉ hiện ở lần mở app đầu tiên.
  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeen) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeen, true);
  }
}
