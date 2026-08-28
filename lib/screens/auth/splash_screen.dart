import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/ads/admob_provider.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/auth/login_screen.dart';
import 'package:nutriscan/screens/auth/onboarding_screen.dart';
import 'package:nutriscan/screens/main/main_navigation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late AnimationController _loadingController;
  late Animation<double> _logoScale;
  late Animation<double> _fadeAnimation;
  late Animation<double> _loadingRotation;

  @override
  void initState() {
    super.initState();

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Initialize animation controllers with faster durations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Define animations
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _loadingRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );

    // Start animations
    _logoController.forward();
    _fadeController.forward();
    _loadingController.repeat();

    // Navigate to appropriate screen after 3 second delay
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        final hasLoggedIn = prefs.getBool('has_logged_in') ?? false;

        // Also check Firebase auth state
        if (!mounted) return;
        final cloudBackupProvider = context.read<CloudBackupProvider>();
        final isFirebaseSignedIn = cloudBackupProvider.isSignedIn;

        // Use Firebase auth state as primary source of truth
        final isActuallyLoggedIn = isFirebaseSignedIn && hasLoggedIn;

        if (mounted) {
          // Show open ad before navigating to main app (only if onboarding is completed)
          if (hasSeenOnboarding) {
            if (!mounted) return;
            final admobProvider = context.read<AdMobProvider>();
            if (admobProvider.canShowAppOpenAd()) {
              await admobProvider.showAppOpenAd();
            }
          }

          if (isActuallyLoggedIn) {
            // User is actually logged in - go directly to main screen
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const MainNavigation(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          } else if (!hasSeenOnboarding) {
            // User not logged in and hasn't seen onboarding - go to onboarding
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const OnboardingScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          } else {
            // User has seen onboarding but not logged in - navigate to login screen
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const LoginScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LanguageProvider, ThemeProvider>(
      builder: (context, languageProvider, themeProvider, child) {
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          body: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo and App Name
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Logo
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Container(
                              width: 120.0,
                              height: 120.0,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30.0),
                                child: Image.asset(
                                  'assets/images/logo.jpg',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),

                      // App Name
                      AnimatedBuilder(
                        animation: _fadeController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              AppLocalizations.getString(
                                'calorie_tracker',
                                currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryLight,
                                letterSpacing: 1.2,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Tagline
                      AnimatedBuilder(
                        animation: _fadeController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              AppLocalizations.getString(
                                'track_nutrition_journey',
                                currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 16,
                                color: AppColors.textSecondaryLight,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Loading Indicator with Circle and Text
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Rotating Loading Circle
                      AnimatedBuilder(
                        animation: _loadingController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _loadingRotation.value * 2 * 3.14159,
                            // Convert to radians
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                strokeWidth: 3,
                                backgroundColor: AppColors.grey200,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Loading Text
                      AnimatedBuilder(
                        animation: _fadeController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              AppLocalizations.getString(
                                'loading',
                                currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimaryLight,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      // Loading Subtitle
                      AnimatedBuilder(
                        animation: _fadeController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              AppLocalizations.getString(
                                'preparing_app',
                                currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 14,
                                color: AppColors.textSecondaryLight,
                                letterSpacing: 0.3,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Powered by Groq AI + Version
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.getString(
                                'powered_by_groq_ai',
                                currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocalizations.getString(
                                'splash_version',
                                currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
