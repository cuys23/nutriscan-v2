import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class PolicyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? gradientStartColor;
  final Color? gradientEndColor;
  final double? iconSize;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const PolicyHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.gradientStartColor,
    this.gradientEndColor,
    this.iconSize,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final iconSizeValue = iconSize ?? 48.0;

        return Container(
          width: double.infinity,
          margin: margin ?? const EdgeInsets.symmetric(vertical: 16),
          padding: padding ?? const EdgeInsets.all(24),
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
              Icon(icon, size: iconSizeValue, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                title,
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
