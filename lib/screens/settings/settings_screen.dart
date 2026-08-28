import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/config/exports/providers.dart';
import 'package:nutriscan/config/exports/screens.dart';
import 'package:nutriscan/config/exports/widgets.dart';
import 'package:nutriscan/utils/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(
              AppLocalizations.getString('settings', currentLanguage),
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            elevation: 0,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // App Settings
                      _buildAppSettings(),
                      const SizedBox(height: 24),

                      // Subscription Section
                      _buildSubscriptionSection(),
                      const SizedBox(height: 24),

                      // Ad for Rewards Section
                      _buildAdRewardsSection(),
                      const SizedBox(height: 24),

                      // Data & Privacy
                      _buildDataPrivacy(),
                      const SizedBox(height: 24),

                      // About Section
                      _buildAboutSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              const AdaptiveBannerAd(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppSettings() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppLocalizations.getString('app_settings', currentLanguage),
          icon: Icons.settings,
        ),
        SettingsCard(
          icon: Icons.dark_mode,
          title: AppLocalizations.getString('dark_mode', currentLanguage),
          subtitle: AppLocalizations.getString(
            'dark_mode_subtitle',
            currentLanguage,
          ),
          color: Colors.purple,
          trailing: Switch(
            value: isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
          onTap: null,
        ),
        const SizedBox(height: 12),
        SettingsCard(
          icon: Icons.language,
          title: AppLocalizations.getString('language', currentLanguage),
          subtitle: AppLocalizations.getString(
            'language_subtitle',
            currentLanguage,
          ),
          color: Colors.blue,
          trailing: const LanguageDropdown(),
          onTap: null,
        ),
        const SizedBox(height: 12),
        SettingsCard(
          icon: Icons.notifications,
          title: AppLocalizations.getString(
            'notification_settings',
            currentLanguage,
          ),
          subtitle: AppLocalizations.getString(
            'notification_settings_subtitle',
            currentLanguage,
          ),
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              PageTransition(child: const NotificationSettingsScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        SettingsCard(
          icon: Icons.auto_awesome,
          title: AppLocalizations.getString(
            'meal_plan_settings_title',
            currentLanguage,
          ),
          subtitle: AppLocalizations.getString(
            'meal_plan_settings_subtitle',
            currentLanguage,
          ),
          color: Colors.teal,
          onTap: () {
            Navigator.push(
              context,
              PageTransition(child: const MealPlanPreferencesScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionSection() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppLocalizations.getString('subscription', currentLanguage),
          icon: Icons.star,
        ),
        Consumer<SubscriptionProvider>(
          builder: (context, subscriptionProvider, child) {
            if (subscriptionProvider.isSubscribed) {
              return SettingsCard(
                icon: Icons.check_circle,
                title: AppLocalizations.getString(
                  'premium_active',
                  currentLanguage,
                ),
                subtitle: AppLocalizations.getString(
                  'manage_subscription',
                  currentLanguage,
                ),
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(child: const SubscriptionScreen()),
                  );
                },
              );
            } else {
              return SettingsCard(
                icon: Icons.star,
                title: AppLocalizations.getString(
                  'upgrade_to_premium',
                  currentLanguage,
                ),
                subtitle: AppLocalizations.getString(
                  'remove_ads_unlock_features',
                  currentLanguage,
                ),
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(child: const SubscriptionScreen()),
                  );
                },
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildAdRewardsSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return Consumer3<CoinProvider, CloudBackupProvider, SubscriptionProvider>(
      builder:
          (
            context,
            coinProvider,
            cloudBackupProvider,
            subscriptionProvider,
            child,
          ) {
            final isPremium = subscriptionProvider.hasPremiumFeatures;

            // Hide section for premium users
            if (isPremium) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: AppLocalizations.getString(
                    'ad_for_rewards',
                    currentLanguage,
                  ),
                  icon: Icons.card_giftcard,
                ),

                // Coin Balance Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.getString(
                                  'your_coins',
                                  currentLanguage,
                                ),
                                style: themeProvider.getFontForCurrentLanguage(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.monetization_on,
                                    color: Colors.amber[300],
                                    size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${coinProvider.coinBalance}',
                                    style: themeProvider
                                        .getFontForCurrentLanguage(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.getString(
                                    'total_earned',
                                    currentLanguage,
                                  ),
                                  style: themeProvider
                                      .getFontForCurrentLanguage(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                ),
                                Text(
                                  '${coinProvider.totalCoinsEarned}',
                                  style: themeProvider
                                      .getFontForCurrentLanguage(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.getString(
                                    'total_spent',
                                    currentLanguage,
                                  ),
                                  style: themeProvider
                                      .getFontForCurrentLanguage(
                                        fontSize: 12,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                ),
                                Text(
                                  '${coinProvider.totalCoinsSpent}',
                                  style: themeProvider
                                      .getFontForCurrentLanguage(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Watch Ad Button
                SettingsCard(
                  icon: Icons.play_circle_filled,
                  title: AppLocalizations.getString(
                    'watch_ad_earn_coins',
                    currentLanguage,
                  ),
                  subtitle: AppLocalizations.getString(
                    'ad_for_rewards_subtitle',
                    currentLanguage,
                  ),
                  color: Colors.green,
                  onTap: () => _showWatchAdDialog(coinProvider),
                ),
              ],
            );
          },
    );
  }

  Widget _buildDataPrivacy() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppLocalizations.getString('data_privacy', currentLanguage),
          icon: Icons.security,
        ),
        SettingsCard(
          icon: Icons.cloud_upload,
          title: AppLocalizations.getString(
            'cloud_backup_settings',
            currentLanguage,
          ),
          subtitle: AppLocalizations.getString(
            'cloud_backup_settings_subtitle',
            currentLanguage,
          ),
          color: AppColors.primary,
          onTap: () {
            Navigator.push(
              context,
              PageTransition(child: const CloudBackupScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        SettingsCard(
          icon: Icons.delete_forever,
          title: AppLocalizations.getString('clear_all_data', currentLanguage),
          subtitle: AppLocalizations.getString(
            'clear_all_data_subtitle',
            currentLanguage,
          ),
          color: Colors.red,
          onTap: () => _showClearDataDialog(),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppLocalizations.getString('about', currentLanguage),
          icon: Icons.info,
        ),
        SettingsCard(
          icon: Icons.privacy_tip,
          title: AppLocalizations.getString('privacy_policy', currentLanguage),
          subtitle: AppLocalizations.getString(
            'privacy_policy_subtitle',
            currentLanguage,
          ),
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              PageTransition(child: const PrivacyPolicyScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        SettingsCard(
          icon: Icons.description,
          title: AppLocalizations.getString(
            'terms_of_service',
            currentLanguage,
          ),
          subtitle: AppLocalizations.getString(
            'terms_of_service_subtitle',
            currentLanguage,
          ),
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              PageTransition(child: const TermsOfServiceScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        SettingsCard(
          icon: Icons.info,
          title: AppLocalizations.getString('app_version', currentLanguage),
          subtitle: AppLocalizations.getString(
            'app_version_subtitle',
            currentLanguage,
          ),
          color: AppColors.primary,
          onTap: () {
            Navigator.push(
              context,
              PageTransition(child: const AppVersionScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        Consumer<CloudBackupProvider>(
          builder: (context, backupProvider, child) {
            if (backupProvider.isSignedIn) {
              return SettingsCard(
                icon: IconlyBold.logout,
                title: AppLocalizations.getString('logout', currentLanguage),
                subtitle: AppLocalizations.getString(
                  'logout_subtitle',
                  currentLanguage,
                ),
                color: Colors.red,
                onTap: () => _showLogoutDialog(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                // Logout Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    IconlyBold.logout,
                    size: 48,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.getString('logout_title', currentLanguage),
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

                // Description
                Text(
                  AppLocalizations.getString(
                    'logout_description',
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

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
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
                              'cancel_btn',
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

                    // Logout Button
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red[500],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () async {
                            final backupProvider = context
                                .read<CloudBackupProvider>();
                            await backupProvider.signOut(
                              language: currentLanguage,
                            );
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'logout',
                              currentLanguage,
                            ),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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

  void _showWatchAdDialog(CoinProvider coinProvider) {
    final admobProvider = Provider.of<AdMobProvider>(context, listen: false);
    final cloudBackupProvider =
        Provider.of<CloudBackupProvider>(context, listen: false);

    admobProvider
        .showRewardedAd(
          isLoggedIn: cloudBackupProvider.isSignedIn,
          onRewardEarned: (amount, type) async {
            await coinProvider.addCoins(CoinProvider.coinsPerAd);
            if (!mounted) return;
            CoinAdDialogs.showCoinEarnedDialog(
              context,
              CoinProvider.coinsPerAd,
            );
          },
        )
        .then((success) {
          if (!success && mounted) {
            CoinAdDialogs.showAdNotAvailableDialog(context);
          }
        })
        .catchError((e) {
          if (mounted) {
            CoinAdDialogs.showAdNotAvailableDialog(context);
          }
        });
  }

  void _showClearDataDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                // Warning Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.delete_forever,
                    size: 48,
                    color: Colors.red[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.getString('clear_all_data', currentLanguage),
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

                // Description
                Text(
                  AppLocalizations.getString(
                    'clear_all_data_description',
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

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
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

                    // Clear Button
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red[500],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () async {
                            // Clear food data using FoodProvider
                            final foodProvider = context.read<FoodProvider>();
                            await foodProvider.clearAllFoods();

                            // Clear other app settings but preserve subscription data
                            final prefs = await SharedPreferences.getInstance();

                            // Save critical subscription data before clearing
                            final isSubscribed =
                                prefs.getBool('is_subscribed') ?? false;
                            final subscriptionType = prefs.getString(
                              'subscription_type',
                            );
                            final subscriptionExpiry = prefs.getString(
                              'subscription_expiry',
                            );
                            final deviceId = prefs.getString(
                              'device_id',
                            ); // Preserve device ID

                            // Preserve coin data (user's earned coins)
                            final coinBalance =
                                prefs.getInt('coin_balance') ?? 0;
                            final totalCoinsEarned =
                                prefs.getInt('total_coins_earned') ?? 0;
                            final totalCoinsSpent =
                                prefs.getInt('total_coins_spent') ?? 0;

                            // Clear all preferences
                            await prefs.clear();

                            // Restore critical subscription data
                            if (isSubscribed) {
                              await prefs.setBool('is_subscribed', true);
                            }
                            if (subscriptionType != null) {
                              await prefs.setString(
                                'subscription_type',
                                subscriptionType,
                              );
                            }
                            if (subscriptionExpiry != null) {
                              await prefs.setString(
                                'subscription_expiry',
                                subscriptionExpiry,
                              );
                            }
                            if (deviceId != null) {
                              await prefs.setString(
                                'device_id',
                                deviceId,
                              ); // Restore device ID
                            }

                            // Restore coin data (user's earned coins should be preserved)
                            if (coinBalance > 0 ||
                                totalCoinsEarned > 0 ||
                                totalCoinsSpent > 0) {
                              await prefs.setInt('coin_balance', coinBalance);
                              await prefs.setInt(
                                'total_coins_earned',
                                totalCoinsEarned,
                              );
                              await prefs.setInt(
                                'total_coins_spent',
                                totalCoinsSpent,
                              );
                            }

                            // Reload subscription status and coin balance after clearing data
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            final subscriptionProvider = context
                                .read<SubscriptionProvider>();
                            if (!mounted) return;
                            await subscriptionProvider
                                .reloadSubscriptionStatus();

                            // Reload coin balance
                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            final coinProvider = context.read<CoinProvider>();
                            if (!mounted) return;
                            await coinProvider.reloadCoins();

                            if (!mounted) return;
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'clear_all',
                              currentLanguage,
                            ),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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
}
