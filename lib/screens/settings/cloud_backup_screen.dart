import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:nutriscan/widgets/cloud_backup/cloud_backup_widgets.dart';
import 'package:provider/provider.dart';


class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize silently without loading state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CloudBackupProvider>().initializeSilently();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to the page without loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final backupProvider = context.read<CloudBackupProvider>();
      if (backupProvider.isInitialized && backupProvider.isSignedIn) {
        backupProvider.refreshBackupInfo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(IconlyLight.arrow_left, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.getString('cloud_backup', currentLanguage),
          style: themeProvider.getFontForCurrentLanguage(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          Consumer<CloudBackupProvider>(
            builder: (context, backupProvider, child) {
              // Check if user is premium
              final subscriptionProvider = Provider.of<SubscriptionProvider>(
                context,
                listen: false,
              );
              final isPremium = subscriptionProvider.hasPremiumFeatures;

              if (!isPremium) return const SizedBox.shrink();

              return BackupStatusIndicator(
                isSignedIn: backupProvider.isSignedIn,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<CloudBackupProvider>(
              builder: (context, backupProvider, child) {
                final languageProvider = Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                );
                final currentLanguage = languageProvider.currentLanguage;

                if (backupProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Backup Info Section
                      _buildBackupInfoSection(
                        backupProvider,
                        themeProvider,
                        isDarkMode,
                        currentLanguage,
                      ),

                      const SizedBox(height: 30),

                      // Auto Backup Section
                      _buildAutoBackupSection(
                        backupProvider,
                        themeProvider,
                        isDarkMode,
                        currentLanguage,
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
          const AdaptiveBannerAd(),
        ],
      ),
    );
  }

  Widget _buildBackupInfoSection(
    CloudBackupProvider backupProvider,
    ThemeProvider themeProvider,
    bool isDarkMode,
    String currentLanguage,
  ) {
    // Check if user is premium
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final isPremium = subscriptionProvider.hasPremiumFeatures;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.getString('backup_actions', currentLanguage),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.getString(
                      'premium_badge',
                      currentLanguage,
                    ),
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 15),

          // Backup Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (!isPremium ||
                      backupProvider.isLoading ||
                      backupProvider.isBackingUp)
                  ? null
                  : () async {
                      final subscriptionProvider =
                          Provider.of<SubscriptionProvider>(
                            context,
                            listen: false,
                          );
                      final languageProvider = Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      );
                      await backupProvider.backupData(
                        isPremiumUser: subscriptionProvider.hasPremiumFeatures,
                        language: languageProvider.currentLanguage,
                      );
                      // Backup completed - UI will update automatically
                    },
              icon: backupProvider.isBackingUp
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      isPremium ? Icons.cloud_upload : Icons.lock,
                      color: Colors.white,
                    ),
              label: Text(
                backupProvider.isBackingUp
                    ? AppLocalizations.getString('backing_up', currentLanguage)
                    : isPremium
                    ? AppLocalizations.getString(
                        'backup_to_cloud',
                        currentLanguage,
                      )
                    : AppLocalizations.getString(
                        'backup_to_cloud_premium',
                        currentLanguage,
                      ),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium ? AppColors.primary : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 15),

          // Restore Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  (!isPremium ||
                      backupProvider.isLoading ||
                      backupProvider.isRestoring)
                  ? null
                  : () async {
                      _showRestoreDialog(
                        backupProvider,
                        themeProvider,
                        isDarkMode,
                        currentLanguage,
                      );
                    },
              icon: backupProvider.isRestoring
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : Icon(
                      isPremium ? Icons.cloud_download : Icons.lock,
                      color: isPremium ? AppColors.primary : Colors.grey,
                    ),
              label: Text(
                backupProvider.isRestoring
                    ? AppLocalizations.getString('restoring', currentLanguage)
                    : isPremium
                    ? AppLocalizations.getString(
                        'restore_from_cloud',
                        currentLanguage,
                      )
                    : AppLocalizations.getString(
                        'restore_from_cloud_premium',
                        currentLanguage,
                      ),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isPremium ? AppColors.primary : Colors.grey,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: isPremium ? AppColors.primary : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoBackupSection(
    CloudBackupProvider backupProvider,
    ThemeProvider themeProvider,
    bool isDarkMode,
    String currentLanguage,
  ) {
    // Check if user is premium
    final subscriptionProvider = Provider.of<SubscriptionProvider>(
      context,
      listen: false,
    );
    final isPremium = subscriptionProvider.hasPremiumFeatures;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.getString('auto_backup', currentLanguage),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.getString(
                      'premium_badge',
                      currentLanguage,
                    ),
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.getString(
              'auto_backup_description',
              currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 15),
          FutureBuilder<bool>(
            future: backupProvider.isAutoBackupEnabled(),
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? true;
              return SwitchListTile(
                title: Text(
                  AppLocalizations.getString(
                    'enable_auto_backup',
                    currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                value: isPremium ? isEnabled : false,
                onChanged: isPremium
                    ? (value) async {
                        await backupProvider.setAutoBackupEnabled(value);
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    : null,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(
    CloudBackupProvider backupProvider,
    ThemeProvider themeProvider,
    bool isDarkMode,
    String currentLanguage,
  ) {
    showDialog(
      context: context,
      builder: (context) {
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
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.cloud_download,
                    size: 48,
                    color: Colors.orange[600],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.getString('restore_data', currentLanguage),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  AppLocalizations.getString(
                    'restore_data_warning',
                    currentLanguage,
                  ),
                  textAlign: TextAlign.center,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(
                            color: isDarkMode
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        child: Text(
                          AppLocalizations.getString(
                            'cancel_btn',
                            currentLanguage,
                          ),
                          style: themeProvider.getFontForCurrentLanguage(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            (backupProvider.isLoading ||
                                backupProvider.isRestoring)
                            ? null
                            : () async {
                                Navigator.pop(context);
                                final subscriptionProvider =
                                    Provider.of<SubscriptionProvider>(
                                      context,
                                      listen: false,
                                    );
                                final languageProvider =
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    );
                                await backupProvider.restoreData(
                                  isPremiumUser:
                                      subscriptionProvider.hasPremiumFeatures,
                                  language: languageProvider.currentLanguage,
                                );
                                // Restore completed - UI will update automatically
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: backupProvider.isRestoring
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.getString(
                                      'restoring',
                                      currentLanguage,
                                    ),
                                    style: themeProvider
                                        .getFontForCurrentLanguage(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                  ),
                                ],
                              )
                            : Text(
                                AppLocalizations.getString(
                                  'restore',
                                  currentLanguage,
                                ),
                                style: themeProvider.getFontForCurrentLanguage(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
