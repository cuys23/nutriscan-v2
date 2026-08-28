import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class LanguageDropdown extends StatelessWidget {
  final EdgeInsets? padding;
  final double? fontSize;
  final FontWeight? fontWeight;

  const LanguageDropdown({
    super.key,
    this.padding,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        return Container(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: languageProvider.currentLanguage,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  languageProvider.setLanguage(newValue);
                }
              },
              dropdownColor: isDarkMode
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isDarkMode
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                size: 20,
              ),
              style: themeProvider.getFontForCurrentLanguage(
                fontSize: fontSize ?? 12,
                fontWeight: fontWeight ?? FontWeight.w600,
                color: AppColors.primary,
              ),
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇺🇸'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('english', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'bn',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇧🇩'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('bangla', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'hi',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇮🇳'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('hindi', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'es',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇪🇸'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('spanish', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'fr',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇫🇷'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('french', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'de',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇩🇪'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('german', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'zh',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇨🇳'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('chinese', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'tr',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇹🇷'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('turkish', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'ko',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇰🇷'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('korean', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'id',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇮🇩'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString(
                          'indonesian',
                          currentLanguage,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'ja',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇯🇵'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('japanese', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'ru',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇷🇺'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('russian', currentLanguage),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'ur',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇵🇰'),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.getString('urdu', currentLanguage)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'pt',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇵🇹'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString(
                          'portuguese',
                          currentLanguage,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'pt-BR',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇧🇷'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString(
                          'brazilian_portuguese',
                          currentLanguage,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'ar',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇸🇦'),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString('arabic', currentLanguage),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
