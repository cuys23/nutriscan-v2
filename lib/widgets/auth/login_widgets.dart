import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Reusable widget for login screen welcome text
class LoginWelcomeText extends StatelessWidget {
  const LoginWelcomeText({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            // The brand name is the same in every locale now, so the old
            // replaceAll that swapped it for a per-locale spelling would only
            // substitute 'NourishShot' for 'NourishShot'.
            text: AppLocalizations.getString(
              'welcome_to_nutriscan',
              currentLanguage,
            ),
          ),
        ],
      ),
      style: themeProvider.getFontForCurrentLanguage(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: isDarkMode
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Reusable widget for login screen description
class LoginDescriptionText extends StatelessWidget {
  const LoginDescriptionText({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text:
                AppLocalizations.getString(
                  'login_description',
                  currentLanguage,
                ).replaceAll(
                  'Google',
                  AppLocalizations.getString('google', currentLanguage),
                ),
          ),
        ],
      ),
      style: themeProvider.getFontForCurrentLanguage(
        fontSize: 16,
        height: 1.5,
        color: isDarkMode
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Reusable widget for Google sign-in button
class GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const GoogleSignInButton({
    super.key,
    required this.isLoading,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : SvgPicture.asset(
                'assets/images/svg/google_logo.svg',
                width: 26,
                height: 26,
              ),
        label: Text(
          isLoading
              ? AppLocalizations.getString('signing_in', currentLanguage)
              : AppLocalizations.getString(
                  'sign_in_with_google',
                  currentLanguage,
                ).replaceAll(
                  'Google',
                  AppLocalizations.getString('google', currentLanguage),
                ),
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Reusable widget for skip button
class SkipButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const SkipButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return TextButton(
      onPressed: onPressed,
      child: Text(
        AppLocalizations.getString('skip_for_now', currentLanguage),
        style: themeProvider.getFontForCurrentLanguage(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDarkMode
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

/// Reusable widget for login screen logo
class LoginLogo extends StatelessWidget {
  const LoginLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/svg/login.svg',
      height: 250,
      fit: BoxFit.contain,
    );
  }
}
