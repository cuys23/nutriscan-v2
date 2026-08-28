import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/config/exports/providers.dart';
import 'package:nutriscan/config/exports/widgets.dart';
import 'package:nutriscan/utils/page_transition.dart';
import 'package:provider/provider.dart';


class MealPlanPreferencesScreen extends StatelessWidget {
  const MealPlanPreferencesScreen({super.key});

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
              AppLocalizations.getString(
                'meal_plan_settings_title',
                currentLanguage,
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
                child: MealPlanGenerator(
                  showPreferences: true,
                  showResults: false,
                  onPlanGenerated: () {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      PageTransition(child: const MealPlanResultScreen()),
                    );
                  },
                ),
              ),
              const AdaptiveBannerAd(),
            ],
          ),
        );
      },
    );
  }
}

class MealPlanResultScreen extends StatelessWidget {
  const MealPlanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, MealPlanProvider>(
      builder:
          (context, themeProvider, languageProvider, mealPlanProvider, child) {
            final isDarkMode = themeProvider.isDarkMode;
            final currentLanguage = languageProvider.currentLanguage;

            return Scaffold(
              backgroundColor: isDarkMode
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              appBar: AppBar(
                title: Text(
                  AppLocalizations.getString(
                    'meal_plan_result_title',
                    currentLanguage,
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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: mealPlanProvider.isLoading
                        ? null
                        : () async {
                            await mealPlanProvider.generateMealPlan(
                              languageCode: currentLanguage,
                            );
                          },
                    tooltip: AppLocalizations.getString(
                      'refresh',
                      currentLanguage,
                    ),
                  ),
                ],
              ),
              body: Column(
                children: const [
                  Expanded(
                    child: MealPlanGenerator(
                      showPreferences: false,
                      showResults: true,
                    ),
                  ),
                  AdaptiveBannerAd(),
                ],
              ),
            );
          },
    );
  }
}
