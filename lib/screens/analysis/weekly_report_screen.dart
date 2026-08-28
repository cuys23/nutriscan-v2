import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/screens/subscription/subscription_screen.dart';
import 'package:nutriscan/services/database/database_helper.dart';
import 'package:nutriscan/utils/page_transition.dart';
import 'package:nutriscan/widgets/ads/adaptive_banner_ad.dart';
import 'package:provider/provider.dart';


class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;
  int _totalFoods = 0;
  double _totalCalories = 0;
  double _avgCaloriesPerDay = 0;
  List<Food> _weeklyFoods = [];
  Map<String, int> _dailyFoodCount = {};
  Map<String, double> _dailyCalories = {};

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    setState(() => _isLoading = true);

    try {
      // Get foods for last 7 days from database
      _weeklyFoods = await _dbHelper.getFoodsForLastWeek();

      // Calculate statistics
      _totalFoods = _weeklyFoods.length;
      _totalCalories = _weeklyFoods.fold(0, (sum, food) => sum + food.calories);

      // Count unique days
      final uniqueDays = <String>{};
      for (var food in _weeklyFoods) {
        final dateKey =
            '${food.analyzedAt.year}-${food.analyzedAt.month}-${food.analyzedAt.day}';
        uniqueDays.add(dateKey);
      }
      _avgCaloriesPerDay = uniqueDays.isNotEmpty
          ? _totalCalories / uniqueDays.length
          : 0;

      // Daily breakdown
      _dailyFoodCount = {};
      _dailyCalories = {};
      for (var food in _weeklyFoods) {
        final dateKey = _getDateKey(food.analyzedAt);
        _dailyFoodCount[dateKey] = (_dailyFoodCount[dateKey] ?? 0) + 1;
        _dailyCalories[dateKey] =
            (_dailyCalories[dateKey] ?? 0) + food.calories;
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      final day = int.parse(parts[2]);
      final month = int.parse(parts[1]);
      return '$day/${month.toString().padLeft(2, '0')}';
    }
    return dateKey;
  }

  String _getWeekRange() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 7));
    return '${startOfWeek.day}/${startOfWeek.month} - ${now.day}/${now.month}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isPremium = subscriptionProvider.isSubscribed;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          AppLocalizations.getString(
            'weekly_report',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getFontForCurrentLanguage(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(IconlyLight.arrow_left, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : !isPremium
                ? _buildPremiumLock(themeProvider, languageProvider, isDarkMode)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Card
                        _buildSummaryCard(
                          themeProvider,
                          languageProvider,
                          isDarkMode,
                        ),
                        const SizedBox(height: 20),

                        // Statistics
                        _buildStatisticsSection(
                          themeProvider,
                          languageProvider,
                          isDarkMode,
                        ),
                        const SizedBox(height: 20),

                        // Daily Breakdown Chart
                        _buildDailyBreakdown(
                          themeProvider,
                          languageProvider,
                          isDarkMode,
                        ),
                        const SizedBox(height: 20),

                        // All Foods List
                        _buildFoodsList(
                          themeProvider,
                          languageProvider,
                          isDarkMode,
                        ),
                      ],
                    ),
                  ),
          ),
          const AdaptiveBannerAd(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.getString(
              'last_7_days',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getWeekRange(),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: IconlyBold.document,
                value: _totalFoods.toString(),
                label: AppLocalizations.getString(
                  'meals',
                  languageProvider.currentLanguage,
                ),
                themeProvider: themeProvider,
                languageProvider: languageProvider,
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              _buildSummaryItem(
                icon: IconlyBold.activity,
                value: _avgCaloriesPerDay.toStringAsFixed(0),
                label: AppLocalizations.getString(
                  'avg_cal_day',
                  languageProvider.currentLanguage,
                ),
                themeProvider: themeProvider,
                languageProvider: languageProvider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required ThemeProvider themeProvider,
    required LanguageProvider languageProvider,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.getString(
              'statistics',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            AppLocalizations.getString(
              'avg_calories_per_day',
              languageProvider.currentLanguage,
            ),
            '${_avgCaloriesPerDay.toStringAsFixed(0)} ${AppLocalizations.getString('cal', languageProvider.currentLanguage)}',
            themeProvider,
            isDarkMode,
          ),
          const Divider(height: 24),
          _buildStatRow(
            AppLocalizations.getString(
              'total_meals',
              languageProvider.currentLanguage,
            ),
            '$_totalFoods ${AppLocalizations.getString('meals', languageProvider.currentLanguage)}',
            themeProvider,
            isDarkMode,
          ),
          const Divider(height: 24),
          _buildStatRow(
            AppLocalizations.getString(
              'total_calories',
              languageProvider.currentLanguage,
            ),
            '${_totalCalories.toStringAsFixed(0)} ${AppLocalizations.getString('cal', languageProvider.currentLanguage)}',
            themeProvider,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    ThemeProvider themeProvider,
    bool isDarkMode,
  ) {
    return Row(
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyBreakdown(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    final sortedKeys = _dailyFoodCount.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.getString(
              'daily_breakdown',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          _dailyFoodCount.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      AppLocalizations.getString(
                        'no_data_available',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 14,
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      final dateKey = sortedKeys[index];
                      final count = _dailyFoodCount[dateKey] ?? 0;
                      final calories = _dailyCalories[dateKey] ?? 0;
                      final maxCount = _dailyFoodCount.values.reduce(
                        (a, b) => a > b ? a : b,
                      );
                      final heightFactor = count / maxCount;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '$count',
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 36,
                              height: 70 * heightFactor,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDateKey(dateKey),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 11,
                                color: isDarkMode
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            Text(
                              '${calories.toStringAsFixed(0)} ${AppLocalizations.getString('cal', languageProvider.currentLanguage)}',
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 10,
                                color: isDarkMode
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFoodsList(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    if (_weeklyFoods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            AppLocalizations.getString(
              'no_meals_recorded_week',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '${AppLocalizations.getString('all_meals', languageProvider.currentLanguage)} (${_weeklyFoods.length})',
              style: themeProvider.getFontForCurrentLanguage(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _weeklyFoods.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isDarkMode ? AppColors.grey700 : AppColors.grey300,
            ),
            itemBuilder: (context, index) {
              final food = _weeklyFoods[index];
              final date = food.analyzedAt;
              final daysAgo = DateTime.now().difference(date).inDays;
              final timeAgoText = daysAgo == 0
                  ? AppLocalizations.getString(
                      'today',
                      languageProvider.currentLanguage,
                    )
                  : daysAgo == 1
                  ? AppLocalizations.getString(
                      'yesterday',
                      languageProvider.currentLanguage,
                    )
                  : AppLocalizations.getString(
                      'days_ago',
                      languageProvider.currentLanguage,
                    ).replaceAll('{days}', '$daysAgo');

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    '${date.day}',
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                title: Text(
                  food.name,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  '$timeAgoText • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                trailing: Text(
                  '${food.calories.toStringAsFixed(0)} ${AppLocalizations.getString('cal', languageProvider.currentLanguage)}',
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLock(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(IconlyBold.lock, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 32),
            Text(
              AppLocalizations.getString(
                'premium_feature',
                languageProvider.currentLanguage,
              ),
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: isDarkMode ? Colors.white : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.getString(
                'premium_reports_only',
                languageProvider.currentLanguage,
              ),
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.normal,
                fontSize: 16,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textPrimaryLight.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.surfaceDark.withValues(alpha: 0.5)
                    : AppColors.surfaceLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(IconlyBold.star, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.getString(
                        'unlock_detailed_reports',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageTransition(child: const SubscriptionScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(IconlyBold.shield_done, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.getString(
                        'upgrade_to_premium',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
