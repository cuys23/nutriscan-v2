import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Stream controller for notification taps
  final StreamController<String> _notificationTapController =
      StreamController<String>.broadcast();

  Stream<String> get notificationTapStream => _notificationTapController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz.initializeTimeZones();

    // Get local timezone using native method
    await _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap
    if (response.payload != null && response.payload!.isNotEmpty) {
      _notificationTapController.add(response.payload!);
    }
  }

  void dispose() {
    _notificationTapController.close();
  }

  Future<void> _configureLocalTimezone() async {
    try {
      // Try to detect timezone from offset using comprehensive mapping
      await _findTimezoneByOffset();
    } catch (e) {
      // Last resort: UTC
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> _findTimezoneByOffset() async {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final totalMinutes = offset.inMinutes;

      // Comprehensive timezone mappings for all major regions
      final timezoneMap = <int, String>{
        // UTC and Western Europe
        0: 'UTC',
        60: 'Europe/London', // GMT+1 (BST)
        120: 'Europe/Paris', // GMT+2 (CEST)
        180: 'Europe/Moscow', // GMT+3
        240: 'Asia/Dubai', // GMT+4
        270: 'Asia/Kabul', // GMT+4:30
        300: 'Asia/Karachi', // GMT+5
        330: 'Asia/Kolkata', // GMT+5:30 (India)
        345: 'Asia/Kathmandu', // GMT+5:45 (Nepal)
        360: 'Asia/Dhaka', // GMT+6 (Bangladesh)
        390: 'Asia/Yangon', // GMT+6:30 (Myanmar)
        420: 'Asia/Bangkok', // GMT+7
        480: 'Asia/Shanghai', // GMT+8 (China, Singapore)
        540: 'Asia/Tokyo', // GMT+9 (Japan, Korea)
        570: 'Australia/Adelaide', // GMT+9:30
        600: 'Australia/Sydney', // GMT+10
        660: 'Pacific/Guadalcanal', // GMT+11
        720: 'Pacific/Auckland', // GMT+12
        780: 'Pacific/Tongatapu', // GMT+13
        // Americas (negative offsets)
        -300: 'America/New_York', // GMT-5 (EST)
        -360: 'America/Chicago', // GMT-6 (CST)
        -420: 'America/Denver', // GMT-7 (MST)
        -480: 'America/Los_Angeles', // GMT-8 (PST)
        -540: 'America/Anchorage', // GMT-9 (AKST)
        -600: 'Pacific/Honolulu', // GMT-10 (HST)
        -240: 'America/Halifax', // GMT-4 (AST)
        -180: 'America/Sao_Paulo', // GMT-3 (BRT)
        -120: 'Atlantic/South_Georgia', // GMT-2
        -60: 'Atlantic/Azores', // GMT-1
      };

      // Try to get timezone from map first
      String? locationName = timezoneMap[totalMinutes];

      // If not in predefined map, search through all timezone locations
      if (locationName == null) {
        final locations = tz.timeZoneDatabase.locations;
        for (final location in locations.values) {
          final tzNow = tz.TZDateTime.now(location);
          if (tzNow.timeZoneOffset.inMinutes == totalMinutes) {
            locationName = location.name;
            break;
          }
        }
      }

      // Final fallback to UTC
      locationName ??= 'UTC';

      // Set the local timezone location
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (e) {
      // Last resort: UTC
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Request notification permission
      final notificationStatus = await Permission.notification.request();

      if (notificationStatus.isGranted) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        // Request notification permissions from the plugin
        final pluginPermission =
            await androidPlugin?.requestNotificationsPermission() ?? false;

        return pluginPermission;
      }
      return false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  // Open system settings to allow exact alarms
  Future<void> openExactAlarmSettings() async {
    try {
      await Permission.scheduleExactAlarm.request();
    } catch (e) {
      // Silently handle permission request errors
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final status = await Permission.scheduleExactAlarm.status;
      return status.isGranted;
    } catch (e) {
      // If permission check fails, assume we can schedule (older Android)
      return true;
    }
  }

  Future<void> scheduleMealReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final scheduledTime = _nextInstanceOfTime(hour, minute);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_reminders',
            'Meal Reminders',
            channelDescription: 'Notifications for meal reminders',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      rethrow;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> scheduleDailyProgressNotification({
    required String title,
    required String body,
  }) async {
    try {
      final scheduledTime = _nextInstanceOfTime(21, 0); // 21:00 (9 PM)

      await _notifications.zonedSchedule(
        999, // Unique ID for daily progress notification
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_progress',
            'Daily Progress',
            channelDescription: 'Daily calorie progress notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> scheduleInactivityReminder({
    required String title,
    required String body,
  }) async {
    try {
      final scheduledTime = _nextInstanceOfTime(10, 0); // 10:00 (10 AM)

      await _notifications.zonedSchedule(
        998, // Unique ID for inactivity reminder
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'inactivity_reminder',
            'Inactivity Reminder',
            channelDescription: 'Reminders when inactive for 24 hours',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendImmediateInactivityNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _notifications.show(
        998,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'inactivity_reminder',
            'Inactivity Reminder',
            channelDescription: 'Reminders when inactive for 24 hours',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  static const int nutrientDeficiencyNotificationId = 994;

  Future<void> showNutrientDeficiencyNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _notifications.show(
        nutrientDeficiencyNotificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'nutrient_tips',
            'Nutrition Tips',
            channelDescription: 'Tips when your diet is low in a nutrient',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> scheduleWeeklySummary({
    required String title,
    required String body,
  }) async {
    try {
      // Schedule for Sunday at 18:00
      final scheduledTime = _nextSunday18();

      await _notifications.zonedSchedule(
        997, // Unique ID for weekly summary
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'weekly_summary',
            'Weekly Summary',
            channelDescription: 'Weekly nutrition summary notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      rethrow;
    }
  }

  tz.TZDateTime _nextSunday18() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      18, // 18:00
      0,
    );

    // Find next Sunday
    while (scheduledDate.weekday != DateTime.sunday ||
        scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> scheduleMonthlySummary({
    required String title,
    required String body,
    int? month,
    int? year,
  }) async {
    try {
      // Schedule for 1st of month at 18:00
      final scheduledTime = _nextFirstOfMonth18();

      await _notifications.zonedSchedule(
        996, // Unique ID for monthly summary
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'monthly_summary',
            'Monthly Summary',
            channelDescription: 'Monthly nutrition summary notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    } catch (e) {
      rethrow;
    }
  }

  tz.TZDateTime _nextFirstOfMonth18() {
    final now = tz.TZDateTime.now(tz.local);

    // Start with 1st of current month at 18:00
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      1, // 1st of month
      18, // 18:00
      0,
    );

    // If this time has passed, move to next month
    if (scheduledDate.isBefore(now)) {
      // Add 1 month
      if (now.month == 12) {
        scheduledDate = tz.TZDateTime(tz.local, now.year + 1, 1, 1, 18, 0);
      } else {
        scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month + 1,
          1,
          18,
          0,
        );
      }
    }

    return scheduledDate;
  }

  Future<void> schedulePremiumPromotion({
    required String title,
    required String body,
  }) async {
    try {
      // Schedule for Tuesday at 11:00
      final scheduledTime = _nextTuesday11();

      await _notifications.zonedSchedule(
        995, // Unique ID for premium promotion
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'premium_promotion',
            'Premium Promotion',
            channelDescription: 'Weekly premium feature promotions',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      rethrow;
    }
  }

  tz.TZDateTime _nextTuesday11() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      11, // 11:00
      0,
    );

    // Find next Tuesday
    while (scheduledDate.weekday != DateTime.tuesday ||
        scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
