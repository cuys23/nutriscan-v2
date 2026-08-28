import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutriscan/config/firebase_config.dart';
import 'package:nutriscan/models/food.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudBackupService {
  static final CloudBackupService _instance = CloudBackupService._internal();
  factory CloudBackupService() => _instance;
  CloudBackupService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool _isSignedIn = false;
  String? _userId;
  String? _deviceId;

  bool get isSignedIn => _isSignedIn;
  String? get userId => _userId;

  Future<void> initialize() async {
    try {
      // Get device ID
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('device_id') ?? _generateDeviceId();
      await prefs.setString('device_id', _deviceId!);

      // Check if user is already signed in
      await _updateAuthState();
    } catch (e) {
      // Handle initialization error
    }
  }

  Future<void> _updateAuthState() async {
    final user = _auth.currentUser;
    _isSignedIn = user != null;
    _userId = user?.uid;
  }

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      await _updateAuthState();

      // Verify the sign-in was successful
      final isSuccess =
          userCredential.user != null && _isSignedIn && _userId != null;
      return isSuccess;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from Firebase
      await _auth.signOut();

      // Sign out from Google
      await _googleSignIn.signOut();

      // Update auth state
      await _updateAuthState();
    } catch (e) {
      // Handle sign out error
    }
  }

  Future<bool> backupFoodData(
    List<Food> foods, {
    bool isPremiumUser = false,
  }) async {
    if (!_isSignedIn || _userId == null) return false;

    // Only backup for premium users
    if (!isPremiumUser) {
      return false;
    }

    try {
      // Process foods and upload images to Firebase Storage
      final List<Map<String, dynamic>> processedFoods = [];

      for (final food in foods) {
        Map<String, dynamic> foodMap = _foodToMap(food);

        // Use imagePath which can contain either local path or Firebase URL
        if (food.imagePath.isNotEmpty) {
          foodMap['imagePath'] = food.imagePath;
        }

        processedFoods.add(foodMap);
      }

      final user = _auth.currentUser;
      final backupData = {
        'userId': _userId,
        'email': user?.email,
        'displayName': user?.displayName,
        'deviceId': _deviceId,
        'foods': processedFoods,
        'backupDate': FieldValue.serverTimestamp(),
        'totalItems': foods.length,
      };

      await _firestore
          .collection(FirebaseConfig.backupCollection)
          .doc(_userId)
          .set(backupData, SetOptions(merge: true));

      // Update last backup timestamp
      await _updateLastBackupTime();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Food>> restoreFoodData() async {
    if (!_isSignedIn || _userId == null) return [];

    try {
      final doc = await _firestore
          .collection(FirebaseConfig.backupCollection)
          .doc(_userId)
          .get();

      if (!doc.exists) return [];

      final data = doc.data()!;
      final foodsData = data['foods'] as List<dynamic>?;

      if (foodsData == null) return [];

      return foodsData.map((foodMap) => _mapToFood(foodMap)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> hasBackup() async {
    if (!_isSignedIn || _userId == null) return false;

    try {
      final doc = await _firestore
          .collection(FirebaseConfig.backupCollection)
          .doc(_userId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getBackupInfo() async {
    if (!_isSignedIn || _userId == null) return null;

    try {
      final doc = await _firestore
          .collection(FirebaseConfig.backupCollection)
          .doc(_userId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'backupDate': data['backupDate'],
        'totalItems': data['totalItems'] ?? 0,
        'deviceId': data['deviceId'],
      };
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteBackup() async {
    if (!_isSignedIn || _userId == null) return false;

    try {
      await _firestore
          .collection(FirebaseConfig.backupCollection)
          .doc(_userId)
          .delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_backup', DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getString('last_backup');
    if (lastBackup != null) {
      return DateTime.parse(lastBackup);
    }
    return null;
  }

  Map<String, dynamic> _foodToMap(Food food) {
    return {
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
      'healthScore': food.healthScore,
      'healthBenefits': food.healthBenefits,
      'healthWarnings': food.healthWarnings,
      'servingSize': food.servingSize,
      'imagePath': food.imagePath,
      'analyzedAt': food.analyzedAt.toIso8601String(),
    };
  }

  Food _mapToFood(Map<String, dynamic> map) {
    return Food(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      calories: map['calories'].toDouble(),
      protein: map['protein'].toDouble(),
      carbs: map['carbs'].toDouble(),
      fat: map['fat'].toDouble(),
      fiber: map['fiber'].toDouble(),
      sugar: map['sugar'].toDouble(),
      sodium: map['sodium'].toDouble(),
      healthScore: map['healthScore'],
      healthBenefits: List<String>.from(map['healthBenefits'] ?? []),
      healthWarnings: List<String>.from(map['healthWarnings'] ?? []),
      servingSize: map['servingSize'] ?? '1 serving',
      imagePath: map['imagePath'] ?? '',
      analyzedAt: DateTime.parse(map['analyzedAt']),
    );
  }

  String _generateDeviceId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  Future<void> autoBackup(
    List<Food> foods, {
    bool isPremiumUser = false,
  }) async {
    if (_isSignedIn && foods.isNotEmpty) {
      await backupFoodData(foods, isPremiumUser: isPremiumUser);
    }
  }

  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_backup_enabled') ?? true;
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);
  }
}
