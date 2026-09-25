import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/app_state.dart';
import 'prayer_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _daysAhead = 7;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    if (!_supported) return;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  static Future<bool> requestPermissions() async {
    if (!_ready) return false;
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      if (await android.canScheduleExactNotifications() != true) {
        await android.requestExactAlarmsPermission();
      }
      return granted;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final mac = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ??
        await mac?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  static const _prayerDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_alarms',
      'Prayer alarms',
      channelDescription: 'Alerts at the start of each prayer time',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(presentSound: true, interruptionLevel: InterruptionLevel.timeSensitive),
    macOS: DarwinNotificationDetails(presentSound: true),
  );

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Durood and Jumu\'ah reminders',
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  /// Cancels everything and schedules alarms for the next [_daysAhead] days.
  /// Called on launch and whenever a relevant setting changes.
  static Future<void> scheduleAll(AppState s) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final mode = await _android?.canScheduleExactNotifications() == false
          ? AndroidScheduleMode.inexactAllowWhileIdle
          : AndroidScheduleMode.exactAllowWhileIdle;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (var d = 0; d < _daysAhead; d++) {
        final date = today.add(Duration(days: d));
        final times = s.timesFor(date);
        for (final salah in Salah.values) {
          if (s.alarms[salah] != true) continue;
          final at = times[salah].subtract(Duration(minutes: s.alarmOffset));
          if (at.isBefore(now)) continue;
          final lead = s.alarmOffset == 0 ? 'It\'s time for' : '${s.alarmOffset} min until';
          await _schedule(
            id: d * 10 + salah.index,
            at: at,
            title: salah == Salah.sunrise ? 'Sunrise' : '${salah.label} · ${salah.arabic}',
            body: salah == Salah.sunrise
                ? 'Fajr time has ended.'
                : '$lead ${salah.label} — ${s.location.name.split(',').first}',
            details: _prayerDetails,
            mode: mode,
          );
        }
        if (s.jumuahReminder && date.weekday == DateTime.friday) {
          final at = times[Salah.dhuhr].subtract(const Duration(minutes: 60));
          if (at.isAfter(now)) {
            await _schedule(
              id: 800 + d,
              at: at,
              title: 'Jumu\'ah Mubarak',
              body: 'Jumu\'ah prayer is in an hour. Recite Surah Al-Kahf and send durood.',
              details: _reminderDetails,
              mode: mode,
            );
          }
        }
      }

      if (s.duroodReminder) {
        var at = DateTime(today.year, today.month, today.day, s.duroodTime.hour, s.duroodTime.minute);
        if (at.isBefore(now)) at = at.add(const Duration(days: 1));
        await _schedule(
          id: 900,
          at: at,
          title: 'Send durood',
          body: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ — O Allah, send blessings upon Muhammad ﷺ',
          details: _reminderDetails,
          mode: mode,
          daily: true,
        );
      }
    } catch (e) {
      debugPrint('Scheduling failed: $e');
    }
  }

  static Future<void> _schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required NotificationDetails details,
    required AndroidScheduleMode mode,
    bool daily = false,
  }) =>
      _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        title: title,
        body: body,
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: daily ? DateTimeComponents.time : null,
      );
}
