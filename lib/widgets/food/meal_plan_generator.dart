import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/models/meal_plan.dart';
import 'package:nutriscan/providers/food/meal_plan_provider.dart';
import 'package:nutriscan/providers/theme/language_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class MealPlanGenerator extends StatefulWidget {
  const MealPlanGenerator({
    super.key,
    this.showPreferences = true,
    this.showResults = true,
    this.onPlanGenerated,
  });

  final bool showPreferences;
  final bool showResults;
  final VoidCallback? onPlanGenerated;

  @override
  State<MealPlanGenerator> createState() => _MealPlanGeneratorState();
}

class _MealPlanGeneratorState extends State<MealPlanGenerator>
    with TickerProviderStateMixin {
  final TextEditingController _restrictionController = TextEditingController();
  bool _hasSyncedRestrictions = false;
  bool _hasLoadedInsight = false;
  late AnimationController _loadingController;
  late Animation<double> _loadingRotation;

  final List<Map<String, String>> _dietOptions = const [
    {'value': 'balanced', 'icon': '🥦'},
    {'value': 'high_protein', 'icon': '💪'},
    {'value': 'low_carb', 'icon': '🥗'},
    {'value': 'keto', 'icon': '🥑'},
    {'value': 'vegetarian', 'icon': '🌿'},
    {'value': 'vegan', 'icon': '🌱'},
    {'value': 'mediterranean', 'icon': '🌊'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize loading animation controller
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _loadingRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _restrictionController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasSyncedRestrictions) {
      final provider = context.read<MealPlanProvider>();
      _restrictionController.text = provider.restrictions.join(', ');
      _hasSyncedRestrictions = true;
    }
    if (widget.showPreferences && !_hasLoadedInsight) {
      _hasLoadedInsight = true;
      final provider = context.read<MealPlanProvider>();
      provider.analyzeUserNutrition().then((_) {
        if (mounted) provider.applySuggestedDietStyle();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<MealPlanProvider, ThemeProvider, LanguageProvider>(
      builder: (context, mealPlanProvider, themeProvider, languageProvider, _) {
        final isDarkMode = themeProvider.isDarkMode;
        final currentLanguage = languageProvider.currentLanguage;

        // If loading and showing results only, center the loading
        if (widget.showResults &&
            !widget.showPreferences &&
            mealPlanProvider.isLoading) {
          return Center(
            child: _buildLoadingState(
              themeProvider,
              currentLanguage,
              isDarkMode,
            ),
          );
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildContent(
              mealPlanProvider: mealPlanProvider,
              themeProvider: themeProvider,
              language: currentLanguage,
              isDarkMode: isDarkMode,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildContent({
    required MealPlanProvider mealPlanProvider,
    required ThemeProvider themeProvider,
    required String language,
    required bool isDarkMode,
  }) {
    final List<Widget> content = [];

    if (widget.showPreferences) {
      content.addAll([
        _buildHeaderCard(themeProvider, language, isDarkMode),
        if (mealPlanProvider.lastInsight?.hasData == true) ...[
          const SizedBox(height: 12),
          _buildSuggestionBanner(
            mealPlanProvider,
            themeProvider,
            language,
            isDarkMode,
          ),
        ],
        const SizedBox(height: 20),
        _buildCalorieSelector(
          mealPlanProvider,
          themeProvider,
          language,
          isDarkMode,
        ),
        const SizedBox(height: 20),
        _buildDietStyleSelector(
          mealPlanProvider,
          themeProvider,
          language,
          isDarkMode,
        ),
        const SizedBox(height: 20),
        _buildMealsPerDaySelector(
          mealPlanProvider,
          themeProvider,
          language,
          isDarkMode,
        ),
        const SizedBox(height: 20),
        _buildRestrictionInput(
          mealPlanProvider,
          themeProvider,
          language,
          isDarkMode,
        ),
        const SizedBox(height: 24),
        _buildActionButtons(
          mealPlanProvider,
          themeProvider,
          language,
          isDarkMode,
        ),
      ]);
    }

    if (widget.showResults) {
      if (content.isNotEmpty) {
        content.add(const SizedBox(height: 24));
      }

      if (mealPlanProvider.isLoading) {
        // Start animation when loading
        if (!_loadingController.isAnimating) {
          _loadingController.repeat();
        }
        // Center the loading state
        content.add(
          SizedBox(
            width: double.infinity,
            child: Center(
              child: _buildLoadingState(themeProvider, language, isDarkMode),
            ),
          ),
        );
      } else {
        // Stop animation when not loading
        if (_loadingController.isAnimating) {
          _loadingController.stop();
        }
        if (mealPlanProvider.errorMessage != null) {
          content.add(
            _buildErrorState(
              themeProvider,
              language,
              mealPlanProvider.errorMessage!,
              isDarkMode,
            ),
          );
        } else if (mealPlanProvider.currentPlan != null) {
          content.add(
            _buildPlanResult(
              mealPlanProvider.currentPlan!,
              themeProvider,
              language,
              isDarkMode,
            ),
          );
        } else {
          content.add(_buildEmptyState(themeProvider, language, isDarkMode));
        }
      }
    }

    if (content.isEmpty) {
      content.add(const SizedBox.shrink());
    }

    return content;
  }

  Widget _buildHeaderCard(
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  IconlyBold.discovery,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  AppLocalizations.getString(
                    'meal_plan_generator_title',
                    language,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.getString(
              'meal_plan_generator_subtitle',
              language,
            ),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  IconlyBold.shield_done,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.getString(
                      'meal_plan_generator_prompt',
                      language,
                    ),
                    style: themeProvider.getFontForCurrentLanguage(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionBanner(
    MealPlanProvider mealPlanProvider,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    final insight = mealPlanProvider.lastInsight;
    if (insight == null || !insight.hasData) return const SizedBox.shrink();
    final dietLabelKey = 'diet_${insight.suggestedDietStyle}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(IconlyBold.tick_square, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.getString(
                    'meal_plan_suggested_for_you',
                    language,
                  ),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.getString(dietLabelKey, language),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieSelector(
    MealPlanProvider mealPlanProvider,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconlyBold.chart,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString('target_calories_label', language),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${mealPlanProvider.calorieTarget.round()} ${AppLocalizations.getString('cal', language)}',
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              min: 1200,
              max: 3500,
              divisions: 23,
              activeColor: AppColors.primary,
              inactiveColor: isDarkMode ? AppColors.grey700 : AppColors.grey300,
              value: mealPlanProvider.calorieTarget,
              onChanged: (value) => mealPlanProvider.setCalorieTarget(value),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.getString('target_calories_helper', language),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 12,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietStyleSelector(
    MealPlanProvider mealPlanProvider,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconlyBold.category,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString('diet_style_label', language),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _dietOptions.map((option) {
              final isSelected = mealPlanProvider.dietStyle == option['value'];
              final labelKey = 'diet_${option['value']}';
              return GestureDetector(
                onTap: () => mealPlanProvider.setDietStyle(option['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDarkMode ? AppColors.grey800 : AppColors.grey100),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDarkMode
                                ? AppColors.grey700
                                : AppColors.grey300),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option['icon']!,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.getString(labelKey, language),
                        style: themeProvider.getFontForCurrentLanguage(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDarkMode
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsPerDaySelector(
    MealPlanProvider mealPlanProvider,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    final options = [3, 4, 5, 6];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconlyBold.time_circle,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString('meals_per_day_label', language),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: options.map((count) {
              final isSelected = mealPlanProvider.mealsPerDay == count;
              return Expanded(
                child: GestureDetector(
                  onTap: () => mealPlanProvider.setMealsPerDay(count),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDarkMode
                                ? AppColors.grey800
                                : AppColors.grey100),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDarkMode
                                  ? AppColors.grey700
                                  : AppColors.grey300),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$count×',
                          style: themeProvider.getFontForCurrentLanguage(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isDarkMode
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.getString('meals', language),
                          style: themeProvider.getFontForCurrentLanguage(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : (isDarkMode
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictionInput(
    MealPlanProvider mealPlanProvider,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconlyBold.danger,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString('avoid_foods_label', language),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _restrictionController,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            maxLines: 2,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDarkMode ? AppColors.grey800 : AppColors.grey100,
              hintText: AppLocalizations.getString(
                'avoid_foods_hint',
                language,
              ),
              hintStyle: themeProvider.getFontForCurrentLanguage(
                fontSize: 14,
                color: isDarkMode
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDarkMode ? AppColors.grey700 : AppColors.grey300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDarkMode ? AppColors.grey700 : AppColors.grey300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: mealPlanProvider.setRestrictionsFromText,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.getString('avoid_foods_helper', language),
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 12,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    MealPlanProvider mealPlanProvider,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    if (!widget.showPreferences) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: mealPlanProvider.isLoading
            ? null
            : () async {
                await mealPlanProvider.generateMealPlan(languageCode: language);
                if (!mounted) return;
                final hasPlan = mealPlanProvider.currentPlan != null;
                final noError = mealPlanProvider.errorMessage == null;
                if (widget.onPlanGenerated != null && noError && hasPlan) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    widget.onPlanGenerated!();
                  });
                } else if (!noError || !hasPlan) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${AppLocalizations.getString('meal_plan_error_title', language)}: ${mealPlanProvider.errorMessage ?? "Unknown error"}',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mealPlanProvider.isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.getString(
                  'meal_plan_generating_button',
                  language,
                ),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ] else ...[
              const Icon(Icons.auto_awesome, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.getString('generate_meal_plan', language),
                style: themeProvider.getFontForCurrentLanguage(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rotating Loading Circle
        AnimatedBuilder(
          animation: _loadingController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _loadingRotation.value * 2 * 3.14159,
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
          AppLocalizations.getString('meal_plan_generating', language),
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
          AppLocalizations.getString('meal_plan_generating_subtitle', language),
          textAlign: TextAlign.center,
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 14,
            color: isDarkMode
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    ThemeProvider themeProvider,
    String language,
    String errorMessage,
    bool isDarkMode,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(IconlyBold.danger, color: Colors.redAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString('meal_plan_error_title', language),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
            errorMessage,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 13,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanResult(
    MealPlan mealPlan,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlanSummaryCard(mealPlan, themeProvider, language, isDarkMode),
        const SizedBox(height: 20),
        ...mealPlan.meals.map(
          (meal) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _MealCard(
              meal: meal,
              themeProvider: themeProvider,
              language: language,
              isDarkMode: isDarkMode,
            ),
          ),
        ),
        if (mealPlan.hydrationTips.isNotEmpty ||
            mealPlan.lifestyleTips.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTipsCard(themeProvider, language, isDarkMode, mealPlan),
              const SizedBox(height: 16),
            ],
          ),
        if (mealPlan.groceryList.isNotEmpty)
          _buildGroceryCard(
            themeProvider,
            language,
            isDarkMode,
            mealPlan.groceryList,
          ),
      ],
    );
  }

  Widget _buildPlanSummaryCard(
    MealPlan mealPlan,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    final nutrient = mealPlan.nutrition;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealPlan.planTitle,
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mealPlan.goalSummary,
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 13,
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryStat(
                themeProvider,
                language,
                isDarkMode,
                IconlyBold.activity,
                AppLocalizations.getString('total_calories', language),
                '${nutrient.totalCalories.toStringAsFixed(0)} ${AppLocalizations.getString('cal', language)}',
              ),
              _buildSummaryStat(
                themeProvider,
                language,
                isDarkMode,
                IconlyBold.paper,
                AppLocalizations.getString('protein', language),
                '${nutrient.protein.toStringAsFixed(0)} g',
              ),
              _buildSummaryStat(
                themeProvider,
                language,
                isDarkMode,
                IconlyBold.chart,
                AppLocalizations.getString('carbs', language),
                '${nutrient.carbs.toStringAsFixed(0)} g',
              ),
              _buildSummaryStat(
                themeProvider,
                language,
                isDarkMode,
                IconlyBold.time_circle,
                AppLocalizations.getString('fat', language),
                '${nutrient.fat.toStringAsFixed(0)} g',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDarkMode
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: themeProvider.getFontForCurrentLanguage(
            fontSize: 12,
            color: isDarkMode
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard(
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
    MealPlan mealPlan,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconlyBold.info_circle,
                  color: Colors.blueAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString('hydration_and_tips', language),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (mealPlan.hydrationTips.isNotEmpty)
            _buildBulletedList(
              mealPlan.hydrationTips,
              themeProvider,
              language,
              isDarkMode,
            ),
          if (mealPlan.lifestyleTips.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBulletedList(
              mealPlan.lifestyleTips,
              themeProvider,
              language,
              isDarkMode,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroceryCard(
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
    List<String> groceryList,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  IconlyBold.bag_2,
                  color: Colors.green[600],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.getString('grocery_list_label', language),
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groceryList
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.grey800 : AppColors.grey100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      item,
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 13,
                        color: isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletedList(
    List<String> items,
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 6, right: 10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  item,
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
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(
    ThemeProvider themeProvider,
    String language,
    bool isDarkMode,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            IconlyLight.calendar,
            size: 56,
            color: isDarkMode ? AppColors.grey600 : AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.getString('meal_plan_empty_title', language),
            textAlign: TextAlign.center,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.getString('meal_plan_empty_subtitle', language),
            textAlign: TextAlign.center,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 13,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealPlanMeal meal;
  final ThemeProvider themeProvider;
  final String language;
  final bool isDarkMode;

  const _MealCard({
    required this.meal,
    required this.themeProvider,
    required this.language,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? AppColors.grey700 : AppColors.grey200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getMealIcon(meal.type),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getMealTitle(meal.type, language),
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meal.title,
                      style: themeProvider.getFontForCurrentLanguage(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${meal.calories.toStringAsFixed(0)} ${AppLocalizations.getString('cal', language)}',
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            meal.description,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 13,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroChip(
                themeProvider,
                isDarkMode,
                AppLocalizations.getString('protein', language),
                '${meal.protein.toStringAsFixed(0)} g',
                Icons.fitness_center,
              ),
              _buildMacroChip(
                themeProvider,
                isDarkMode,
                AppLocalizations.getString('carbs', language),
                '${meal.carbs.toStringAsFixed(0)} g',
                Icons.local_fire_department,
              ),
              _buildMacroChip(
                themeProvider,
                isDarkMode,
                AppLocalizations.getString('fat', language),
                '${meal.fat.toStringAsFixed(0)} g',
                Icons.oil_barrel,
              ),
            ],
          ),
          if (meal.ingredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              AppLocalizations.getString('ingredients_label', language),
              style: themeProvider.getFontForCurrentLanguage(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            _buildBulletList(meal.ingredients, themeProvider, isDarkMode),
          ],
          if (meal.instructions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              AppLocalizations.getString('instructions_label', language),
              style: themeProvider.getFontForCurrentLanguage(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            _buildBulletList(meal.instructions, themeProvider, isDarkMode),
          ],
        ],
      ),
    );
  }

  IconData _getMealIcon(String type) {
    final normalized = type.toLowerCase().trim();

    if (normalized.contains('snack') ||
        normalized.contains('tea') ||
        normalized.contains('brunch') ||
        normalized.contains('mini meal')) {
      return Icons.cookie;
    }

    if (normalized.contains('breakfast') ||
        normalized.contains('morning meal') ||
        normalized.startsWith('morning ')) {
      return Icons.free_breakfast;
    }

    if (normalized.contains('lunch') ||
        normalized.contains('noon') ||
        normalized.contains('midday')) {
      return Icons.lunch_dining;
    }

    if (normalized.contains('dinner') ||
        normalized.contains('supper') ||
        normalized.contains('evening meal') ||
        normalized.contains('night meal')) {
      return Icons.restaurant;
    }

    return Icons.restaurant_menu;
  }

  String _getMealTitle(String type, String language) {
    final normalized = type.toLowerCase().trim();

    if (normalized.contains('snack') ||
        normalized.contains('tea') ||
        normalized.contains('brunch') ||
        normalized.contains('mini meal')) {
      return AppLocalizations.getString('meal_type_snack', language);
    }

    if (normalized.contains('breakfast') ||
        normalized.contains('morning meal') ||
        normalized.startsWith('morning ')) {
      return AppLocalizations.getString('meal_type_breakfast', language);
    }

    if (normalized.contains('lunch') ||
        normalized.contains('noon') ||
        normalized.contains('midday')) {
      return AppLocalizations.getString('meal_type_lunch', language);
    }

    if (normalized.contains('dinner') ||
        normalized.contains('supper') ||
        normalized.contains('evening meal') ||
        normalized.contains('night meal')) {
      return AppLocalizations.getString('meal_type_dinner', language);
    }

    return AppLocalizations.getString(
      'meal_type_generic',
      language,
    ).replaceAll('{meal}', type);
  }

  Widget _buildMacroChip(
    ThemeProvider themeProvider,
    bool isDarkMode,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.grey800 : AppColors.grey100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 12,
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: themeProvider.getFontForCurrentLanguage(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDarkMode
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletList(
    List<String> items,
    ThemeProvider themeProvider,
    bool isDarkMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 7, right: 10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: themeProvider.getFontForCurrentLanguage(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
