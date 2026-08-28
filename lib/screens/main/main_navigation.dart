import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/config/exports/providers.dart';
import 'package:nutriscan/config/exports/screens.dart';
import 'package:provider/provider.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const HistoryScreen(),
    const AnalysisScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }



  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, LanguageProvider, AdMobProvider>(
      builder:
          (context, themeProvider, languageProvider, admobProvider, child) {
            final isDarkMode = themeProvider.isDarkMode;
            final currentLanguage = languageProvider.currentLanguage;

            return Scaffold(
              body: _pages[_currentIndex],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                selectedItemColor: AppColors.primary,
                unselectedItemColor: isDarkMode
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                backgroundColor: isDarkMode
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                elevation: isDarkMode ? 8 : 0,
                type: BottomNavigationBarType.fixed,
                selectedLabelStyle: themeProvider.getFontForCurrentLanguage(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: themeProvider.getFontForCurrentLanguage(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(IconlyLight.home),
                    activeIcon: Icon(IconlyBold.home),
                    label: AppLocalizations.getString('home', currentLanguage),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(IconlyLight.time_circle),
                    activeIcon: Icon(IconlyBold.time_circle),
                    label: AppLocalizations.getString(
                      'history',
                      currentLanguage,
                    ),
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(IconlyLight.chart),
                    activeIcon: Icon(IconlyBold.chart),
                    label: AppLocalizations.getString(
                      'analysis',
                      currentLanguage,
                    ),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(IconlyLight.setting),
                    activeIcon: const Icon(IconlyBold.setting),
                    label: AppLocalizations.getString(
                      'settings',
                      currentLanguage,
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }
}
