import 'package:flutter/foundation.dart';

@immutable
class MealPlan {
  final String planTitle;
  final String goalSummary;
  final double targetCalories;
  final MealPlanNutritionBreakdown nutrition;
  final List<MealPlanMeal> meals;
  final List<String> hydrationTips;
  final List<String> lifestyleTips;
  final List<String> groceryList;

  const MealPlan({
    required this.planTitle,
    required this.goalSummary,
    required this.targetCalories,
    required this.nutrition,
    required this.meals,
    required this.hydrationTips,
    required this.lifestyleTips,
    required this.groceryList,
  });

  factory MealPlan.fromMap(Map<String, dynamic> map) {
    final nutritionMap = map['nutrition_overview'] ?? map['nutrition'];
    return MealPlan(
      planTitle: (map['plan_title'] ?? map['planTitle'] ?? 'Daily Meal Plan')
          .toString()
          .trim(),
      goalSummary: (map['goal_summary'] ?? map['summary'] ?? '')
          .toString()
          .trim(),
      targetCalories: _parseDouble(
        map['target_calories'] ?? map['targetCalories'],
      ),
      nutrition: MealPlanNutritionBreakdown.fromMap(
        nutritionMap is Map<String, dynamic>
            ? nutritionMap
            : <String, dynamic>{},
      ),
      meals: _parseMealsList(map['meals']),
      hydrationTips: _parseStringList(
        map['hydration_reminders'] ?? map['hydration_tips'],
      ),
      lifestyleTips: _parseStringList(
        map['lifestyle_tips'] ?? map['wellness_tips'],
      ),
      groceryList: _parseStringList(map['grocery_list']),
    );
  }

  static List<MealPlanMeal> _parseMealsList(dynamic value) {
    if (value is! List || value.isEmpty) return [];
    final List<MealPlanMeal> out = [];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        try {
          out.add(MealPlanMeal.fromMap(item));
        } catch (e) {
          debugPrint('Error parsing meal in meal plan: $e');
        }
      }
    }
    return out;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) return [];
    return value
        .map((item) => item.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'plan_title': planTitle,
      'goal_summary': goalSummary,
      'target_calories': targetCalories,
      'nutrition_overview': nutrition.toMap(),
      'meals': meals.map((meal) => meal.toMap()).toList(),
      'hydration_reminders': hydrationTips,
      'lifestyle_tips': lifestyleTips,
      'grocery_list': groceryList,
    };
  }
}

@immutable
class MealPlanNutritionBreakdown {
  final double totalCalories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;

  const MealPlanNutritionBreakdown({
    required this.totalCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
  });

  factory MealPlanNutritionBreakdown.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      return const MealPlanNutritionBreakdown(
        totalCalories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        fiber: 0,
        sugar: 0,
      );
    }
    return MealPlanNutritionBreakdown(
      totalCalories: _parseDouble(
        map['total_calories'] ?? map['calories'] ?? map['totalCalories'],
      ),
      protein: _parseDouble(map['protein']),
      carbs: _parseDouble(map['carbs'] ?? map['carbohydrates']),
      fat: _parseDouble(map['fat']),
      fiber: _parseDouble(map['fiber']),
      sugar: _parseDouble(map['sugar']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_calories': totalCalories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
    };
  }
}

@immutable
class MealPlanMeal {
  final String type;
  final String title;
  final String description;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> ingredients;
  final List<String> instructions;

  const MealPlanMeal({
    required this.type,
    required this.title,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    required this.instructions,
  });

  factory MealPlanMeal.fromMap(Map<String, dynamic> map) {
    return MealPlanMeal(
      type: (map['type'] ?? map['meal_type'] ?? 'meal').toString().trim(),
      title: (map['title'] ?? map['name'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      calories: _parseDouble(map['calories']),
      protein: _parseDouble(map['protein']),
      carbs: _parseDouble(map['carbs']),
      fat: _parseDouble(map['fat']),
      ingredients: MealPlan._parseStringList(map['ingredients']),
      instructions: MealPlan._parseStringList(
        map['instructions'] ?? map['preparation'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'ingredients': ingredients,
      'instructions': instructions,
    };
  }
}

double _parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value.toString());
  return parsed ?? 0;
}
