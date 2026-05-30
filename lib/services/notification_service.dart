import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/drink_log.dart';
import '../models/user_profile.dart';
import 'database_service.dart';
import 'hydration_calculator.dart';
import 'preferences_service.dart';

const _channelId = 'hydrate_me_reminders';
const _channelName = 'Hydration Reminders';

// Notification action IDs
const actionLog = 'action_log';
const actionSnooze = 'action_snooze';
const actionDone = 'action_done';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize(
      DidReceiveBackgroundNotificationResponseCallback onBackground) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onForegroundAction,
      onDidReceiveBackgroundNotificationResponse: onBackground,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          importance: Importance.high,
          enableVibration: true,
        ));
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleTodayReminders({bool force = false}) async {
    final profile = await PreferencesService.loadProfile();
    if (profile == null) return;
    if (await PreferencesService.isDoneForToday()) return;

    final pending = await _plugin.pendingNotificationRequests();

    // Skip rescheduling today if reminders are already queued — but always
    // ensure tomorrow is pre-loaded so the next day starts without app open.
    if (!force && pending.isNotEmpty) {
      final hasTomorrow = pending.any((n) => n.id >= 200 && n.id < 220);
      if (!hasTomorrow) await _scheduleTomorrow(profile);
      return;
    }

    await cancelAllReminders();

    final goalMl = HydrationCalculator.dailyGoalMl(profile);
    final logs = await DatabaseService.logsForDay(DateTime.now());
    final consumedMl = logs.fold<double>(0, (sum, l) => sum + l.amountMl);
    final times = HydrationCalculator.reminderTimesFromNow(
        profile, goalMl, consumedMl);

    await PreferencesService.saveScheduledReminderTimes(times);
    for (int i = 0; i < times.length; i++) {
      await _scheduleOne(i + 1, times[i], profile.cupSizeMl, profile.unitSystem);
    }

    // Pre-schedule tomorrow so reminders restart without needing the app open.
    await _scheduleTomorrow(profile);
  }

  static Future<void> _scheduleTomorrow(UserProfile profile) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final wake = DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
        profile.wakeHour, profile.wakeMinute);
    final sleep = DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
        profile.sleepHour, profile.sleepMinute);
    final goalMl = HydrationCalculator.dailyGoalMl(profile);
    // Assume full goal for tomorrow (no drinks logged yet).
    final times = HydrationCalculator.reminderTimesFrom(
        profile, goalMl, 0, wake, sleep);
    for (int i = 0; i < times.length; i++) {
      // IDs 200+ to avoid colliding with today (1–20) and snooze (100+).
      await _scheduleOne(200 + i + 1, times[i], profile.cupSizeMl, profile.unitSystem);
    }
  }

  static Future<void> _scheduleOne(
    int id,
    DateTime when,
    double cupSizeMl,
    UnitSystem units,
  ) async {
    final label = HydrationCalculator.formatMl(cupSizeMl, units);
    await _plugin.zonedSchedule(
      id,
      'Time to hydrate! 💧',
      'Drink $label of water',
      tz.TZDateTime.from(when, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          actions: const [
            AndroidNotificationAction(actionLog, 'Log drink'),
            AndroidNotificationAction(actionSnooze, 'Snooze 15 min'),
            AndroidNotificationAction(actionDone, 'Done for today'),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$id,$cupSizeMl',
    );
  }

  static Future<void> scheduleSnooze(int originalId, double cupSizeMl) async {
    final profile = await PreferencesService.loadProfile();
    final units = profile?.unitSystem ?? UnitSystem.metric;
    final snoozeTime = DateTime.now().add(const Duration(minutes: 15));
    // Use ID 100+ range to avoid colliding with daily notifications
    await _scheduleOne(100 + originalId, snoozeTime, cupSizeMl, units);
  }

  static Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
  }

  static Future<void> cancelOne(int id) async {
    await _plugin.cancel(id);
  }

  static void _onForegroundAction(NotificationResponse response) {
    handleAction(response);
  }

  static Future<void> handleAction(NotificationResponse response) async {
    final payload = response.payload ?? '';
    final parts = payload.split(',');
    final id = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final cupSizeMl =
        double.tryParse(parts.length > 1 ? parts[1] : '') ?? 250.0;

    switch (response.actionId) {
      case actionLog:
        await DatabaseService.logDrink(DrinkLog(
          timestamp: DateTime.now(),
          amountMl: cupSizeMl,
        ));
        await cancelOne(id);
        await scheduleTodayReminders(force: true);
      case actionSnooze:
        await cancelOne(id);
        await scheduleSnooze(id, cupSizeMl);
      case actionDone:
        await PreferencesService.setDoneForToday();
        await cancelAllReminders();
      case null:
        // Tapped notification body — app opens, nothing extra needed.
        break;
    }
  }
}
