import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/notifications/notification_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/analysis/monthly_report_screen.dart';
import 'package:nutriscan/screens/analysis/weekly_report_screen.dart';
import 'package:nutriscan/screens/subscription/subscription_screen.dart';
import 'package:nutriscan/utils/page_transition.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:nutriscan/widgets/settings/notification_widgets.dart';
import 'package:provider/provider.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer4<
      ThemeProvider,
      LanguageProvider,
      NotificationProvider,
      SubscriptionProvider
    >(
      builder:
          (
            context,
            themeProvider,
            languageProvider,
            notificationProvider,
            subscriptionProvider,
            child,
          ) {
            final isDarkMode = themeProvider.isDarkMode;
            final hasPremium = subscriptionProvider.hasPremiumFeatures;

            return Scaffold(
              backgroundColor: isDarkMode
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              appBar: AppBar(
                title: Text(
                  AppLocalizations.getString(
                    'notification_settings',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: AppColors.primary,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(IconlyLight.arrow_left, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // If paused, show only pause info card, hide all other settings
                          if (notificationProvider.notificationsPaused) ...[
                            NotificationPauseCard(
                              remainingDays:
                                  notificationProvider.remainingPauseDays,
                              onResume: () {
                                notificationProvider.resumeNotifications();
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                          ] else ...[
                            // 7 Days Pause Button (Premium Only) - Only show when NOT paused
                            if (hasPremium) ...[
                              NotificationCategoryHeader(
                                titleKey: 'pause_category',
                                icon: IconlyBold.time_circle,
                                themeProvider: themeProvider,
                                languageProvider: languageProvider,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildPauseButton(
                                themeProvider,
                                languageProvider,
                                notificationProvider,
                                isDarkMode,
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Category: Meal Reminders
                            NotificationCategoryHeader(
                              titleKey: 'meal_reminders_category',
                              icon: IconlyBold.buy,
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),

                            // Meal Reminders Toggle
                            NotificationMainToggle(
                              value: notificationProvider.notificationsEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleNotifications(value);
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),

                            // Meal Reminder Cards (only show when enabled)
                            if (notificationProvider.notificationsEnabled) ...[
                              ...notificationProvider.mealReminders.map(
                                (reminder) => MealReminderCard(
                                  mealNameKey: reminder.name,
                                  icon: _getMealIcon(reminder.name),
                                  time: reminder.time,
                                  isEnabled: reminder.isEnabled,
                                  formattedTime: notificationProvider
                                      .formatTime(reminder.time),
                                  onTimePressed: () async {
                                    final newTime = await showTimePicker(
                                      context: context,
                                      initialTime: reminder.time,
                                      builder:
                                          (
                                            BuildContext context,
                                            Widget? child,
                                          ) {
                                            return MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                    alwaysUse24HourFormat:
                                                        false,
                                                  ),
                                              child: child!,
                                            );
                                          },
                                    );
                                    if (newTime != null) {
                                      notificationProvider.updateReminderTime(
                                        reminder.id,
                                        newTime,
                                      );
                                    }
                                  },
                                  onToggle: (value) {
                                    notificationProvider.toggleReminder(
                                      reminder.id,
                                      value,
                                    );
                                  },
                                  themeProvider: themeProvider,
                                  languageProvider: languageProvider,
                                  isDarkMode: isDarkMode,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Category: Progress Notifications
                            NotificationCategoryHeader(
                              titleKey: 'progress_category',
                              icon: IconlyBold.chart,
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            NotificationToggleCard(
                              icon: IconlyBold.chart,
                              iconColor: AppColors.secondary,
                              titleKey: 'daily_progress',
                              subtitleKey: 'daily_progress_subtitle',
                              value: notificationProvider.dailyProgressEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleDailyProgress(value);
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 24),

                            // Category: Inactivity Notifications
                            NotificationCategoryHeader(
                              titleKey: 'inactivity_category',
                              icon: IconlyBold.time_circle,
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            NotificationToggleCard(
                              icon: IconlyBold.time_circle,
                              iconColor: AppColors.warning,
                              titleKey: 'inactivity_reminder',
                              subtitleKey: 'inactivity_reminder_subtitle',
                              value: notificationProvider
                                  .inactivityReminderEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleInactivityReminder(
                                  value,
                                );
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 24),

                            // Category: Summary Notifications
                            NotificationCategoryHeader(
                              titleKey: 'summary_category',
                              icon: IconlyBold.calendar,
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            NotificationToggleCard(
                              icon: IconlyBold.calendar,
                              iconColor: AppColors.success,
                              titleKey: 'weekly_summary',
                              subtitleKey: 'weekly_summary_subtitle',
                              value: notificationProvider.weeklySummaryEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleWeeklySummary(value);
                              },
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageTransition(child: const WeeklyReportScreen()),
                                );
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            NotificationToggleCard(
                              icon: IconlyBold.document,
                              iconColor: AppColors.accent,
                              titleKey: 'monthly_summary',
                              subtitleKey: 'monthly_summary_subtitle',
                              value: notificationProvider.monthlySummaryEnabled,
                              onChanged: (value) {
                                notificationProvider.toggleMonthlySummary(
                                  value,
                                );
                              },
                              onTap: () {
                                final now = DateTime.now();
                                final previousMonth = now.month == 1
                                    ? 12
                                    : now.month - 1;
                                final previousYear = now.month == 1
                                    ? now.year - 1
                                    : now.year;
                                Navigator.push(
                                  context,
                                  PageTransition(
                                    child: MonthlyReportScreen(
                                      month: previousMonth,
                                      year: previousYear,
                                    ),
                                  ),
                                );
                              },
                              themeProvider: themeProvider,
                              languageProvider: languageProvider,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 24),

                            // Category: Promotion Notifications
                            if (!hasPremium) ...[
                              NotificationCategoryHeader(
                                titleKey: 'promotion_category',
                                icon: IconlyBold.star,
                                themeProvider: themeProvider,
                                languageProvider: languageProvider,
                                isDarkMode: isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildPremiumPromotionToggle(
                                themeProvider,
                                languageProvider,
                                notificationProvider,
                                isDarkMode,
                              ),
                            ],
                          ],
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

  Widget _buildPremiumPromotionToggle(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    NotificationProvider notificationProvider,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(IconlyBold.star, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    'premium_promotion',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.getString(
                    'premium_promotion_subtitle',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 13,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: notificationProvider.premiumPromotionEnabled,
            onChanged: (value) {
              // If trying to disable, show upgrade dialog
              if (!value) {
                _showUpgradeToDisableDialog();
              } else {
                // Allow enabling
                notificationProvider.togglePremiumPromotion(value);
              }
            },
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPauseButton(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    NotificationProvider notificationProvider,
    bool isDarkMode,
  ) {
    final isPaused = notificationProvider.notificationsPaused;
    final remainingDays = notificationProvider.remainingPauseDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              IconlyBold.time_circle,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    'pause_notifications',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaused
                      ? '${AppLocalizations.getString('pause_days_remaining', languageProvider.currentLanguage)}: $remainingDays'
                      : AppLocalizations.getString(
                          'pause_subtitle',
                          languageProvider.currentLanguage,
                        ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 13,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isPaused,
            onChanged: (value) {
              if (value) {
                _showPauseConfirmDialog(
                  notificationProvider,
                  themeProvider,
                  languageProvider,
                  isDarkMode,
                );
              } else {
                notificationProvider.resumeNotifications();
              }
            },
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  void _showPauseConfirmDialog(
    NotificationProvider notificationProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  IconlyBold.time_circle,
                  size: 48,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.getString(
                    'pause_confirm_title',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 20,
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
                    'pause_confirm_message',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          AppLocalizations.getString(
                            'cancel',
                            languageProvider.currentLanguage,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          notificationProvider.pauseNotificationsFor7Days();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.getString(
                            'pause_confirm',
                            languageProvider.currentLanguage,
                          ),
                          style: themeProvider.getFontForCurrentLanguage(
                            fontSize: 16,
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

  IconData _getMealIcon(String mealName) {
    switch (mealName) {
      case 'breakfast':
        return IconlyBold.time_circle;
      case 'lunch':
        return IconlyBold.time_square;
      case 'snack':
        return IconlyBold.activity;
      case 'dinner':
        return IconlyBold.calendar;
      default:
        return IconlyBold.notification;
    }
  }

  void _showUpgradeToDisableDialog() {
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
                // Premium Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    IconlyBold.star,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalizations.getString(
                    'upgrade_required',
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

                // Description
                Text(
                  AppLocalizations.getString(
                    'upgrade_to_disable_promotion',
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

                    // Upgrade Button
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Navigate to subscription screen
                            Navigator.push(
                              context,
                              PageTransition(child: const SubscriptionScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.getString(
                              'upgrade_now',
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
