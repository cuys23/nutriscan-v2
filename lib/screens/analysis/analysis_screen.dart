import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/config/exports/models.dart';
import 'package:nutriscan/config/exports/providers.dart';
import 'package:nutriscan/config/exports/widgets.dart';
import 'package:nutriscan/services/ai/groq_service.dart';
import 'package:provider/provider.dart';


class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _loadingController;
  late Animation<double> _loadingRotation;
  String _selectedPeriod = 'week';
  String _selectedMetric = 'calories';
  bool _hasShownInterstitialOnEntry = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _loadingRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );

    _loadingController.repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInterstitialOnFirstEntry();
    });
  }

  Future<void> _showInterstitialOnFirstEntry() async {
    if (_hasShownInterstitialOnEntry) return;

    final admobProvider = context.read<AdMobProvider>();
    await admobProvider.showInterstitialOnAnalysisEntry();
    _hasShownInterstitialOnEntry = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<FoodProvider, ThemeProvider, LanguageProvider>(
      builder: (context, foodProvider, themeProvider, languageProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        return Scaffold(
          backgroundColor: isDarkMode
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          appBar: AppBar(
            title: Text(
              AppLocalizations.getString('analysis', currentLanguage),
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.primary,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(IconlyBold.info_circle, color: Colors.white),
                onPressed: () => _showAnalysisInfo(context, languageProvider),
                tooltip: AppLocalizations.getString(
                  'analysis_info',
                  languageProvider.currentLanguage,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildPeriodSelector(context, themeProvider, languageProvider),
              _buildMetricSelector(context, themeProvider, languageProvider),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(
                      context,
                      foodProvider,
                      themeProvider,
                      languageProvider,
                    ),
                    _buildTrendsTab(
                      context,
                      foodProvider,
                      themeProvider,
                      languageProvider,
                    ),
                    _buildInsightsTab(
                      context,
                      foodProvider,
                      themeProvider,
                      languageProvider,
                    ),
                  ],
                ),
              ),
              const AdaptiveBannerAd(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return PeriodSelector(
      selectedPeriod: _selectedPeriod,
      onPeriodChanged: (period) => setState(() => _selectedPeriod = period),
    );
  }

  Widget _buildMetricSelector(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return MetricSelector(
      selectedMetric: _selectedMetric,
      onMetricChanged: (metric) => setState(() => _selectedMetric = metric),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    FoodProvider foodProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final foods = foodProvider.foods;
    if (foods.isEmpty) {
      return _buildEmptyState(context, themeProvider, languageProvider);
    }

    final filteredFoods = _filterFoodsByPeriod(foods, _selectedPeriod);
    final totalCalories = filteredFoods.fold(
      0.0,
      (sum, food) => sum + food.calories,
    );
    final totalProtein = filteredFoods.fold(
      0.0,
      (sum, food) => sum + food.protein,
    );
    final totalCarbs = filteredFoods.fold(0.0, (sum, food) => sum + food.carbs);
    final totalFat = filteredFoods.fold(0.0, (sum, food) => sum + food.fat);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(
            context,
            themeProvider,
            languageProvider,
            totalCalories,
            totalProtein,
            totalCarbs,
            totalFat,
          ),
          const SizedBox(height: 20),
          _buildMacronutrientChart(
            context,
            filteredFoods,
            themeProvider,
            languageProvider,
          ),
          const SizedBox(height: 20),
          _buildTopFoodsList(
            context,
            filteredFoods,
            themeProvider,
            languageProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(
    BuildContext context,
    FoodProvider foodProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    final foods = foodProvider.foods;
    if (foods.isEmpty) {
      return _buildEmptyState(context, themeProvider, languageProvider);
    }

    final filteredFoods = _filterFoodsByPeriod(foods, _selectedPeriod);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.getString(
              'trends',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          _buildTrendChart(
            context,
            filteredFoods,
            themeProvider,
            languageProvider,
          ),
          const SizedBox(height: 24),
          _buildTrendInsights(
            context,
            filteredFoods,
            themeProvider,
            languageProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab(
    BuildContext context,
    FoodProvider foodProvider,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    final foods = foodProvider.foods;
    if (foods.isEmpty) {
      return _buildEmptyState(context, themeProvider, languageProvider);
    }

    final filteredFoods = _filterFoodsByPeriod(foods, _selectedPeriod);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.getString(
              'insights',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          _buildHealthScoreChart(
            context,
            filteredFoods,
            themeProvider,
            languageProvider,
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchInsightsFromServer(filteredFoods, languageProvider),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState(
                  context,
                  themeProvider,
                  languageProvider,
                );
              } else if (snapshot.hasError) {
                // Fallback to local insights on error
                final localInsights = _generateLocalInsights(
                  filteredFoods,
                  languageProvider,
                );
                return Column(
                  children: localInsights
                      .map(
                        (insight) => _buildInsightCard(
                          context,
                          insight,
                          themeProvider,
                          languageProvider,
                        ),
                      )
                      .toList(),
                );
              } else if (snapshot.hasData) {
                final insights = snapshot.data!;
                return Column(
                  children: insights
                      .map(
                        (insight) => _buildInsightCard(
                          context,
                          insight,
                          themeProvider,
                          languageProvider,
                        ),
                      )
                      .toList(),
                );
              } else {
                // Fallback to local insights
                final localInsights = _generateLocalInsights(
                  filteredFoods,
                  languageProvider,
                );
                return Column(
                  children: localInsights
                      .map(
                        (insight) => _buildInsightCard(
                          context,
                          insight,
                          themeProvider,
                          languageProvider,
                        ),
                      )
                      .toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Build loading state using app's standard loading pattern
  Widget _buildLoadingState(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    final currentLanguage = languageProvider.currentLanguage;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rotating Loading Circle
          AnimatedBuilder(
            animation: _loadingController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _loadingRotation.value * 2 * 3.14159,
                // Convert to radians
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkMode
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    strokeWidth: 3,
                    backgroundColor: isDarkMode
                        ? AppColors.grey800
                        : AppColors.grey200,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Loading Text
          Text(
            AppLocalizations.getString('analyzing_data', currentLanguage),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Loading Subtitle
          Text(
            AppLocalizations.getString('generating_insights', currentLanguage),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    double totalCalories,
    double totalProtein,
    double totalCarbs,
    double totalFat,
  ) {
    return NutritionSummaryCard(
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      title: AppLocalizations.getString(
        'total_nutrition',
        languageProvider.currentLanguage,
      ),
      backgroundColor: AppColors.primary,
      textColor: Colors.white,
    );
  }

  Widget _buildMacronutrientChart(
    BuildContext context,
    List<Food> foods,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    final protein = foods.fold(0.0, (sum, food) => sum + food.protein);
    final carbs = foods.fold(0.0, (sum, food) => sum + food.carbs);
    final fat = foods.fold(0.0, (sum, food) => sum + food.fat);
    final total = protein + carbs + fat;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.getString(
              'macronutrient_distribution',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: protein,
                            title:
                                '${(protein / total * 100).toStringAsFixed(1)}%',
                            color: AppColors.primary,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: carbs,
                            title:
                                '${(carbs / total * 100).toStringAsFixed(1)}%',
                            color: Colors.orange,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: fat,
                            title: '${(fat / total * 100).toStringAsFixed(1)}%',
                            color: Colors.red,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        centerSpaceRadius: 35,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                        AppLocalizations.getString(
                          'protein',
                          languageProvider.currentLanguage,
                        ),
                        AppColors.primary,
                        '${protein.toStringAsFixed(1)}g',
                        themeProvider,
                      ),
                      const SizedBox(height: 12),
                      _buildLegendItem(
                        AppLocalizations.getString(
                          'carbs',
                          languageProvider.currentLanguage,
                        ),
                        Colors.orange,
                        '${carbs.toStringAsFixed(1)}g',
                        themeProvider,
                      ),
                      const SizedBox(height: 12),
                      _buildLegendItem(
                        AppLocalizations.getString(
                          'fat',
                          languageProvider.currentLanguage,
                        ),
                        Colors.red,
                        '${fat.toStringAsFixed(1)}g',
                        themeProvider,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    Color color,
    String value,
    ThemeProvider themeProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
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
        const SizedBox(width: 6),
        Text(
          value,
          style: themeProvider.getFontForCurrentLanguage(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTopFoodsList(
    BuildContext context,
    List<Food> foods,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    final sortedFoods = List<Food>.from(foods)
      ..sort((a, b) => _getNutritionValueByMetric(b, _selectedMetric)
          .compareTo(_getNutritionValueByMetric(a, _selectedMetric)));
    final topFoods = sortedFoods.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.getString(
              'top_foods',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          ...topFoods.map(
            (food) => _buildTopFoodItem(
              context,
              food,
              themeProvider,
              languageProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFoodItem(
    BuildContext context,
    Food food,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.grey800 : AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.restaurant_menu,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  '${_getNutritionValueByMetric(food, _selectedMetric).toStringAsFixed(0)} ${_getMetricUnit(_selectedMetric, languageProvider.currentLanguage)}',
                  style: themeProvider.getFontForCurrentLanguage(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${food.healthScore}/10',
              style: themeProvider.getFontForCurrentLanguage(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    List<Food> foods,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return TrendChart(foods: foods, metric: _selectedMetric);
  }

  Widget _buildTrendInsights(
    BuildContext context,
    List<Food> foods,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    if (foods.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          AppLocalizations.getString(
            'insufficient_data',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 16,
            color: isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      );
    }

    final avgValue =
        foods.fold(0.0, (sum, food) => sum + _getNutritionValueByMetric(food, _selectedMetric)) / foods.length;
    final trend = _calculateTrend(foods, _selectedMetric);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.getString(
              'trend_analysis',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          _buildTrendItem(
            context,
            _getMetricAverageLabel(_selectedMetric, languageProvider.currentLanguage),
            '${avgValue.toStringAsFixed(0)} ${_getMetricUnit(_selectedMetric, languageProvider.currentLanguage)}',
            trend > 0 ? Icons.trending_up : Icons.trending_down,
            trend > 0 ? Colors.green : Colors.red,
            themeProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeProvider themeProvider,
  ) {
    return TrendItem(label: label, value: value, icon: icon, color: color);
  }

  Widget _buildHealthScoreChart(
    BuildContext context,
    List<Food> foods,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return HealthScoreChart(foods: foods);
  }

  Widget _buildInsightCard(
    BuildContext context,
    Map<String, dynamic> insight,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                insight['icon'] as IconData,
                color: insight['color'] as Color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  insight['title'] as String,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight['description'] as String,
            style: themeProvider.getFontForCurrentLanguage(
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

  Widget _buildEmptyState(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            IconlyLight.chart,
            size: 64,
            color: isDarkMode ? AppColors.grey600 : AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.getString(
              'no_data_for_analysis',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.getString(
              'start_adding_food_analysis',
              languageProvider.currentLanguage,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  double _getNutritionValueByMetric(Food food, String metric) {
    switch (metric) {
      case 'calories':
        return food.calories;
      case 'protein':
        return food.protein;
      case 'carbs':
        return food.carbs;
      case 'fat':
        return food.fat;
      default:
        return food.calories;
    }
  }

  String _getMetricUnit(String metric, String languageCode) {
    switch (metric) {
      case 'calories':
        return 'kcal';
      case 'protein':
      case 'carbs':
      case 'fat':
        return 'g';
      default:
        return '';
    }
  }

  String _getMetricAverageLabel(String metric, String languageCode) {
    // Check if we have a direct localization first
    if (metric == 'calories') {
      return AppLocalizations.getString('average_calories', languageCode);
    }

    // Otherwise, combine average + metric label
    final metricLabel = AppLocalizations.getString(metric, languageCode);
    switch (languageCode) {
      case 'bn':
        return 'গড় $metricLabel';
      case 'hi':
        return 'औसत $metricLabel';
      case 'ar':
      case 'ur':
        return 'متوسط $metricLabel';
      case 'es':
      case 'pt':
        return '$metricLabel Promédio';
      case 'fr':
        return '$metricLabel Moyennes';
      default:
        return 'Average $metricLabel';
    }
  }

  List<Food> _filterFoodsByPeriod(List<Food> foods, String period) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }

    return foods.where((food) => food.analyzedAt.isAfter(startDate)).toList();
  }

  double _calculateTrend(List<Food> foods, String metric) {
    if (foods.length < 2) return 0;

    final sortedFoods = List<Food>.from(foods)
      ..sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));
    final firstHalf = sortedFoods.take(sortedFoods.length ~/ 2).toList();
    final secondHalf = sortedFoods.skip(sortedFoods.length ~/ 2).toList();

    double firstAvg = _getAverage(firstHalf, metric);
    double secondAvg = _getAverage(secondHalf, metric);

    return secondAvg - firstAvg;
  }

  double _getAverage(List<Food> foods, String metric) {
    if (foods.isEmpty) return 0;

    double sum = 0;
    for (final food in foods) {
      sum += _getNutritionValueByMetric(food, metric);
    }

    return sum / foods.length;
  }

  void _showAnalysisInfo(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.85;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: dialogWidth > 450 ? 450 : dialogWidth,
            maxHeight: dialogHeight > 700 ? 700 : dialogHeight,
          ),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced Header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Icon and title row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            IconlyBold.chart,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            AppLocalizations.getString(
                              'analysis_info',
                              languageProvider.currentLanguage,
                            ),
                            style: themeProvider.getFontForCurrentLanguage(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Subtitle
                    Text(
                      AppLocalizations.getString(
                        'analysis_info_description',
                        languageProvider.currentLanguage,
                      ),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Enhanced Content with better organization
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Navigation Pills
                      _buildQuickNavPills(
                        context,
                        themeProvider,
                        languageProvider,
                      ),

                      const SizedBox(height: 24),

                      // Overview Tab Section
                      _buildEnhancedInfoSection(
                        context,
                        themeProvider,
                        languageProvider,
                        'overview_tab',
                        IconlyBold.home,
                        AppColors.primary,
                        [
                          AppLocalizations.getString(
                            'overview_description_1',
                            languageProvider.currentLanguage,
                          ),
                          AppLocalizations.getString(
                            'overview_description_2',
                            languageProvider.currentLanguage,
                          ),
                          AppLocalizations.getString(
                            'overview_description_3',
                            languageProvider.currentLanguage,
                          ),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Trends Tab Section
                      _buildEnhancedInfoSection(
                        context,
                        themeProvider,
                        languageProvider,
                        'trends_tab',
                        IconlyBold.chart,
                        Colors.green,
                        [
                          AppLocalizations.getString(
                            'trends_description_1',
                            languageProvider.currentLanguage,
                          ),
                          AppLocalizations.getString(
                            'trends_description_2',
                            languageProvider.currentLanguage,
                          ),
                          AppLocalizations.getString(
                            'trends_description_3',
                            languageProvider.currentLanguage,
                          ),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Insights Tab Section
                      _buildEnhancedInfoSection(
                        context,
                        themeProvider,
                        languageProvider,
                        'insights_tab',
                        IconlyBold.info_circle,
                        Colors.orange,
                        [
                          AppLocalizations.getString(
                            'insights_description_1',
                            languageProvider.currentLanguage,
                          ),
                          AppLocalizations.getString(
                            'insights_description_2',
                            languageProvider.currentLanguage,
                          ),
                          AppLocalizations.getString(
                            'insights_description_3',
                            languageProvider.currentLanguage,
                          ),
                        ],
                        isDarkMode,
                      ),

                      const SizedBox(height: 20),

                      // Tools Section
                      _buildToolsSection(
                        context,
                        themeProvider,
                        languageProvider,
                        isDarkMode,
                      ),
                    ],
                  ),
                ),
              ),

              // Enhanced Footer with better styling
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.grey800 : AppColors.grey100,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Tip section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            IconlyBold.info_circle,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.getString(
                                'analysis_tip',
                                languageProvider.currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Button row
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                            ),
                            child: Text(
                              AppLocalizations.getString(
                                'got_it',
                                languageProvider.currentLanguage,
                              ),
                              style: themeProvider.getFontForCurrentLanguage(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickNavPills(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    final isDarkMode = themeProvider.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.getString(
            'quick_navigation',
            languageProvider.currentLanguage,
          ),
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildNavPill(
              context,
              AppLocalizations.getString(
                'overview',
                languageProvider.currentLanguage,
              ),
              IconlyBold.home,
              AppColors.primary,
              themeProvider,
            ),
            _buildNavPill(
              context,
              AppLocalizations.getString(
                'trends',
                languageProvider.currentLanguage,
              ),
              IconlyBold.chart,
              Colors.green,
              themeProvider,
            ),
            _buildNavPill(
              context,
              AppLocalizations.getString(
                'insights',
                languageProvider.currentLanguage,
              ),
              IconlyBold.info_circle,
              Colors.orange,
              themeProvider,
            ),
            _buildNavPill(
              context,
              AppLocalizations.getString(
                'tools',
                languageProvider.currentLanguage,
              ),
              IconlyBold.setting,
              Colors.purple,
              themeProvider,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavPill(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    ThemeProvider themeProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoSection(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    String titleKey,
    IconData icon,
    Color color,
    List<String> descriptions,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.grey800 : AppColors.grey50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  AppLocalizations.getString(
                    titleKey,
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
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description points with enhanced styling
          ...descriptions.asMap().entries.map((entry) {
            final description = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 16),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      description,
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 14,
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildToolsSection(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.getString(
            'analysis_tools',
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

        // Period Selector Tool
        _buildToolCard(
          context,
          themeProvider,
          languageProvider,
          'period_selector',
          IconlyBold.calendar,
          Colors.blue,
          [
            AppLocalizations.getString(
              'period_selector_description_1',
              languageProvider.currentLanguage,
            ),
            AppLocalizations.getString(
              'period_selector_description_2',
              languageProvider.currentLanguage,
            ),
          ],
          isDarkMode,
        ),

        const SizedBox(height: 16),

        // Metric Selector Tool
        _buildToolCard(
          context,
          themeProvider,
          languageProvider,
          'metric_selector',
          IconlyBold.activity,
          Colors.purple,
          [
            AppLocalizations.getString(
              'metric_selector_description_1',
              languageProvider.currentLanguage,
            ),
            AppLocalizations.getString(
              'metric_selector_description_2',
              languageProvider.currentLanguage,
            ),
          ],
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildToolCard(
    BuildContext context,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    String titleKey,
    IconData icon,
    Color color,
    List<String> descriptions,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.grey700 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString(
                    titleKey,
                    languageProvider.currentLanguage,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...descriptions.map(
            (description) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      description,
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 13,
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fetch insights from server with language support, fallback to local generation
  Future<List<Map<String, dynamic>>> _fetchInsightsFromServer(
    List<Food> foods,
    LanguageProvider languageProvider,
  ) async {
    try {
      final groqService = GroqService();

      // Convert Food objects to Map for API
      List<Map<String, dynamic>> foodData = foods
          .map(
            (food) => {
              'name': food.name,
              'calories': food.calories,
              'protein': food.protein,
              'carbs': food.carbs,
              'fat': food.fat,
              'healthScore': food.healthScore,
              'analyzedAt': food.analyzedAt.toIso8601String(),
            },
          )
          .toList();

      // Fetch insights from server with current language
      final serverInsights = await groqService.fetchInsights(
        foodData,
        language: languageProvider.currentLanguage,
      );

      // Convert icon strings to Icons
      return serverInsights.map((insight) {
        Map<String, dynamic> convertedInsight = Map.from(insight);
        convertedInsight['icon'] = _getIconFromString(
          insight['icon'] ?? 'info',
        );
        convertedInsight['color'] = _getColorFromString(
          insight['color'] ?? 'blue',
        );
        return convertedInsight;
      }).toList();
    } catch (e) {
      // Fallback to local insights if server fails
      return _generateLocalInsights(foods, languageProvider);
    }
  }

  // Convert icon string to IconData
  IconData _getIconFromString(String iconString) {
    switch (iconString.toLowerCase()) {
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'thumb_up':
        return Icons.thumb_up;
      case 'warning':
        return Icons.warning;
      case 'diversity_3':
        return Icons.diversity_3;
      case 'repeat':
        return Icons.repeat;
      case 'local_fire_department':
        return Icons.local_fire_department;
      default:
        return Icons.info;
    }
  }

  // Convert color string to Color
  Color _getColorFromString(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  // Generate local insights as fallback
  List<Map<String, dynamic>> _generateLocalInsights(
    List<Food> foods,
    LanguageProvider languageProvider,
  ) {
    if (foods.isEmpty) return [];

    final insights = <Map<String, dynamic>>[];

    // Health score insight
    final avgHealthScore =
        foods.fold(0.0, (sum, food) => sum + food.healthScore) / foods.length;
    if (avgHealthScore >= 8) {
      insights.add({
        'icon': Icons.health_and_safety,
        'color': Colors.green,
        'title': AppLocalizations.getString(
          'excellent_health_choices',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'excellent_health_description',
          languageProvider.currentLanguage,
        ).replaceAll('{score}', avgHealthScore.toStringAsFixed(1)),
      });
    } else if (avgHealthScore >= 6) {
      insights.add({
        'icon': Icons.thumb_up,
        'color': Colors.orange,
        'title': AppLocalizations.getString(
          'good_health_choices',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'good_health_description',
          languageProvider.currentLanguage,
        ).replaceAll('{score}', avgHealthScore.toStringAsFixed(1)),
      });
    } else {
      insights.add({
        'icon': Icons.warning,
        'color': Colors.red,
        'title': AppLocalizations.getString(
          'health_improvement_needed',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'health_improvement_description',
          languageProvider.currentLanguage,
        ).replaceAll('{score}', avgHealthScore.toStringAsFixed(1)),
      });
    }

    // Variety insight
    final uniqueFoods = foods.map((f) => f.name.toLowerCase()).toSet().length;
    if (uniqueFoods >= foods.length * 0.8) {
      insights.add({
        'icon': Icons.diversity_3,
        'color': Colors.blue,
        'title': AppLocalizations.getString(
          'great_food_variety',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'great_variety_description',
          languageProvider.currentLanguage,
        ),
      });
    } else {
      insights.add({
        'icon': Icons.repeat,
        'color': Colors.orange,
        'title': AppLocalizations.getString(
          'limited_food_variety',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'limited_variety_description',
          languageProvider.currentLanguage,
        ),
      });
    }

    // Calorie balance insight
    final totalCalories = foods.fold(0.0, (sum, food) => sum + food.calories);
    if (totalCalories > 2000) {
      insights.add({
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'title': AppLocalizations.getString(
          'high_calorie_intake',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'high_calorie_description',
          languageProvider.currentLanguage,
        ).replaceAll('{calories}', totalCalories.toStringAsFixed(0)),
      });
    } else if (totalCalories < 1200) {
      insights.add({
        'icon': Icons.local_fire_department,
        'color': Colors.red,
        'title': AppLocalizations.getString(
          'low_calorie_intake',
          languageProvider.currentLanguage,
        ),
        'description': AppLocalizations.getString(
          'low_calorie_description',
          languageProvider.currentLanguage,
        ).replaceAll('{calories}', totalCalories.toStringAsFixed(0)),
      });
    }

    return insights;
  }
}
