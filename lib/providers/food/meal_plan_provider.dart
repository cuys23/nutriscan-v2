import 'package:flutter/foundation.dart';

import 'package:nutriscan/models/meal_plan.dart';
import 'package:nutriscan/services/ai/groq_service.dart';
import 'package:nutriscan/services/database/database_helper.dart';

class UserNutritionInsight {
  final String suggestedDietStyle;
  final String balanceContextForPrompt;
  final bool hasData;

  const UserNutritionInsight({
    required this.suggestedDietStyle,
    required this.balanceContextForPrompt,
    required this.hasData,
  });
}

class MealPlanProvider extends ChangeNotifier {
  MealPlanProvider({GroqService? groqService, DatabaseHelper? databaseHelper})
    : _groqService = groqService ?? GroqService(),
      _databaseHelper = databaseHelper ?? DatabaseHelper();

  final GroqService _groqService;
  final DatabaseHelper _databaseHelper;

  MealPlan? _currentPlan;
  bool _isLoading = false;
  String? _errorMessage;

  double _calorieTarget = 2000;
  String _dietStyle = 'balanced';
  int _mealsPerDay = 4;
  final List<String> _restrictions = [];

  UserNutritionInsight? _lastInsight;

  MealPlan? get currentPlan => _currentPlan;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserNutritionInsight? get lastInsight => _lastInsight;

  double get calorieTarget => _calorieTarget;
  String get dietStyle => _dietStyle;
  int get mealsPerDay => _mealsPerDay;
  List<String> get restrictions => List.unmodifiable(_restrictions);

  void setCalorieTarget(double value) {
    _calorieTarget = value.clamp(1200, 3500);
    notifyListeners();
  }

  void setDietStyle(String style) {
    if (_dietStyle == style) return;
    _dietStyle = style;
    notifyListeners();
  }

  void setMealsPerDay(int count) {
    if (count < 3 || count > 6) return;
    if (_mealsPerDay == count) return;
    _mealsPerDay = count;
    notifyListeners();
  }

  void toggleRestriction(String restriction) {
    if (_restrictions.contains(restriction)) {
      _restrictions.remove(restriction);
    } else {
      _restrictions.add(restriction);
    }
    notifyListeners();
  }

  void setRestrictionsFromText(String text) {
    _restrictions
      ..clear()
      ..addAll(
        text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet(),
      );
    notifyListeners();
  }

  void clearPlan() {
    _currentPlan = null;
    _errorMessage = null;
    notifyListeners();
  }

  static const int _analysisDays = 14;
  static const double _minProteinPerDay = 45;
  static const double _minFiberPerDay = 18;
  static const double _highFatPerDay = 75;

  Future<UserNutritionInsight> analyzeUserNutrition() async {
    try {
      final summary = await _databaseHelper.getNutritionSummaryForLastDays(
        _analysisDays,
      );
      final totalMeals = summary['total_meals'] as int? ?? 0;
      if (totalMeals < 3) {
        _lastInsight = const UserNutritionInsight(
          suggestedDietStyle: 'balanced',
          balanceContextForPrompt: '',
          hasData: false,
        );
        notifyListeners();
        return _lastInsight!;
      }

      final avgProtein =
          (summary['avg_protein_per_day'] as num?)?.toDouble() ?? 0.0;
      final avgFat = (summary['avg_fat_per_day'] as num?)?.toDouble() ?? 0.0;
      final avgFiber =
          (summary['avg_fiber_per_day'] as num?)?.toDouble() ?? 0.0;
      final avgCalories =
          (summary['avg_calories_per_day'] as num?)?.toDouble() ?? 0.0;

      String suggested = 'balanced';
      final List<String> gaps = [];

      if (avgProtein < _minProteinPerDay) {
        suggested = 'high_protein';
        gaps.add('low protein (avg ${avgProtein.toStringAsFixed(0)}g/day)');
      }
      if (avgFiber < _minFiberPerDay && suggested == 'balanced') {
        suggested = 'vegetarian';
        gaps.add('low fiber (avg ${avgFiber.toStringAsFixed(0)}g/day)');
      }
      if (avgFat > _highFatPerDay && suggested == 'balanced') {
        suggested = 'low_carb';
        gaps.add('high fat intake (avg ${avgFat.toStringAsFixed(0)}g/day)');
      }

      String contextForPrompt = '';
      if (gaps.isNotEmpty) {
        contextForPrompt =
            "User's recent diet (last $_analysisDays days, avg ${avgCalories.toStringAsFixed(0)} kcal/day) "
            "shows: ${gaps.join('; ')}. Create a plan that helps balance their diet and address these needs.";
      } else {
        contextForPrompt =
            "User's recent diet (last $_analysisDays days) is relatively balanced. "
            "Create a varied plan that maintains balance.";
      }

      _lastInsight = UserNutritionInsight(
        suggestedDietStyle: suggested,
        balanceContextForPrompt: contextForPrompt,
        hasData: true,
      );
      notifyListeners();
      return _lastInsight!;
    } catch (e) {
      _lastInsight = const UserNutritionInsight(
        suggestedDietStyle: 'balanced',
        balanceContextForPrompt: '',
        hasData: false,
      );
      notifyListeners();
      return _lastInsight!;
    }
  }

  void applySuggestedDietStyle() {
    if (_lastInsight != null && _lastInsight!.hasData) {
      _dietStyle = _lastInsight!.suggestedDietStyle;
      notifyListeners();
    }
  }

  Future<void> generateMealPlan({required String languageCode}) async {
    _setLoading(true);
    try {
      String? userContext;
      if (_lastInsight != null &&
          _lastInsight!.hasData &&
          _lastInsight!.balanceContextForPrompt.isNotEmpty) {
        userContext = _lastInsight!.balanceContextForPrompt;
      }

      final result = await _groqService.generateMealPlan(
        targetCalories: _calorieTarget.round(),
        dietStyle: _dietStyle,
        mealsPerDay: _mealsPerDay,
        restrictions: _restrictions,
        language: languageCode,
        userNutritionContext: userContext,
      );

      _currentPlan = result;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      _currentPlan = null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
