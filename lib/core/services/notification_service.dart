// ============================================================
// SmartAttend — Notification Service (v1)
// Local push notifications for class reminders & attendance.
// Uses flutter_local_notifications + timezone.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static NotificationService get to => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Init ──────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  // ── Android channel details ───────────────────────────
  static const _classChannel = AndroidNotificationDetails(
    'smartattend_class',
    'Class Reminders',
    channelDescription: 'Upcoming class and attendance alerts',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    icon: '@mipmap/launcher_icon',
  );

  static const _attendanceChannel = AndroidNotificationDetails(
    'smartattend_attendance',
    'Attendance Alerts',
    channelDescription: 'Attendance session open/close alerts',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    icon: '@mipmap/launcher_icon',
  );

  static const _breakChannel = AndroidNotificationDetails(
    'smartattend_break',
    'Break & Lunch',
    channelDescription: 'Break and lunch notifications',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/launcher_icon',
  );

  // ── Immediate Notification ─────────────────────────────
  Future<void> show({
    required int id,
    required String title,
    required String body,
    NotificationChannel channel = NotificationChannel.classReminder,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: _channelDetails(channel)),
    );
  }

  // ── Scheduled Notification ─────────────────────────────
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    NotificationChannel channel = NotificationChannel.classReminder,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledAt, tz.local);
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(android: _channelDetails(channel)),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('[NotificationService] Scheduled #$id at $scheduledAt');
  }

  // ── Cancel ────────────────────────────────────────────
  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Schedule class reminders ─────────────────────────
  /// Schedule 5 min, 2 min, 1 min before class + class start notification.
  /// [baseId]: unique base ID for this class (e.g. timetable entry ID * 10)
  Future<void> scheduleClassReminders({
    required int baseId,
    required String subjectName,
    required String room,
    required DateTime classStart,
  }) async {
    final reminders = [
      (baseId,     5, '$subjectName starts in 5 minutes', 'Room $room • Get ready!'),
      (baseId + 1, 2, '$subjectName starts in 2 minutes', 'Attendance session will open soon.'),
      (baseId + 2, 1, 'Open attendance now', '$subjectName — Students are arriving. Room $room'),
      (baseId + 3, 0, 'Attendance session started', '$subjectName • Room $room — Mark your attendance now!'),
    ];

    for (final (id, minsBefore, title, body) in reminders) {
      final time = classStart.subtract(Duration(minutes: minsBefore));
      await schedule(id: id, title: title, body: body, scheduledAt: time,
          channel: minsBefore == 0 ? NotificationChannel.attendance : NotificationChannel.classReminder);
    }
  }

  /// Schedule attendance closing in 1 minute notification.
  Future<void> scheduleAttendanceClosing({
    required int id,
    required String subjectName,
    required DateTime closeTime,
  }) async {
    await schedule(
      id: id,
      title: 'Attendance closing soon',
      body: '$subjectName attendance closes in 1 minute.',
      scheduledAt: closeTime.subtract(const Duration(minutes: 1)),
      channel: NotificationChannel.attendance,
    );
  }

  /// Schedule break / lunch start notification.
  Future<void> scheduleBreak({
    required int id,
    required String breakLabel, // e.g. 'Break', 'Lunch'
    required DateTime breakStart,
    bool scheduleEndReminder = true,
    Duration? breakDuration,
  }) async {
    await schedule(
      id: id,
      title: '$breakLabel Starts Now',
      body: 'Take a break! Next class coming up soon.',
      scheduledAt: breakStart,
      channel: NotificationChannel.breakAlert,
    );

    if (scheduleEndReminder && breakDuration != null) {
      final endTime = breakStart.add(breakDuration);
      await schedule(
        id: id + 1,
        title: '$breakLabel Ends in 2 Minutes',
        body: 'Head to class. Next period starts soon.',
        scheduledAt: endTime.subtract(const Duration(minutes: 2)),
        channel: NotificationChannel.breakAlert,
      );
    }
  }

  AndroidNotificationDetails _channelDetails(NotificationChannel ch) {
    switch (ch) {
      case NotificationChannel.attendance:
        return _attendanceChannel;
      case NotificationChannel.breakAlert:
        return _breakChannel;
      default:
        return _classChannel;
    }
  }
}

enum NotificationChannel {
  classReminder,
  attendance,
  breakAlert,
}
