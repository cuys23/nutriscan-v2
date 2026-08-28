import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/services/notifications/fcm_service.dart';
import 'package:nutriscan/services/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MealReminder {
  final int id;
  final String name;
  TimeOfDay time;
  bool isEnabled;

  MealReminder({
    required this.id,
    required this.name,
    required this.time,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hour': time.hour,
      'minute': time.minute,
      'isEnabled': isEnabled,
    };
  }

  factory MealReminder.fromJson(Map<String, dynamic> json) {
    return MealReminder(
      id: json['id'],
      name: json['name'],
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
      isEnabled: json['isEnabled'] ?? true,
    );
  }
}

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final FCMService _fcmService = FCMService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  bool _notificationsEnabled = false;
  bool _dailyProgressEnabled = false;
  bool _inactivityReminderEnabled = false;
  bool _weeklySummaryEnabled = false;
  bool _monthlySummaryEnabled = false;
  bool _premiumPromotionEnabled = true;
  List<MealReminder> _mealReminders = [];
  String? _fcmToken;

  static const int maxDailyNotifications = 3;
  int _dailyNotificationCount = 0;
  String? _lastNotificationDate;

  bool _notificationsPaused = false;
  String? _pauseStartDate;
  static const int pauseDurationDays = 7;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get dailyProgressEnabled => _dailyProgressEnabled;
  bool get inactivityReminderEnabled => _inactivityReminderEnabled;
  bool get weeklySummaryEnabled => _weeklySummaryEnabled;
  bool get monthlySummaryEnabled => _monthlySummaryEnabled;
  bool get premiumPromotionEnabled => _premiumPromotionEnabled;
  List<MealReminder> get mealReminders => _mealReminders;
  String? get fcmToken => _fcmToken;
  bool get notificationsPaused => _notificationsPaused;
  int get remainingPauseDays => _getRemainingPauseDays();

  NotificationProvider() {
    _initializeReminders();
    _loadSettings();
  }

  void _initializeReminders() {
    _mealReminders = [
      MealReminder(
        id: 1,
        name: 'breakfast',
        time: const TimeOfDay(hour: 7, minute: 30),
      ),
      MealReminder(
        id: 2,
        name: 'lunch',
        time: const TimeOfDay(hour: 12, minute: 30),
      ),
      MealReminder(
        id: 3,
        name: 'snack',
        time: const TimeOfDay(hour: 16, minute: 0),
      ),
      MealReminder(
        id: 4,
        name: 'dinner',
        time: const TimeOfDay(hour: 20, minute: 0),
      ),
    ];
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _dailyProgressEnabled = prefs.getBool('daily_progress_enabled') ?? false;
      _inactivityReminderEnabled =
          prefs.getBool('inactivity_reminder_enabled') ?? false;
      _weeklySummaryEnabled = prefs.getBool('weekly_summary_enabled') ?? false;
      _monthlySummaryEnabled =
          prefs.getBool('monthly_summary_enabled') ?? false;
      // Premium promotion is enabled by default for free users
      _premiumPromotionEnabled =
          prefs.getBool('premium_promotion_enabled') ?? true;

      // Load custom times if available
      final remindersJson = prefs.getString('meal_reminders');
      if (remindersJson != null && remindersJson.isNotEmpty) {
        try {
          final List<dynamic> decodedList = json.decode(remindersJson);
          final loadedReminders = decodedList
              .map((item) => MealReminder.fromJson(item))
              .toList();

          // Update existing reminders with loaded data
          for (var loadedReminder in loadedReminders) {
            final index = _mealReminders.indexWhere(
              (r) => r.id == loadedReminder.id,
            );
            if (index != -1) {
              _mealReminders[index].time = loadedReminder.time;
              _mealReminders[index].isEnabled = loadedReminder.isEnabled;
            }
          }
        } catch (e) {
          debugPrint('Error parsing reminders: $e');
        }
      }

      // Load daily notification count
      _dailyNotificationCount = prefs.getInt('daily_notification_count') ?? 0;
      _lastNotificationDate = prefs.getString('last_notification_date');

      // Load pause status
      _notificationsPaused = prefs.getBool('notifications_paused') ?? false;
      _pauseStartDate = prefs.getString('pause_start_date');

      // Reset count if it's a new day
      _checkAndResetDailyCount();

      // Check if pause period has expired (must be after other loads)
      await _checkAndResumePause();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('daily_progress_enabled', _dailyProgressEnabled);
      await prefs.setBool(
        'inactivity_reminder_enabled',
        _inactivityReminderEnabled,
      );
      await prefs.setBool('weekly_summary_enabled', _weeklySummaryEnabled);
      await prefs.setBool('monthly_summary_enabled', _monthlySummaryEnabled);
      await prefs.setBool(
        'premium_promotion_enabled',
        _premiumPromotionEnabled,
      );

      // Save meal reminders
      final remindersJsonList = _mealReminders.map((r) => r.toJson()).toList();
      final remindersJsonString = json.encode(remindersJsonList);
      await prefs.setString('meal_reminders', remindersJsonString);

      // Save daily notification count
      await prefs.setInt('daily_notification_count', _dailyNotificationCount);
      if (_lastNotificationDate != null) {
        await prefs.setString('last_notification_date', _lastNotificationDate!);
      }

      // Save pause status
      await prefs.setBool('notifications_paused', _notificationsPaused);
      if (_pauseStartDate != null) {
        await prefs.setString('pause_start_date', _pauseStartDate!);
      }
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;

    if (value) {
      // Request permissions
      try {
        final granted = await _notificationService.requestPermissions();
        if (granted) {
          // Also request exact alarm permission
          await _notificationService.openExactAlarmSettings();

          // Wait a bit for permission dialog
          await Future.delayed(const Duration(milliseconds: 500));

          await _scheduleAllReminders();
        } else {
          _notificationsEnabled = false;
        }
      } catch (e) {
        debugPrint('Error toggling notifications: $e');
        _notificationsEnabled = false;
      }
    } else {
      // Cancel only meal reminder notifications (IDs: 1, 2, 3, 4)
      for (final reminder in _mealReminders) {
        await _notificationService.cancelNotification(reminder.id);
      }
    }

    await _saveSettings();
    notifyListeners();
  }

  Future<void> _scheduleAllReminders() async {
    for (final reminder in _mealReminders) {
      if (reminder.isEnabled) {
        try {
          await scheduleReminder(reminder);
        } catch (e) {
          debugPrint('Error scheduling reminder ${reminder.id}: $e');
        }
      }
    }
  }

  Future<void> scheduleReminder(MealReminder reminder) async {
    try {
      // Check if notifications are paused
      if (_notificationsPaused) {
        return;
      }

      // Generate proper notification message (async)
      String mealName = reminder.name;
      String message = await _getMealReminderMessage(mealName);

      await _notificationService.scheduleMealReminder(
        id: reminder.id,
        title: 'NutriScan 🍽️',
        body: message,
        hour: reminder.time.hour,
        minute: reminder.time.minute,
      );
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  Future<String> _getMealReminderMessage(String mealName) async {
    // Get current language from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final currentLanguage = prefs.getString('selected_language') ?? 'en';

    // Generate localized key
    String key = '${mealName}_notification';

    // Get localized message
    String message = AppLocalizations.getString(key, currentLanguage);

    // Fallback to default message if key not found
    if (message == key) {
      final defaultMessages = {
        'breakfast': 'Time for breakfast! 🍽️ Don\'t forget to register.',
        'lunch': 'Time for lunch! 🍽️ Don\'t forget to register.',
        'snack': 'Time for snack! 🍽️ Don\'t forget to register.',
        'dinner': 'Time for dinner! 🍽️ Don\'t forget to register.',
      };
      message =
          defaultMessages[mealName] ??
          'Meal time! 🍽️ Don\'t forget to register.';
    }

    return message;
  }

  Future<void> toggleReminder(int id, bool value) async {
    final index = _mealReminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      _mealReminders[index].isEnabled = value;

      if (_notificationsEnabled) {
        try {
          if (value) {
            await scheduleReminder(_mealReminders[index]);
          } else {
            await _notificationService.cancelNotification(id);
          }
        } catch (e) {
          debugPrint('Error toggling reminder: $e');
        }
      }

      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> updateReminderTime(int id, TimeOfDay newTime) async {
    final index = _mealReminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      _mealReminders[index].time = newTime;

      if (_notificationsEnabled && _mealReminders[index].isEnabled) {
        try {
          // Cancel old notification first
          await _notificationService.cancelNotification(id);
          // Schedule with new time
          await scheduleReminder(_mealReminders[index]);
        } catch (e) {
          debugPrint('Error updating reminder time: $e');
        }
      }

      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> initializeNotifications() async {
    try {
      await _notificationService.initialize();

      // Initialize FCM for push notifications
      await _fcmService.initialize();
      _fcmToken = _fcmService.fcmToken;

      // Set callback for notification received
      _fcmService.setNotificationCallback(() {
        _checkAndResetDailyCount();
        notifyListeners();
      });

      // Set callback for FCM notification shown (for counting)
      _fcmService.setFCMNotificationShownCallback(() async {
        await incrementFCMNotificationCount();
      });

      // Set callback for pause status check
      _fcmService.setPauseCheckCallback(() async {
        return isNotificationPaused();
      });

      // Listen to FCM messages
      _fcmService.messageStream.listen((message) {
        // Handle incoming FCM messages
      });

      if (_notificationsEnabled) {
        await _scheduleAllReminders();
      }
      if (_dailyProgressEnabled) {
        await scheduleDailyProgressNotification();
      }
      if (_inactivityReminderEnabled) {
        await scheduleInactivityReminder();
      }
      if (_weeklySummaryEnabled) {
        await scheduleWeeklySummary();
      }
      if (_monthlySummaryEnabled) {
        // Cancel old notification first to ensure fresh scheduling
        await _notificationService.cancelNotification(996);
        await scheduleMonthlySummary();
      }
      // Premium promotion: only schedule if enabled and user is not premium
      if (_premiumPromotionEnabled) {
        await schedulePremiumPromotion();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> toggleDailyProgress(bool value) async {
    _dailyProgressEnabled = value;

    if (value) {
      // Request permissions if not already granted
      try {
        final granted = await _notificationService.requestPermissions();
        if (granted) {
          await scheduleDailyProgressNotification();
        } else {
          _dailyProgressEnabled = false;
        }
      } catch (e) {
        debugPrint('Error toggling daily progress: $e');
        _dailyProgressEnabled = false;
      }
    } else {
      // Cancel daily progress notification (ID: 999)
      await _notificationService.cancelNotification(999);
    }

    await _saveSettings();
    notifyListeners();
  }

  Future<void> scheduleDailyProgressNotification({double? calories}) async {
    try {
      // Check if notifications are paused
      if (_notificationsPaused) {
        return;
      }

      // Get current language from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentLanguage = prefs.getString('selected_language') ?? 'en';

      // Get localized strings
      String title = AppLocalizations.getString(
        'daily_progress',
        currentLanguage,
      );
      String messageTemplate = AppLocalizations.getString(
        'daily_progress_message',
        currentLanguage,
      );

      // Format calories or use placeholder
      String calorieText = calories != null ? calories.toStringAsFixed(0) : '0';
      String message = messageTemplate.replaceAll('{calories}', calorieText);

      await _notificationService.scheduleDailyProgressNotification(
        title: title,
        body: message,
      );
    } catch (e) {
      debugPrint('Error scheduling daily progress notification: $e');
    }
  }

  Future<void> updateDailyProgressNotification(double calories) async {
    if (_dailyProgressEnabled) {
      await scheduleDailyProgressNotification(calories: calories);
    }
  }

  Future<void> showNutrientDeficiencyNotification({
    required String nutrientKey,
    required String language,
  }) async {
    if (_notificationsPaused) return;
    try {
      final title = AppLocalizations.getString(
        'nutrient_deficiency_title',
        language,
      );
      final bodyKey = 'nutrient_deficiency_$nutrientKey';
      final body = AppLocalizations.getString(bodyKey, language);
      if (body == bodyKey) return;
      await _notificationService.showNutrientDeficiencyNotification(
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Error showing nutrient deficiency notification: $e');
    }
  }

  Future<void> toggleInactivityReminder(bool value) async {
    _inactivityReminderEnabled = value;

    if (value) {
      // Request permissions if not already granted
      try {
        final granted = await _notificationService.requestPermissions();
        if (granted) {
          await scheduleInactivityReminder();
        } else {
          _inactivityReminderEnabled = false;
        }
      } catch (e) {
        debugPrint('Error toggling inactivity reminder: $e');
        _inactivityReminderEnabled = false;
      }
    } else {
      // Cancel inactivity reminder (ID: 998)
      await _notificationService.cancelNotification(998);
    }

    await _saveSettings();
    notifyListeners();
  }

  Future<void> scheduleInactivityReminder() async {
    try {
      // Store initial app first used time
      final prefs = await SharedPreferences.getInstance();
      final appFirstUsed = prefs.getString('app_first_used');
      if (appFirstUsed == null) {
        await prefs.setString(
          'app_first_used',
          DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('Error scheduling inactivity reminder: $e');
    }
  }

  Future<void> checkAndNotifyInactivity() async {
    if (!_inactivityReminderEnabled) return;

    // Check if notifications are paused
    if (_notificationsPaused) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScanTime = prefs.getString('last_food_scan_time');
      final lastNotificationDate = prefs.getString(
        'last_inactivity_notification_date',
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check if already sent notification today
      if (lastNotificationDate != null) {
        final lastNotifDate = DateTime.parse(lastNotificationDate);
        final lastNotifDay = DateTime(
          lastNotifDate.year,
          lastNotifDate.month,
          lastNotifDate.day,
        );

        if (lastNotifDay.isAtSameMomentAs(today)) {
          // Already sent notification today, skip
          return;
        }
      }

      // Check if user is inactive for 24+ hours
      if (lastScanTime != null) {
        final lastScan = DateTime.parse(lastScanTime);
        final hoursSinceLastScan = now.difference(lastScan).inHours;

        // Only send if inactive for 24+ hours and time is around 10:00
        if (hoursSinceLastScan >= 24 && now.hour >= 10 && now.hour < 11) {
          // Get localized message
          final currentLanguage = prefs.getString('selected_language') ?? 'en';
          String title = AppLocalizations.getString(
            'inactivity_reminder',
            currentLanguage,
          );
          String message = AppLocalizations.getString(
            'inactivity_reminder_message',
            currentLanguage,
          );

          // Send immediate notification
          await _notificationService.sendImmediateInactivityNotification(
            title: title,
            body: message,
          );

          // Mark that we sent notification today
          await prefs.setString(
            'last_inactivity_notification_date',
            now.toIso8601String(),
          );
        }
      } else {
        // No last scan recorded, consider as inactive if app was used before
        final appFirstUsed = prefs.getString('app_first_used');
        if (appFirstUsed != null) {
          final firstUsed = DateTime.parse(appFirstUsed);
          final hoursSinceFirstUse = now.difference(firstUsed).inHours;

          if (hoursSinceFirstUse >= 24 && now.hour >= 10 && now.hour < 11) {
            final currentLanguage =
                prefs.getString('selected_language') ?? 'en';
            String title = AppLocalizations.getString(
              'inactivity_reminder',
              currentLanguage,
            );
            String message = AppLocalizations.getString(
              'inactivity_reminder_message',
              currentLanguage,
            );

            await _notificationService.sendImmediateInactivityNotification(
              title: title,
              body: message,
            );

            await prefs.setString(
              'last_inactivity_notification_date',
              now.toIso8601String(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking inactivity: $e');
    }
  }

  Future<void> updateLastFoodScanTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_food_scan_time',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error updating last food scan time: $e');
    }
  }

  Future<void> toggleWeeklySummary(bool value) async {
    _weeklySummaryEnabled = value;

    if (value) {
      // Request permissions if not already granted
      try {
        final granted = await _notificationService.requestPermissions();
        if (granted) {
          await scheduleWeeklySummary();
        } else {
          _weeklySummaryEnabled = false;
        }
      } catch (e) {
        debugPrint('Error toggling weekly summary: $e');
        _weeklySummaryEnabled = false;
      }
    } else {
      // Cancel weekly summary (ID: 997)
      await _notificationService.cancelNotification(997);
    }

    await _saveSettings();
    notifyListeners();
  }

  Future<void> scheduleWeeklySummary({
    int? foodCount,
    double? avgCalories,
  }) async {
    try {
      // Check if notifications are paused
      if (_notificationsPaused) {
        return;
      }

      // Get current language from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentLanguage = prefs.getString('selected_language') ?? 'en';

      // Get localized strings
      String title = AppLocalizations.getString(
        'weekly_summary',
        currentLanguage,
      );
      String messageTemplate = AppLocalizations.getString(
        'weekly_summary_message',
        currentLanguage,
      );

      // Format food count and calories
      String foodText = foodCount != null ? foodCount.toString() : '0';
      String caloriesText = avgCalories != null
          ? avgCalories.toStringAsFixed(0)
          : '0';

      String message = messageTemplate
          .replaceAll('{foods}', foodText)
          .replaceAll('{calories}', caloriesText);

      await _notificationService.scheduleWeeklySummary(
        title: title,
        body: message,
      );
    } catch (e) {
      debugPrint('Error scheduling weekly summary: $e');
    }
  }

  Future<void> updateWeeklySummaryNotification(
    int foodCount,
    double avgCalories,
  ) async {
    if (_weeklySummaryEnabled) {
      await scheduleWeeklySummary(
        foodCount: foodCount,
        avgCalories: avgCalories,
      );
    }
  }

  Future<void> toggleMonthlySummary(bool value) async {
    _monthlySummaryEnabled = value;

    // Always cancel old notification first
    await _notificationService.cancelNotification(996);

    if (value) {
      // Request permissions if not already granted
      try {
        final granted = await _notificationService.requestPermissions();
        if (granted) {
          await scheduleMonthlySummary();
        } else {
          _monthlySummaryEnabled = false;
        }
      } catch (e) {
        debugPrint('Error toggling monthly summary: $e');
        _monthlySummaryEnabled = false;
      }
    }

    await _saveSettings();
    notifyListeners();
  }

  Future<void> scheduleMonthlySummary({
    int? foodCount,
    String? monthName,
    int? month,
    int? year,
  }) async {
    try {
      // Check if notifications are paused
      if (_notificationsPaused) {
        return;
      }

      // Get current language from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentLanguage = prefs.getString('selected_language') ?? 'en';

      // Get localized strings
      String title = AppLocalizations.getString(
        'monthly_summary',
        currentLanguage,
      );
      String messageTemplate = AppLocalizations.getString(
        'monthly_summary_message',
        currentLanguage,
      );

      // Format food count and month name
      String foodText = foodCount != null ? foodCount.toString() : '0';
      String monthText =
          monthName ??
          AppLocalizations.getString('last_month', currentLanguage);

      String message = messageTemplate
          .replaceAll('{foods}', foodText)
          .replaceAll('{month}', monthText);

      await _notificationService.scheduleMonthlySummary(
        title: title,
        body: message,
        month: month,
        year: year,
      );
    } catch (e) {
      debugPrint('Error scheduling monthly summary: $e');
    }
  }

  Future<void> updateMonthlySummaryNotification(
    int foodCount,
    String monthName,
  ) async {
    if (_monthlySummaryEnabled) {
      await scheduleMonthlySummary(foodCount: foodCount, monthName: monthName);
    }
  }

  Future<void> togglePremiumPromotion(bool value) async {
    _premiumPromotionEnabled = value;

    if (value) {
      // Request permissions if not already granted
      try {
        final granted = await _notificationService.requestPermissions();
        if (granted) {
          await schedulePremiumPromotion();
        } else {
          _premiumPromotionEnabled = false;
        }
      } catch (e) {
        debugPrint('Error toggling premium promotion: $e');
        _premiumPromotionEnabled = false;
      }
    } else {
      // Cancel premium promotion (ID: 995)
      await _notificationService.cancelNotification(995);
    }

    await _saveSettings();
    notifyListeners();
  }

  Future<void> schedulePremiumPromotion() async {
    try {
      // Check if notifications are paused
      if (_notificationsPaused) {
        return;
      }

      // Securely check subscription status
      final isSubscribedStr = await _secureStorage.read(key: 'is_subscribed');
      final isSubscribed = isSubscribedStr == 'true';

      // Check if subscription is active
      bool hasPremium = false;
      if (isSubscribed) {
        final expiryString = await _secureStorage.read(key: 'subscription_expiry');
        if (expiryString != null) {
          final expiry = DateTime.parse(expiryString);
          hasPremium = DateTime.now().isBefore(expiry);
        }
      }

      // Only schedule if user is NOT premium
      if (!hasPremium) {
        final prefs = await SharedPreferences.getInstance();
        final currentLanguage = prefs.getString('selected_language') ?? 'en';

        // Get localized strings
        String title = AppLocalizations.getString(
          'premium_promotion',
          currentLanguage,
        );
        String message = AppLocalizations.getString(
          'premium_promotion_message',
          currentLanguage,
        );

        await _notificationService.schedulePremiumPromotion(
          title: title,
          body: message,
        );
      } else {
        // User is premium, cancel any scheduled promotion
        await _notificationService.cancelNotification(995);
      }
    } catch (e) {
      debugPrint('Error scheduling premium promotion: $e');
    }
  }

  // Method to cancel premium promotion when user becomes premium
  Future<void> cancelPremiumPromotionForPremiumUser() async {
    try {
      await _notificationService.cancelNotification(995);
      _premiumPromotionEnabled = false;
      await _saveSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error cancelling premium promotion: $e');
    }
  }

  // FCM Topic Management
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcmService.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcmService.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  // Subscribe to language-specific topic for localized push notifications
  Future<void> subscribeToLanguageTopic(String languageCode) async {
    try {
      // Unsubscribe from all language topics first
      final languages = [
        'en', 'bn', 'hi', 'es', 'fr', 'de', 'zh', 'tr', 'ko', 'id', 'ja', 'ru', 'ur', 'pt', 'pt-BR', 'ar',
      ];
      for (final lang in languages) {
        await _fcmService.unsubscribeFromTopic('lang_$lang');
      }

      // Subscribe to current language topic
      await _fcmService.subscribeToTopic('lang_$languageCode');
    } catch (e) {
      debugPrint('Error subscribing to language topic: $e');
    }
  }

  // Subscribe to general topics
  Future<void> subscribeToGeneralTopics() async {
    try {
      await _fcmService.subscribeToTopic('all_users');
      await _fcmService.subscribeToTopic('nutriscan_updates');
    } catch (e) {
      debugPrint('Error subscribing to general topics: $e');
    }
  }

  // Subscribe to critical system topics (cannot be disabled by user)
  Future<void> subscribeToCriticalTopics() async {
    try {
      await _fcmService.subscribeToTopic('system_maintenance');
      await _fcmService.subscribeToTopic('critical_updates');
      await _fcmService.subscribeToTopic('security_alerts');
    } catch (e) {
      debugPrint('Error subscribing to critical topics: $e');
    }
  }

  // Refresh FCM token
  Future<void> refreshFCMToken() async {
    try {
      _fcmToken = _fcmService.fcmToken;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing FCM token: $e');
    }
  }

  // Check and reset daily notification count
  void _checkAndResetDailyCount() {
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    if (_lastNotificationDate != todayString) {
      _dailyNotificationCount = 0;
      _lastNotificationDate = todayString;
    }
  }

  // Get remaining notifications for today (FCM Push only)
  int getRemainingNotifications() {
    _checkAndResetDailyCount();
    return maxDailyNotifications - _dailyNotificationCount;
  }

  // Increment FCM notification count (called from FCM Service)
  Future<void> incrementFCMNotificationCount() async {
    _checkAndResetDailyCount();
    _dailyNotificationCount++;
    await _saveSettings();
    notifyListeners();
  }

  // Check and auto-resume if pause period expired
  Future<void> _checkAndResumePause() async {
    if (!_notificationsPaused || _pauseStartDate == null) {
      return;
    }

    try {
      final pauseStart = DateTime.parse(_pauseStartDate!);
      final now = DateTime.now();
      final daysPassed = now.difference(pauseStart).inDays;

      if (daysPassed >= pauseDurationDays) {
        // Auto-resume and re-schedule all notifications
        await resumeNotifications();
      }
    } catch (e) {
      debugPrint('Error checking pause resume: $e');
      // Error parsing date, reset pause and resume
      _notificationsPaused = false;
      _pauseStartDate = null;
      await _saveSettings();
    }
  }

  int _getRemainingPauseDays() {
    if (!_notificationsPaused || _pauseStartDate == null) {
      return 0;
    }

    try {
      final pauseStart = DateTime.parse(_pauseStartDate!);
      final now = DateTime.now();
      final daysPassed = now.difference(pauseStart).inDays;
      final remaining = pauseDurationDays - daysPassed;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      debugPrint('Error getting remaining pause days: $e');
      return 0;
    }
  }

  // Pause all notifications for 7 days (Premium feature)
  Future<void> pauseNotificationsFor7Days() async {
    try {
      _notificationsPaused = true;
      _pauseStartDate = DateTime.now().toIso8601String();

      // Cancel all scheduled notifications except critical
      for (final reminder in _mealReminders) {
        await _notificationService.cancelNotification(reminder.id);
      }
      await _notificationService.cancelNotification(999); // Daily Progress
      await _notificationService.cancelNotification(998); // Inactivity
      await _notificationService.cancelNotification(997); // Weekly
      await _notificationService.cancelNotification(996); // Monthly
      await _notificationService.cancelNotification(995); // Premium Promo

      await _saveSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing notifications: $e');
    }
  }

  // Resume notifications
  Future<void> resumeNotifications() async {
    try {
      _notificationsPaused = false;
      _pauseStartDate = null;

      // Re-schedule all enabled notifications
      if (_notificationsEnabled) {
        await _scheduleAllReminders();
      }
      if (_dailyProgressEnabled) {
        await scheduleDailyProgressNotification();
      }
      if (_inactivityReminderEnabled) {
        await scheduleInactivityReminder();
      }
      if (_weeklySummaryEnabled) {
        await scheduleWeeklySummary();
      }
      if (_monthlySummaryEnabled) {
        await scheduleMonthlySummary();
      }
      if (_premiumPromotionEnabled) {
        await schedulePremiumPromotion();
      }

      await _saveSettings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming notifications: $e');
    }
  }

  // Check if notifications are paused (for UI and FCM)
  bool isNotificationPaused() {
    return _notificationsPaused;
  }
}
