import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDarkMode;
  final ThemeProvider themeProvider;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.isDarkMode,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
