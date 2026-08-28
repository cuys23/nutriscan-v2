import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class TrendItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const TrendItem({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;

        return Container(
          padding: padding ?? const EdgeInsets.all(12),
          margin: margin ?? const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Text(
                value,
                style: themeProvider.getFontForCurrentLanguage(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
