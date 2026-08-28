import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageController.stream;

  bool _initialized = false;

  Function()? _onNotificationReceived;
  Function()? _onFCMNotificationShown;
  Function()? _checkPauseStatus;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize local notifications for FCM
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

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Request permissions
      await requestPermissions();

      // Get FCM token
      await _getFCMToken();

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Listen for notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // Check if app was opened from a terminated state via notification
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }

      _initialized = true;
    } catch (e) {
      // Handle initialization error silently
    }
  }

  Future<void> requestPermissions() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _getFCMToken() async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);

        // Send token to backend server if needed
        await _sendTokenToServer(_fcmToken!);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      // Save FCM token to Firestore under the user's document
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  void _onTokenRefresh(String token) async {
    _fcmToken = token;

    // Save new token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);

    // Send to server
    await _sendTokenToServer(token);
  }

  void _onForegroundMessage(RemoteMessage message) async {
    // Check if this is a critical notification
    final isCritical = _isCriticalNotification(message);

    // Show local notification when app is in foreground
    await _showLocalNotification(message, isCritical: isCritical);

    // Emit message to stream
    _messageController.add(message);
  }

  bool _isCriticalNotification(RemoteMessage message) {
    final data = message.data;
    if (data.containsKey('critical') && data['critical'] == 'true') {
      return true;
    }

    if (data.containsKey('topic')) {
      final topic = data['topic'].toString();
      if (topic == 'system_maintenance' ||
          topic == 'critical_updates' ||
          topic == 'security_alerts') {
        return true;
      }
    }

    return false;
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _handleMessage(message);
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap based on payload
    if (response.payload != null && response.payload!.isNotEmpty) {
      _handleNotificationPayload(response.payload!);
    }
  }

  void _handleMessage(RemoteMessage message) {
    // Emit to stream for UI to handle
    _messageController.add(message);

    // Handle based on message data
    final data = message.data;
    if (data.isNotEmpty) {
      _handleNotificationData(data);
    }
  }

  void _handleNotificationPayload(String payload) {
    debugPrint('FCM Notification tapped with payload: $payload');
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    // Implement actions based on notification data
  }

  Future<void> _showLocalNotification(
    RemoteMessage message, {
    bool isCritical = false,
  }) async {
    try {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {
        // Check pause status for non-critical notifications
        if (!isCritical) {
          final isPaused = await _checkPauseStatus?.call() ?? false;
          if (isPaused) {
            return;
          }

          final canShow = await _checkDailyLimit();
          if (!canShow) {
            return;
          }
        }

        await _localNotifications.show(
          message.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              isCritical ? 'critical_channel' : 'fcm_channel',
              isCritical ? 'Critical Notifications' : 'FCM Notifications',
              channelDescription: isCritical
                  ? 'Critical system notifications'
                  : 'Firebase Cloud Messaging notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
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
          payload: message.data.toString(),
        );

        // Notify callback for UI update
        _onNotificationReceived?.call();

        // Increment FCM notification counter for non-critical
        if (!isCritical) {
          _onFCMNotificationShown?.call();
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<bool> _checkDailyLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('daily_notification_count') ?? 0;
      final lastDate = prefs.getString('last_notification_date');

      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

      if (lastDate != todayString) {
        return true;
      }

      return count < 3;
    } catch (e) {
      return true;
    }
  }

  void setNotificationCallback(Function() callback) {
    _onNotificationReceived = callback;
  }

  void setFCMNotificationShownCallback(Function() callback) {
    _onFCMNotificationShown = callback;
  }

  void setPauseCheckCallback(Future<bool> Function() callback) {
    _checkPauseStatus = callback;
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
    } catch (e) {
      // Handle error silently
    }
  }

  void dispose() {
    _messageController.close();
  }
}
