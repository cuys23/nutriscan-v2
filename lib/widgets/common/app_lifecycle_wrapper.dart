import 'package:flutter/material.dart';
import 'package:nutriscan/providers/ads/admob_provider.dart';
import 'package:nutriscan/providers/notifications/notification_provider.dart';
import 'package:provider/provider.dart';

class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  DateTime? _lastPausedTime;
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check inactivity on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInactivityOnStart();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final admobProvider = context.read<AdMobProvider>();

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isAppInForeground) {
          _isAppInForeground = true;
          _handleAppResumed(admobProvider);
          _checkInactivityOnResume();
        }
        break;
      case AppLifecycleState.paused:
        _isAppInForeground = false;
        _lastPausedTime = DateTime.now();
        break;
      case AppLifecycleState.detached:
        _isAppInForeground = false;
        _lastPausedTime = DateTime.now();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handleAppResumed(AdMobProvider admobProvider) {
    // Only show open ad if app was paused for more than 30 seconds
    if (_lastPausedTime != null) {
      final timeSincePaused = DateTime.now().difference(_lastPausedTime!);
      if (timeSincePaused.inSeconds >= 30) {
        // Small delay to ensure app is fully resumed
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && admobProvider.canShowAppOpenAd()) {
            admobProvider.showAppOpenAd();
          }
        });
      }
    }
  }

  void _checkInactivityOnStart() {
    try {
      final notificationProvider = context.read<NotificationProvider>();
      notificationProvider.checkAndNotifyInactivity();
    } catch (e) {
      // Handle error silently
    }
  }

  void _checkInactivityOnResume() {
    try {
      final notificationProvider = context.read<NotificationProvider>();
      notificationProvider.checkAndNotifyInactivity();
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
