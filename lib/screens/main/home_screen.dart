import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/ads/admob_provider.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/coins/coin_provider.dart';
import 'package:nutriscan/providers/food/food_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/chat/health_coach_screen.dart';
import 'package:nutriscan/services/ai/groq_service.dart';
import 'package:nutriscan/services/media/image_picker_service.dart';
import 'package:nutriscan/utils/page_transition.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:nutriscan/widgets/dialogs/coin_ad_dialogs.dart';
import 'package:nutriscan/widgets/food/food_list.dart';
import 'package:nutriscan/widgets/food/nutrition_summary_card.dart';
import 'package:nutriscan/widgets/home/image_source_button.dart';
import 'package:provider/provider.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ImagePickerService _imagePickerService = ImagePickerService();
  bool _isInitialLoading = true;
  late AnimationController _loadingController;
  late Animation<double> _loadingRotation;

  TextStyle _getStyledText(
    ThemeProvider themeProvider, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return themeProvider.getFontForCurrentLanguage(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  @override
  void initState() {
    super.initState();

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _loadingRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );

    _loadingController.repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupErrorListener();
    });
  }

  @override
  void dispose() {
    _loadingController.dispose();

    try {
      final foodProvider = context.read<FoodProvider>();
      foodProvider.removeListener(_setupErrorListener);
    } catch (e) {
      // Ignore if context is not available
    }

    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      final foodProvider = context.read<FoodProvider>();
      await Future.delayed(const Duration(seconds: 1));
      await foodProvider.loadFoods();
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  void _setupErrorListener() {
    final foodProvider = context.read<FoodProvider>();

    foodProvider.addListener(() {
      if (mounted && foodProvider.error == 'NOT_FOOD_IMAGE') {
        foodProvider.clearError();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final languageProvider = context.read<LanguageProvider>();
            final currentLanguage = languageProvider.currentLanguage;
            GroqService.showNonFoodImageDialog(
              context,
              language: currentLanguage,
            );
          }
        });
      }
    });
  }

  Future<void> _showImageSourceDialog() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      enableDrag: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.grey600 : AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                AppLocalizations.getString('choose_method', currentLanguage),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.getString(
                  'select_scan_method',
                  currentLanguage,
                ),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 15,
                  color: isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceButton(
                    icon: IconlyBold.camera,
                    label: AppLocalizations.getString(
                      'camera',
                      currentLanguage,
                    ),
                    subtitle: AppLocalizations.getString(
                      'take_photo',
                      currentLanguage,
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _takePhotoFromCamera();
                    },
                  ),
                  _buildImageSourceButton(
                    icon: IconlyBold.image,
                    label: AppLocalizations.getString(
                      'gallery',
                      currentLanguage,
                    ),
                    subtitle: AppLocalizations.getString(
                      'choose_existing',
                      currentLanguage,
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickImageFromGallery();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ImageSourceButton(
      icon: icon,
      label: label,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  Future<void> _takePhotoFromCamera() async {
    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      final admobProvider = context.read<AdMobProvider>();
      final coinProvider = context.read<CoinProvider>();

      // Check if user has coins or is subscribed
      if (!subscriptionProvider.hasPremiumFeatures) {
        if (!coinProvider.canScan()) {
          _showNoCoinDialog();
          return;
        }
      }

      File? imageFile = await _imagePickerService.takePhotoFromCamera();
      if (imageFile != null && mounted) {
        final currentLanguage = context
            .read<LanguageProvider>()
            .currentLanguage;

        if (mounted) {
          await context.read<FoodProvider>().analyzeFoodImage(
            imageFile,
            language: currentLanguage,
            isPremiumUser: subscriptionProvider.hasPremiumFeatures,
          );

          // Track scan and show interstitial after 2 scans
          admobProvider.trackScan();
          await admobProvider.showInterstitialAfterScans();
        }
      }
    } catch (e) {
      if (mounted) {
        // Camera error - no snackbar shown
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      final admobProvider = context.read<AdMobProvider>();
      final coinProvider = context.read<CoinProvider>();

      // Check if user has coins or is subscribed
      if (!subscriptionProvider.hasPremiumFeatures) {
        if (!coinProvider.canScan()) {
          _showNoCoinDialog();
          return;
        }
      }

      File? imageFile = await _imagePickerService.pickImageFromGallery();
      if (imageFile != null && mounted) {
        final currentLanguage = context
            .read<LanguageProvider>()
            .currentLanguage;

        if (mounted) {
          await context.read<FoodProvider>().analyzeFoodImage(
            imageFile,
            language: currentLanguage,
            isPremiumUser: subscriptionProvider.hasPremiumFeatures,
          );

          // Track scan and show interstitial after 2 scans
          admobProvider.trackScan();
          await admobProvider.showInterstitialAfterScans();
        }
      }
    } catch (e) {
      if (mounted) {
        // Gallery error - no snackbar shown
      }
    }
  }


  void _showNoCoinDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.monetization_on,
                    size: 48,
                    color: Colors.orange[600],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.getString(
                    'not_enough_coins',
                    currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.getString(
                    'not_enough_coins_description',
                    currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 15,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.grey800
                              : AppColors.grey100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'cancel',
                              currentLanguage,
                            ),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber[600]!, Colors.amber[400]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();

                            final admobProvider = context.read<AdMobProvider>();
                            final coinProvider = context.read<CoinProvider>();
                            final cloudBackupProvider =
                                context.read<CloudBackupProvider>();

                            await admobProvider
                                .showRewardedAd(
                                  isLoggedIn: cloudBackupProvider.isSignedIn,
                                  onRewardEarned: (amount, type) async {
                                    await coinProvider.addCoins(
                                      CoinProvider.coinsPerAd,
                                    );
                                    if (!mounted) return;
                                    CoinAdDialogs.showCoinEarnedDialog(
                                      context,
                                      CoinProvider.coinsPerAd,
                                    );
                                  },
                                )
                                .then((success) {
                                  if (!success && mounted) {
                                    CoinAdDialogs.showAdNotAvailableDialog(
                                      context,
                                    );
                                  }
                                });
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.getString(
                                  'watch_ad_earn_coins',
                                  currentLanguage,
                                ),
                                style: themeProvider.getFontForCurrentLanguage(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildMainContent(FoodProvider foodProvider) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    if (foodProvider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon with Background
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.red[200]!, width: 2),
                ),
                child: Icon(
                  IconlyBold.danger,
                  size: 60,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 24),

              // Error Title
              Text(
                AppLocalizations.getString(
                  'oops_something_went_wrong',
                  currentLanguage,
                ),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Error Message
              Text(
                '${AppLocalizations.getString('loading_error_title', currentLanguage)}\n• ${AppLocalizations.getString('internet_connection_problem', currentLanguage)}\n• ${AppLocalizations.getString('server_unavailable', currentLanguage)}\n• ${AppLocalizations.getString('app_configuration_issue', currentLanguage)}',
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 14,
                  color: isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Try Again Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // Clear error and reload data
                    foodProvider.clearError();
                    foodProvider.loadFoods();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString(
                          'try_again',
                          currentLanguage,
                        ),
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Additional Help Text
              Text(
                AppLocalizations.getString('internet_check', currentLanguage),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 12,
                  color: isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (foodProvider.foods.isNotEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Summary
            NutritionSummaryCard(
              totalCalories: foodProvider.getTodayCaloriesSync(),
              totalProtein: foodProvider.getTodayProteinSync(),
              totalCarbs: foodProvider.getTodayCarbsSync(),
              totalFat: foodProvider.getTodayFatSync(),
              title: AppLocalizations.getString(
                'todays_nutrition',
                currentLanguage,
              ),
            ),
            const SizedBox(height: 24),

            // Today's Food List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.getString('todays_food', currentLanguage),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  '${AppLocalizations.getString('total', currentLanguage)}: ${foodProvider.getTodayFoodsSync().length}',
                  style: themeProvider.getFontForCurrentLanguage(
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FoodList(foods: foodProvider.getTodayFoodsSync()),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 80,
                      color: isDarkMode ? AppColors.grey600 : AppColors.grey400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.getString(
                        'no_food_today',
                        currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.getString(
                        'start_with_photo',
                        currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 15,
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, FoodProvider>(
      builder: (context, themeProvider, languageProvider, foodProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString('hello', currentLanguage),
                  style: _getStyledText(
                    themeProvider,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
                Text(
                  AppLocalizations.getString(
                    'calorie_tracker',
                    currentLanguage,
                  ),
                  style: _getStyledText(
                    themeProvider,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(IconlyBold.chat, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageTransition(child: const HealthCoachScreen()),
                  );
                },
                tooltip: AppLocalizations.getString(
                  'health_coach_title',
                  currentLanguage,
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showImageSourceDialog,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(IconlyBold.scan, size: 28),
          ),
          body: Column(
            children: [
              Expanded(
                child: _isInitialLoading
                    ? _buildLoadingView(
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      )
                    : _buildMainContentWithLoading(
                        foodProvider,
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
              ),
              const AdaptiveBannerAd(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingView(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Center(
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
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkMode
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    strokeWidth: 3,
                    backgroundColor: isDarkMode
                        ? AppColors.grey800
                        : AppColors.grey200,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Loading Text
          Text(
            AppLocalizations.getString(
              'loading',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Loading Subtitle
          Text(
            AppLocalizations.getString(
              'preparing_food_data',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContentWithLoading(
    FoodProvider foodProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    // Show loading when analyzing image
    if (foodProvider.isLoading) {
      return Center(
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
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      strokeWidth: 3,
                      backgroundColor: isDarkMode
                          ? AppColors.grey800
                          : AppColors.grey200,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Loading Text
            Text(
              AppLocalizations.getString(
                'scanning',
                languageProvider.currentLanguage,
              ),
              style: themeProvider.getFontForCurrentLanguage(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 8),

            // Loading Subtitle
            Text(
              AppLocalizations.getString(
                'scanning_food_image',
                languageProvider.currentLanguage,
              ),
              style: themeProvider.getFontForCurrentLanguage(
                fontSize: 14,
                color: isDarkMode
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    return _buildMainContent(foodProvider);
  }
}
