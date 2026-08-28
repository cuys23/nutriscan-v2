import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class PolicySection extends StatelessWidget {
  final String title;
  final String content;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const PolicySection({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;

        return Container(
          margin: margin ?? const EdgeInsets.only(bottom: 20),
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? AppColors.grey600.withValues(alpha: 0.3)
                  : AppColors.grey300.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            iconBackgroundColor ??
                            AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  title,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                content,
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 15,
                  color: isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
