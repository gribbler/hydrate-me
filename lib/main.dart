import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'app.dart';
import 'services/notification_service.dart';

// Called when a notification action is tapped while app is terminated/background.
@pragma('vm:entry-point')
void notificationBackground(NotificationResponse response) {
  NotificationService.handleAction(response);
}

// WorkManager callback — runs in a separate isolate.
@pragma('vm:entry-point')
void workManagerDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    tz.initializeTimeZones();
    final localTz = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(localTz));
    // Must initialise the plugin before using it in a background isolate.
    await NotificationService.initialize(notificationBackground);
    if (taskName == 'daily_reschedule') {
      await NotificationService.scheduleTodayReminders(force: true);
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final localTz = (await FlutterTimezone.getLocalTimezone()).identifier;
  tz.setLocalLocation(tz.getLocation(localTz));

  await NotificationService.initialize(notificationBackground);

  // Request permissions without crashing if unavailable on this Android version.
  try {
    await NotificationService.requestPermission();
  } catch (_) {}

  try {
    await Workmanager().initialize(workManagerDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'daily_reschedule',
      'daily_reschedule',
      frequency: const Duration(hours: 24),
      initialDelay: _untilMidnight(),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  } catch (_) {}

  // Schedule today's reminders on app open.
  try {
    await NotificationService.scheduleTodayReminders();
  } catch (_) {}

  runApp(const HydrateMeApp());
}

Duration _untilMidnight() {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day + 1);
  return midnight.difference(now);
}
