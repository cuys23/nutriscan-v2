import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/widgets/food/food_detail_card.dart';
import 'package:provider/provider.dart';

class FoodList extends StatelessWidget {
  final List<Food> foods;

  const FoodList({super.key, required this.foods});

  // Helper method to get styled text with current language font
  TextStyle _getStyledText(
    BuildContext context,
    ThemeProvider themeProvider, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return themeProvider.getFontForCurrentLanguage(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    if (foods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: isDarkMode ? AppColors.grey600 : AppColors.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.getString('no_food_found', currentLanguage),
              style: _getStyledText(
                context,
                themeProvider,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.getString('start_adding_food', currentLanguage),
              style: _getStyledText(
                context,
                themeProvider,
                fontSize: 14,
                color: isDarkMode
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Food Items List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: foods.length,
          itemBuilder: (context, index) {
            final food = foods[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FoodDetailCard(food: food),
            );
          },
        ),
      ],
    );
  }
}
