import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class NutritionSummaryCard extends StatelessWidget {
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final String? title;
  final Color? backgroundColor;
  final Color? textColor;

  const NutritionSummaryCard({
    super.key,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.title,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final bgColor = backgroundColor ?? AppColors.primary;
        final txtColor = textColor ?? Colors.white;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title ??
                        AppLocalizations.getString(
                          'nutrition_summary',
                          languageProvider.currentLanguage,
                        ),
                    style: themeProvider.getFontForCurrentLanguage(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: txtColor,
                    ),
                  ),
                  Icon(IconlyBold.chart, color: txtColor, size: 24),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildNutritionItem(
                      context,
                      AppLocalizations.getString(
                        'calories',
                        languageProvider.currentLanguage,
                      ),
                      totalCalories.toStringAsFixed(0),
                      'kcal',
                      txtColor,
                      themeProvider,
                    ),
                  ),
                  Expanded(
                    child: _buildNutritionItem(
                      context,
                      AppLocalizations.getString(
                        'protein',
                        languageProvider.currentLanguage,
                      ),
                      totalProtein.toStringAsFixed(1),
                      'g',
                      txtColor,
                      themeProvider,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildNutritionItem(
                      context,
                      AppLocalizations.getString(
                        'carbs',
                        languageProvider.currentLanguage,
                      ),
                      totalCarbs.toStringAsFixed(1),
                      'g',
                      txtColor,
                      themeProvider,
                    ),
                  ),
                  Expanded(
                    child: _buildNutritionItem(
                      context,
                      AppLocalizations.getString(
                        'fat',
                        languageProvider.currentLanguage,
                      ),
                      totalFat.toStringAsFixed(1),
                      'g',
                      txtColor,
                      themeProvider,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNutritionItem(
    BuildContext context,
    String label,
    String value,
    String unit,
    Color color,
    ThemeProvider themeProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: themeProvider.getFontForCurrentLanguage(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: color.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
