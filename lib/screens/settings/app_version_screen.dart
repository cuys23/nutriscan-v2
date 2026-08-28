import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_config.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/common/info_card.dart';
import 'package:nutriscan/widgets/common/info_row.dart';
import 'package:provider/provider.dart';

class AppVersionScreen extends StatelessWidget {
  const AppVersionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Consumer2<ThemeProvider, LanguageProvider>(
          builder: (context, themeProvider, languageProvider, child) {
            return Text(
              AppLocalizations.getString(
                'app_version',
                languageProvider.currentLanguage,
              ),
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            );
          },
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(IconlyLight.arrow_left, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // App Logo and Version
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // App Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25.0),
                      child: Image.asset(
                        'assets/images/logo.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // App Name
                  Consumer2<ThemeProvider, LanguageProvider>(
                    builder: (context, themeProvider, languageProvider, child) {
                      return Text(
                        AppConfig.appName,
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // Version
                  Consumer2<ThemeProvider, LanguageProvider>(
                    builder: (context, themeProvider, languageProvider, child) {
                      return Text(
                        '${AppLocalizations.getString('version', languageProvider.currentLanguage)} ${AppConfig.appVersion}',
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),

                  // Build Number
                  Consumer2<ThemeProvider, LanguageProvider>(
                    builder: (context, themeProvider, languageProvider, child) {
                      return Text(
                        '${AppLocalizations.getString('build_number', languageProvider.currentLanguage)} ${AppConfig.buildNumber}',
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Information
            Consumer2<ThemeProvider, LanguageProvider>(
              builder: (context, themeProvider, languageProvider, child) {
                return InfoCard(
                  title: AppLocalizations.getString(
                    'app_details',
                    languageProvider.currentLanguage,
                  ),
                  icon: Icons.info,
                  isDarkMode: isDarkMode,
                  themeProvider: themeProvider,
                  children: [
                    InfoRow(
                      label: AppLocalizations.getString(
                        'version',
                        languageProvider.currentLanguage,
                      ),
                      value: AppConfig.appVersion,
                      isDarkMode: isDarkMode,
                      themeProvider: themeProvider,
                    ),
                    InfoRow(
                      label: AppLocalizations.getString(
                        'build_number',
                        languageProvider.currentLanguage,
                      ),
                      value: AppConfig.buildNumber,
                      isDarkMode: isDarkMode,
                      themeProvider: themeProvider,
                    ),
                    InfoRow(
                      label: AppLocalizations.getString(
                        'developer',
                        languageProvider.currentLanguage,
                      ),
                      value: 'SoftSync Agency',
                      isDarkMode: isDarkMode,
                      themeProvider: themeProvider,
                    ),
                    InfoRow(
                      label: AppLocalizations.getString(
                        'platform_support',
                        languageProvider.currentLanguage,
                      ),
                      value: 'Android 15+ & iOS',
                      isDarkMode: isDarkMode,
                      themeProvider: themeProvider,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Update Button
            Consumer2<ThemeProvider, LanguageProvider>(
              builder: (context, themeProvider, languageProvider, child) {
                return Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () {
                      // Check for updates - no snackbar shown
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.getString(
                        'check_for_updates',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
