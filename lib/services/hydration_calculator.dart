import '../models/user_profile.dart';

class HydrationCalculator {
  // Based on weight-adjusted formula with gender and activity modifiers.
  // Men: ~35ml/kg, Women: ~31ml/kg as baseline (sedentary).
  static double dailyGoalMl(UserProfile profile) {
    final double base = profile.gender == Gender.male
        ? profile.weightKg * 35
        : profile.weightKg * 31;

    final double activityBonus = switch (profile.activityLevel) {
      ActivityLevel.sedentary => 0,
      ActivityLevel.moderate => 500,
      ActivityLevel.active => 1000,
    };

    return base + activityBonus;
  }

  static int reminderCount(UserProfile profile, double goalMl) {
    final count = (goalMl / profile.cupSizeMl).ceil();
    return count.clamp(2, 20);
  }

  // Returns the next scheduled reminder after now, or null if none remain today.
  static DateTime? nextReminderTime(UserProfile profile, double goalMl,
      {double consumedMl = 0}) {
    final now = DateTime.now();
    return reminderTimesFromNow(profile, goalMl, consumedMl)
        .cast<DateTime?>()
        .firstOrNull;
  }

  // Fixed schedule across full wake window (used for settings display).
  static List<DateTime> reminderTimes(UserProfile profile, double goalMl) {
    final now = DateTime.now();
    final wake = DateTime(
        now.year, now.month, now.day, profile.wakeHour, profile.wakeMinute);
    final sleep = DateTime(
        now.year, now.month, now.day, profile.sleepHour, profile.sleepMinute);

    final count = reminderCount(profile, goalMl);
    final windowMinutes = sleep.difference(wake).inMinutes;
    final intervalMinutes = windowMinutes ~/ (count + 1);

    return List.generate(
      count,
      (i) => wake.add(Duration(minutes: intervalMinutes * (i + 1))),
    );
  }

  // Dynamic schedule: spaces remaining drinks across remaining wake time.
  static List<DateTime> reminderTimesFromNow(
      UserProfile profile, double goalMl, double consumedMl) {
    final now = DateTime.now();
    final wake = DateTime(
        now.year, now.month, now.day, profile.wakeHour, profile.wakeMinute);
    final sleep = DateTime(
        now.year, now.month, now.day, profile.sleepHour, profile.sleepMinute);
    if (now.isAfter(sleep)) return [];
    // If called before wake time (e.g. midnight WorkManager run), start from wake.
    final start = now.isBefore(wake) ? wake : now;
    return reminderTimesFrom(profile, goalMl, consumedMl, start, sleep);
  }

  // Schedule reminders between [start] and [sleep] for a given day.
  static List<DateTime> reminderTimesFrom(UserProfile profile, double goalMl,
      double consumedMl, DateTime start, DateTime sleep) {
    if (start.isAfter(sleep)) return [];
    final remainingMl = (goalMl - consumedMl).clamp(0.0, double.infinity);
    if (remainingMl <= 0) return [];
    const minIntervalMinutes = 20;
    final rawCount =
        (remainingMl / profile.cupSizeMl).ceil().clamp(1, 20);
    final windowMinutes = sleep.difference(start).inMinutes;
    if (windowMinutes <= 0) return [];
    final maxByInterval = (windowMinutes / minIntervalMinutes).floor().clamp(1, 20);
    final count = rawCount < maxByInterval ? rawCount : maxByInterval;
    final intervalMinutes = (windowMinutes / (count + 1)).round().clamp(minIntervalMinutes, windowMinutes);
    return List.generate(
      count,
      (i) => start.add(Duration(minutes: intervalMinutes * (i + 1))),
    );
  }

  // 0.0–1.0 fraction of the goal that should have been consumed by now.
  static double expectedProgressNow(UserProfile profile) {
    final now = DateTime.now();
    final wake = DateTime(
        now.year, now.month, now.day, profile.wakeHour, profile.wakeMinute);
    final sleep = DateTime(
        now.year, now.month, now.day, profile.sleepHour, profile.sleepMinute);
    if (now.isBefore(wake)) return 0.0;
    if (now.isAfter(sleep)) return 1.0;
    final total = sleep.difference(wake).inSeconds;
    final elapsed = now.difference(wake).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  // Display helpers
  static String formatMl(double ml, UnitSystem units) {
    if (units == UnitSystem.metric) {
      return ml >= 1000
          ? '${(ml / 1000).toStringAsFixed(1)} L'
          : '${ml.round()} ml';
    } else {
      final oz = ml / 29.5735;
      return '${oz.toStringAsFixed(1)} fl oz';
    }
  }

  static double mlToDisplay(double ml, UnitSystem units) =>
      units == UnitSystem.metric ? ml : ml / 29.5735;

  static double displayToMl(double value, UnitSystem units) =>
      units == UnitSystem.metric ? value : value * 29.5735;
}
