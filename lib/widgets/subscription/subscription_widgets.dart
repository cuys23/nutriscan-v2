import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class StoreErrorDialog extends StatelessWidget {
  const StoreErrorDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const StoreErrorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return AlertDialog(
      backgroundColor: isDarkMode ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(IconlyBold.danger, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.getString('store_setup_required', currentLanguage),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
      content: Text(
        AppLocalizations.getString('store_setup_unavailable_msg', currentLanguage),
        style: themeProvider.getFontForCurrentLanguage(
          fontSize: 14,
          color: isDarkMode ? Colors.white70 : AppColors.textSecondaryLight,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppLocalizations.getString('i_understand', currentLanguage),
            style: themeProvider.getFontForCurrentLanguage(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
