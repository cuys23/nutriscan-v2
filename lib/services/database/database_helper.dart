import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/services/auth/cloud_backup_service.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final CloudBackupService _cloudBackupService = CloudBackupService();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'calories.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE foods(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        fiber REAL NOT NULL,
        sugar REAL NOT NULL,
        sodium REAL NOT NULL,
        health_score INTEGER NOT NULL,
        health_benefits TEXT,
        health_warnings TEXT,
        serving_size TEXT,
        image_path TEXT,
        analyzed_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertFood(Food food, {bool isPremiumUser = false}) async {
    final db = await database;
    final result = await db.insert('foods', {
      'id': food.id,
      'name': food.name,
      'description': food.description,
      'calories': food.calories,
      'protein': food.protein,
      'carbs': food.carbs,
      'fat': food.fat,
      'fiber': food.fiber,
      'sugar': food.sugar,
      'sodium': food.sodium,
      'health_score': food.healthScore,
      'health_benefits': food.healthBenefits.join('|'),
      'health_warnings': food.healthWarnings.join('|'),
      'serving_size': food.servingSize,
      'image_path': food.imagePath,
      'analyzed_at': food.analyzedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Auto backup to cloud ONLY for premium users
    if (isPremiumUser && await _cloudBackupService.isAutoBackupEnabled()) {
      final allFoods = await getAllFoods();
      _cloudBackupService.autoBackup(allFoods, isPremiumUser: isPremiumUser);
    }

    return result;
  }

  Future<List<Food>> getAllFoods() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      orderBy: 'analyzed_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Food(
        id: maps[i]['id'],
        name: maps[i]['name'],
        description: maps[i]['description'] ?? '',
        calories: maps[i]['calories'],
        protein: maps[i]['protein'],
        carbs: maps[i]['carbs'],
        fat: maps[i]['fat'],
        fiber: maps[i]['fiber'],
        sugar: maps[i]['sugar'],
        sodium: maps[i]['sodium'],
        healthScore: maps[i]['health_score'],
        healthBenefits:
            (maps[i]['health_benefits'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        healthWarnings:
            (maps[i]['health_warnings'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        servingSize: maps[i]['serving_size'] ?? '1 serving',
        imagePath: maps[i]['image_path'] ?? '',
        analyzedAt: DateTime.parse(maps[i]['analyzed_at']),
      );
    });
  }

  Future<List<Food>> getFoodsForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'analyzed_at >= ? AND analyzed_at < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'analyzed_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Food(
        id: maps[i]['id'],
        name: maps[i]['name'],
        description: maps[i]['description'] ?? '',
        calories: maps[i]['calories'],
        protein: maps[i]['protein'],
        carbs: maps[i]['carbs'],
        fat: maps[i]['fat'],
        fiber: maps[i]['fiber'],
        sugar: maps[i]['sugar'],
        sodium: maps[i]['sodium'],
        healthScore: maps[i]['health_score'],
        healthBenefits:
            (maps[i]['health_benefits'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        healthWarnings:
            (maps[i]['health_warnings'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        servingSize: maps[i]['serving_size'] ?? '1 serving',
        imagePath: maps[i]['image_path'] ?? '',
        analyzedAt: DateTime.parse(maps[i]['analyzed_at']),
      );
    });
  }

  Future<int> deleteFood(String id) async {
    final db = await database;
    return await db.delete('foods', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllFoods() async {
    final db = await database;
    return await db.delete('foods');
  }

  List<String> _getDateRange(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return [startOfDay.toIso8601String(), endOfDay.toIso8601String()];
  }

  Future<double> _getSumForDate(String column, DateTime date) async {
    final db = await database;
    final dateRange = _getDateRange(date);
    final result = await db.rawQuery('''
      SELECT SUM($column) as total_$column
      FROM foods
      WHERE analyzed_at >= ? AND analyzed_at < ?
    ''', dateRange);
    return (result.first['total_$column'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalCaloriesForDate(DateTime date) async {
    return _getSumForDate('calories', date);
  }

  Future<double> getTotalProteinForDate(DateTime date) async {
    return _getSumForDate('protein', date);
  }

  Future<double> getTotalCarbsForDate(DateTime date) async {
    return _getSumForDate('carbs', date);
  }

  Future<double> getTotalFatForDate(DateTime date) async {
    return _getSumForDate('fat', date);
  }

  Future<double> getTotalFiberForDate(DateTime date) async {
    return _getSumForDate('fiber', date);
  }

  Future<double> getTotalSugarForDate(DateTime date) async {
    return _getSumForDate('sugar', date);
  }

  Future<double> getAverageHealthScoreForDate(DateTime date) async {
    final db = await database;
    final dateRange = _getDateRange(date);
    final result = await db.rawQuery('''
      SELECT AVG(health_score) as avg_health_score
      FROM foods
      WHERE analyzed_at >= ? AND analyzed_at < ?
    ''', dateRange);
    return (result.first['avg_health_score'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Food>> getFoodsForLastWeek() async {
    final db = await database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 7));

    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'analyzed_at >= ?',
      whereArgs: [startOfWeek.toIso8601String()],
      orderBy: 'analyzed_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Food(
        id: maps[i]['id'],
        name: maps[i]['name'],
        description: maps[i]['description'] ?? '',
        calories: maps[i]['calories'],
        protein: maps[i]['protein'],
        carbs: maps[i]['carbs'],
        fat: maps[i]['fat'],
        fiber: maps[i]['fiber'],
        sugar: maps[i]['sugar'],
        sodium: maps[i]['sodium'],
        healthScore: maps[i]['health_score'],
        healthBenefits:
            (maps[i]['health_benefits'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        healthWarnings:
            (maps[i]['health_warnings'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        servingSize: maps[i]['serving_size'] ?? '1 serving',
        imagePath: maps[i]['image_path'] ?? '',
        analyzedAt: DateTime.parse(maps[i]['analyzed_at']),
      );
    });
  }

  Future<List<Food>> getFoodsForMonth(int month, int year) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(
      month == 12 ? year + 1 : year,
      month == 12 ? 1 : month + 1,
      1,
    );

    final List<Map<String, dynamic>> maps = await db.query(
      'foods',
      where: 'analyzed_at >= ? AND analyzed_at < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'analyzed_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Food(
        id: maps[i]['id'],
        name: maps[i]['name'],
        description: maps[i]['description'] ?? '',
        calories: maps[i]['calories'],
        protein: maps[i]['protein'],
        carbs: maps[i]['carbs'],
        fat: maps[i]['fat'],
        fiber: maps[i]['fiber'],
        sugar: maps[i]['sugar'],
        sodium: maps[i]['sodium'],
        healthScore: maps[i]['health_score'],
        healthBenefits:
            (maps[i]['health_benefits'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        healthWarnings:
            (maps[i]['health_warnings'] as String?)
                ?.split('|')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        servingSize: maps[i]['serving_size'] ?? '1 serving',
        imagePath: maps[i]['image_path'] ?? '',
        analyzedAt: DateTime.parse(maps[i]['analyzed_at']),
      );
    });
  }

  /// Returns average daily nutrition (protein, carbs, fat, fiber, calories) and
  /// total meal count for the last [days] days. Used to suggest diet style for meal plan.
  Future<Map<String, dynamic>> getNutritionSummaryForLastDays(int days) async {
    final db = await database;
    final start = DateTime.now().subtract(Duration(days: days));

    final result = await db.rawQuery(
      '''
      SELECT
        COUNT(*) as total_meals,
        SUM(calories) as total_calories,
        SUM(protein) as total_protein,
        SUM(carbs) as total_carbs,
        SUM(fat) as total_fat,
        SUM(fiber) as total_fiber
      FROM foods
      WHERE analyzed_at >= ?
    ''',
      [start.toIso8601String()],
    );

    final row = result.isNotEmpty ? result.first : null;
    final totalMeals = (row?['total_meals'] as num?)?.toInt() ?? 0;
    if (totalMeals == 0) {
      return {
        'total_meals': 0,
        'days_with_data': 0,
        'avg_calories_per_day': 0.0,
        'avg_protein_per_day': 0.0,
        'avg_carbs_per_day': 0.0,
        'avg_fat_per_day': 0.0,
        'avg_fiber_per_day': 0.0,
      };
    }

    final totalCalories = (row?['total_calories'] as num?)?.toDouble() ?? 0.0;
    final totalProtein = (row?['total_protein'] as num?)?.toDouble() ?? 0.0;
    final totalCarbs = (row?['total_carbs'] as num?)?.toDouble() ?? 0.0;
    final totalFat = (row?['total_fat'] as num?)?.toDouble() ?? 0.0;
    final totalFiber = (row?['total_fiber'] as num?)?.toDouble() ?? 0.0;

    final daysResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT date(analyzed_at)) as days_with_food
      FROM foods
      WHERE analyzed_at >= ?
    ''',
      [start.toIso8601String()],
    );
    final daysWithData =
        (daysResult.first['days_with_food'] as num?)?.toInt() ?? 1;
    final effectiveDays = daysWithData > 0 ? daysWithData : 1;

    return {
      'total_meals': totalMeals,
      'days_with_data': daysWithData,
      'avg_calories_per_day': totalCalories / effectiveDays,
      'avg_protein_per_day': totalProtein / effectiveDays,
      'avg_carbs_per_day': totalCarbs / effectiveDays,
      'avg_fat_per_day': totalFat / effectiveDays,
      'avg_fiber_per_day': totalFiber / effectiveDays,
    };
  }

  Future<Map<String, dynamic>> getWeeklySummary() async {
    final db = await database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(const Duration(days: 7));

    // Get total foods and calories
    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_foods,
        SUM(calories) as total_calories
      FROM foods
      WHERE analyzed_at >= ?
    ''',
      [startOfWeek.toIso8601String()],
    );

    final totalFoods = (result.first['total_foods'] as num?)?.toInt() ?? 0;
    final totalCalories =
        (result.first['total_calories'] as num?)?.toDouble() ?? 0.0;

    // Get count of distinct days with food data
    final daysResult = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT date(analyzed_at)) as days_with_food
      FROM foods
      WHERE analyzed_at >= ?
    ''',
      [startOfWeek.toIso8601String()],
    );

    final daysWithFood =
        (daysResult.first['days_with_food'] as num?)?.toInt() ?? 0;

    // Calculate average calories per day based on actual days with food
    // If no food data, return 0. Otherwise divide by actual days with food.
    final avgCaloriesPerDay = daysWithFood > 0
        ? totalCalories / daysWithFood
        : 0.0;

    return {
      'total_foods': totalFoods,
      'avg_calories_per_day': avgCaloriesPerDay,
      'total_calories': totalCalories,
      'days_with_food': daysWithFood,
    };
  }

  Future<Map<String, dynamic>> getMonthlySummary() async {
    final db = await database;
    final now = DateTime.now();

    // Get previous month's start and end dates
    final startOfPreviousMonth = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
      1,
    );
    final endOfPreviousMonth = DateTime(now.year, now.month, 1);

    // Get total foods for previous month
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as total_foods
      FROM foods
      WHERE analyzed_at >= ? AND analyzed_at < ?
    ''',
      [
        startOfPreviousMonth.toIso8601String(),
        endOfPreviousMonth.toIso8601String(),
      ],
    );

    final totalFoods = (result.first['total_foods'] as num?)?.toInt() ?? 0;

    return {
      'total_foods': totalFoods,
      'month_number': startOfPreviousMonth.month,
      'year': startOfPreviousMonth.year,
    };
  }

  Future<Map<String, dynamic>> getCurrentMonthSummary() async {
    final db = await database;
    final now = DateTime.now();

    // Get current month's start and end dates
    final startOfCurrentMonth = DateTime(now.year, now.month, 1);
    final endOfCurrentMonth = DateTime(
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
      1,
    );

    // Get total foods for current month
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as total_foods
      FROM foods
      WHERE analyzed_at >= ? AND analyzed_at < ?
    ''',
      [
        startOfCurrentMonth.toIso8601String(),
        endOfCurrentMonth.toIso8601String(),
      ],
    );

    final totalFoods = (result.first['total_foods'] as num?)?.toInt() ?? 0;

    return {
      'total_foods': totalFoods,
      'month_number': now.month,
      'year': now.year,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<bool> backupToCloud({bool isPremiumUser = false}) async {
    try {
      final foods = await getAllFoods();
      return await _cloudBackupService.backupFoodData(
        foods,
        isPremiumUser: isPremiumUser,
      );
    } catch (e) {
      return false;
    }
  }

  Future<List<Food>> restoreFromCloud() async {
    try {
      return await _cloudBackupService.restoreFoodData();
    } catch (e) {
      return [];
    }
  }

  Future<bool> hasCloudBackup() async {
    try {
      return await _cloudBackupService.hasBackup();
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCloudBackupInfo() async {
    try {
      return await _cloudBackupService.getBackupInfo();
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteCloudBackup() async {
    try {
      return await _cloudBackupService.deleteBackup();
    } catch (e) {
      return false;
    }
  }

  Future<bool> restoreFromCloudAndReplace() async {
    try {
      final cloudFoods = await _cloudBackupService.restoreFoodData();
      if (cloudFoods.isEmpty) return false;

      // Clear local database
      await deleteAllFoods();

      // Insert cloud data
      for (final food in cloudFoods) {
        await insertFood(food);
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
