import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nutriscan/config/app_config.dart';
import 'package:nutriscan/firebase_options.dart';
import 'package:nutriscan/providers/ads/admob_provider.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/chat/chat_provider.dart';
import 'package:nutriscan/providers/coins/coin_provider.dart';
import 'package:nutriscan/providers/common/connectivity_provider.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/food/meal_plan_provider.dart';
import 'package:nutriscan/providers/notifications/notification_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/auth/login_screen.dart';
import 'package:nutriscan/screens/auth/splash_screen.dart';
import 'package:nutriscan/screens/main/main_navigation.dart';
import 'package:nutriscan/screens/main/no_internet_screen.dart';
import 'package:nutriscan/services/notifications/notification_service.dart';
import 'package:nutriscan/widgets/common/app_lifecycle_wrapper.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize AdMob
    await MobileAds.instance.initialize();

  } catch (e) {
    // Continue app startup even if some services fail
  }

  // Pre-initialize providers in background
  final themeProvider = ThemeProvider();
  final foodProvider = FoodProvider();
  final languageProvider = LanguageProvider();
  final admobProvider = AdMobProvider();
  final subscriptionProvider = SubscriptionProvider();
  final cloudBackupProvider = CloudBackupProvider();
  final coinProvider = CoinProvider();
  final notificationProvider = NotificationProvider();
  final mealPlanProvider = MealPlanProvider();
  final connectivityProvider = ConnectivityProvider();
  final chatProvider = ChatProvider();

  // Initialize providers asynchronously
  foodProvider.initialize();
  cloudBackupProvider.initializeSilently();
  notificationProvider.initializeNotifications();

  // Connect theme provider with language provider
  themeProvider.setLanguageProvider(languageProvider);

  // Connect providers
  foodProvider.setAdMobProvider(admobProvider);
  foodProvider.setNotificationProvider(notificationProvider);
  admobProvider.setSubscriptionProvider(subscriptionProvider);
  subscriptionProvider.setNotificationProvider(notificationProvider);

  // Setup FCM topic subscription on language change
  languageProvider.setLanguageChangeCallback((languageCode) {
    notificationProvider.subscribeToLanguageTopic(languageCode);
  });

  // Subscribe to general topics and current language topic
  notificationProvider.subscribeToGeneralTopics();
  notificationProvider.subscribeToLanguageTopic(
    languageProvider.currentLanguage,
  );

  // Subscribe to critical system topics (always enabled, user cannot disable)
  notificationProvider.subscribeToCriticalTopics();

  runApp(
    MyApp(
      themeProvider: themeProvider,
      foodProvider: foodProvider,
      languageProvider: languageProvider,
      admobProvider: admobProvider,
      subscriptionProvider: subscriptionProvider,
      cloudBackupProvider: cloudBackupProvider,
      coinProvider: coinProvider,
      notificationProvider: notificationProvider,
      mealPlanProvider: mealPlanProvider,
      connectivityProvider: connectivityProvider,
      chatProvider: chatProvider,
    ),
  );
}

class MyApp extends StatefulWidget {
  final ThemeProvider themeProvider;
  final FoodProvider foodProvider;
  final LanguageProvider languageProvider;
  final AdMobProvider admobProvider;
  final SubscriptionProvider subscriptionProvider;
  final CloudBackupProvider cloudBackupProvider;
  final CoinProvider coinProvider;
  final NotificationProvider notificationProvider;
  final MealPlanProvider mealPlanProvider;
  final ConnectivityProvider connectivityProvider;
  final ChatProvider chatProvider;

  const MyApp({
    super.key,
    required this.themeProvider,
    required this.foodProvider,
    required this.languageProvider,
    required this.admobProvider,
    required this.subscriptionProvider,
    required this.cloudBackupProvider,
    required this.coinProvider,
    required this.notificationProvider,
    required this.mealPlanProvider,
    required this.connectivityProvider,
    required this.chatProvider,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationSubscription = NotificationService().notificationTapStream
        .listen((payload) {});
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set provider references
    widget.foodProvider.setAdMobProvider(widget.admobProvider);
    widget.foodProvider.setSubscriptionProvider(widget.subscriptionProvider);
    widget.foodProvider.setCoinProvider(widget.coinProvider);
    widget.foodProvider.setNotificationProvider(widget.notificationProvider);
    widget.subscriptionProvider.setAuth(widget.cloudBackupProvider);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.themeProvider),
        ChangeNotifierProvider.value(value: widget.foodProvider),
        ChangeNotifierProvider.value(value: widget.languageProvider),
        ChangeNotifierProvider.value(value: widget.admobProvider),
        ChangeNotifierProvider.value(value: widget.subscriptionProvider),
        ChangeNotifierProvider.value(value: widget.cloudBackupProvider),
        ChangeNotifierProvider.value(value: widget.coinProvider),
        ChangeNotifierProvider.value(value: widget.notificationProvider),
        ChangeNotifierProvider.value(value: widget.mealPlanProvider),
        ChangeNotifierProvider.value(value: widget.connectivityProvider),
        ChangeNotifierProvider.value(value: widget.chatProvider),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, child) {
          return AppLifecycleWrapper(
            child: MaterialApp(
              navigatorKey: _navigatorKey,
              title: AppConfig.appName,
              debugShowCheckedModeBanner: false,
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode: themeProvider.isDarkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
              routes: {
                '/main': (context) => const MainNavigation(),
                '/login': (context) => const LoginScreen(),
              },
              builder: (context, child) {
                // Determine text direction based on language (RTL for Arabic, Urdu, Hebrew)
                final isRTL =
                    languageProvider.currentLanguage == 'ar' ||
                    languageProvider.currentLanguage == 'ur' ||
                    languageProvider.currentLanguage == 'he';

                // Apply font to all text widgets in the app
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness:
                        themeProvider.isDarkMode
                            ? Brightness.light
                            : Brightness.dark,
                    statusBarBrightness:
                        themeProvider.isDarkMode
                            ? Brightness.dark
                            : Brightness.light,
                  ),
                  child: Directionality(
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: MediaQuery.of(context).textScaler),
                      child: Consumer<ConnectivityProvider>(
                        builder: (context, connectivity, _) {
                          if (!connectivity.isOnline) {
                            return NoInternetScreen(
                              onRetry: () => connectivity.checkConnection(),
                            );
                          }
                          return child!;
                        },
                      ),
                    ),
                  ),
                );
              },
              home: const SplashScreen(),
            ),
          );
        },
      ),
    );
  }
}
