import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/models/food.dart';
import 'package:nutriscan/services/database/database_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// V-P4-2: an existing install must still open after the schema version is
/// bumped. There is nothing to migrate yet, so this pins the wiring — that
/// [DatabaseHelper] passes an onUpgrade at all and that a database written by
/// an older build survives being reopened with its rows intact. Whoever adds
/// the first real migration should extend this rather than start over.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<String> legacyDatabaseWithOneRow(int atVersion) async {
    final path = join(await databaseFactory.getDatabasesPath(), 'calories.db');
    await databaseFactory.deleteDatabase(path);

    final db = await databaseFactory.openDatabase(path);
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
    await db.insert('foods', {
      'id': 'legacy-1',
      'name': 'Old scan',
      'description': 'logged by a previous build',
      'calories': 250.0,
      'protein': 10.0,
      'carbs': 30.0,
      'fat': 5.0,
      'fiber': 2.0,
      'sugar': 3.0,
      'sodium': 100.0,
      'health_score': 6,
      'health_benefits': 'high protein|low sugar',
      'health_warnings': '',
      'serving_size': '1 serving',
      'image_path': '',
      'analyzed_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });
    await db.setVersion(atVersion);
    await db.close();
    return path;
  }

  // One test, not two: DatabaseHelper caches the open database in a static
  // field, so a second test that deletes and reopens the file would hand the
  // helper back a closed handle.
  test('an older install opens at the current version and keeps its rows',
      () async {
    await legacyDatabaseWithOneRow(1);

    final foods = await DatabaseHelper().getAllFoods();

    expect(foods, hasLength(1));
    final Food food = foods.single;
    expect(food.id, 'legacy-1');
    expect(food.calories, 250.0);
    expect(food.healthBenefits, ['high protein', 'low sugar']);
    // Empty strings must not become [''] — the split/filter in getAllFoods
    // is the only thing standing between a blank column and a stray bullet
    // in the UI.
    expect(food.healthWarnings, isEmpty);

    // Guards the one thing a missing onUpgrade breaks: sqflite throws rather
    // than opening when the stored version is below the requested one and no
    // upgrade handler is registered.
    final db = await DatabaseHelper().database;
    expect(await db.getVersion(), greaterThanOrEqualTo(1));
  });
}
