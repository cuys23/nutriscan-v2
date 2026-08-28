import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';

class NotificationCategoryHeader extends StatelessWidget {
  final String titleKey;
  final IconData icon;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;

  const NotificationCategoryHeader({
    super.key,
    required this.titleKey,
    required this.icon,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.getString(
            titleKey,
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}

class NotificationToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String titleKey;
  final String subtitleKey;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const NotificationToggleCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.titleKey,
    required this.subtitleKey,
    required this.value,
    required this.onChanged,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    titleKey,
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
                    subtitleKey,
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
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }

    return content;
  }
}

class MealReminderCard extends StatelessWidget {
  final String mealNameKey;
  final IconData icon;
  final TimeOfDay time;
  final bool isEnabled;
  final VoidCallback onTimePressed;
  final ValueChanged<bool> onToggle;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;
  final String formattedTime;

  const MealReminderCard({
    super.key,
    required this.mealNameKey,
    required this.icon,
    required this.time,
    required this.isEnabled,
    required this.onTimePressed,
    required this.onToggle,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : isDarkMode
              ? AppColors.grey600
              : AppColors.grey300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isEnabled
                ? AppColors.primary
                : isDarkMode
                ? AppColors.grey600
                : AppColors.grey400,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    mealNameKey,
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
                  formattedTime,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(IconlyLight.time_circle, color: AppColors.primary),
            onPressed: onTimePressed,
          ),
          Switch(
            value: isEnabled,
            onChanged: onToggle,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class NotificationPauseCard extends StatelessWidget {
  final int remainingDays;
  final VoidCallback onResume;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;

  const NotificationPauseCard({
    super.key,
    required this.remainingDays,
    required this.onResume,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconlyBold.time_circle,
                color: AppColors.primary,
                size: 72,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              AppLocalizations.getString(
                'pause_active',
                languageProvider.currentLanguage,
              ),
              style: themeProvider.getFontForCurrentLanguage(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(IconlyBold.calendar, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  '$remainingDays ${AppLocalizations.getString('days', languageProvider.currentLanguage)} ${AppLocalizations.getString('remaining', languageProvider.currentLanguage)}',
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                AppLocalizations.getString(
                  'pause_info_message',
                  languageProvider.currentLanguage,
                ),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 16,
                  color: isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.7,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 280,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: onResume,
                icon: const Icon(IconlyBold.play, size: 24),
                label: Text(
                  AppLocalizations.getString(
                    'resume_now',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationMainToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final bool isDarkMode;

  const NotificationMainToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.themeProvider,
    required this.languageProvider,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Icon(IconlyBold.buy, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.getString(
                    'enable_notifications',
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
                    'notification_description',
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
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
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
