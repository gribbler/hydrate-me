import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class PreferencesService {
  static const _profileKey = 'user_profile';
  static const _setupDoneKey = 'setup_done';
  static const _doneForTodayKey = 'done_for_today';

  static Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_profileKey);
    if (json == null) return null;
    return UserProfile.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toMap()));
  }

  static Future<bool> isSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupDoneKey) ?? false;
  }

  static Future<void> markSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupDoneKey, true);
  }

  static Future<bool> isDoneForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_doneForTodayKey);
    if (dateStr == null) return false;
    final saved = DateTime.parse(dateStr);
    final now = DateTime.now();
    return saved.year == now.year &&
        saved.month == now.month &&
        saved.day == now.day;
  }

  static Future<void> setDoneForToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_doneForTodayKey, DateTime.now().toIso8601String());
  }

  static Future<void> clearDoneForToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_doneForTodayKey);
  }

  static Future<void> saveScheduledReminderTimes(List<DateTime> times) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'scheduled_reminder_times',
      times.map((t) => t.toIso8601String()).toList(),
    );
  }

  static Future<DateTime?> loadNextReminderAt() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('scheduled_reminder_times') ?? [];
    final now = DateTime.now();
    for (final s in list) {
      final t = DateTime.tryParse(s);
      if (t != null && t.isAfter(now)) return t;
    }
    return null;
  }
}
