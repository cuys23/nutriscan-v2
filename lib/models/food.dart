class Food {
  final String id;
  final String name;
  final String description;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final int healthScore;
  final List<String> healthBenefits;
  final List<String> healthWarnings;
  final String servingSize;
  final String imagePath; // Can contain either local path or Firebase URL
  final DateTime analyzedAt;

  Food({
    required this.id,
    required this.name,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.healthScore,
    required this.healthBenefits,
    required this.healthWarnings,
    required this.servingSize,
    required this.imagePath,
    required this.analyzedAt,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    // Try multiple possible keys for food name
    String foodName =
        json['food_name'] ??
        json['name'] ??
        json['foodName'] ??
        json['title'] ??
        json['item'] ??
        'Food Item';

    // description: API may send description, desc, details, or notes (Groq food analysis uses "notes")
    String? rawDesc = json['description'] ??
        json['desc'] ??
        json['details'] ??
        json['notes'];
    String foodDescription =
        (rawDesc != null && rawDesc.toString().trim().isNotEmpty)
            ? rawDesc.toString().trim()
            : '';

    return Food(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: foodName,
      description: foodDescription,
      calories: _parseDouble(json['calories']),
      protein: _parseDouble(json['protein']),
      carbs: _parseDouble(json['carbs']),
      fat: _parseDouble(json['fat']),
      fiber: _parseDouble(json['fiber']),
      sugar: _parseDouble(json['sugar']),
      sodium: _parseDouble(json['sodium']),
      healthScore: _parseInt(json['healthScore'] ?? json['health_score']),
      healthBenefits: List<String>.from(json['health_benefits'] ?? []),
      healthWarnings: List<String>.from(json['health_warnings'] ?? []),
      servingSize: json['serving_size'] ?? '1 serving',
      imagePath: json['image_path'] ?? json['firebase_image_url'] ?? '',
      analyzedAt: DateTime.now(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 5;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 5;
    }
    return 5;
  }

  /// Returns the image URL (can be local path or Firebase URL)
  String get effectiveImageUrl => imagePath;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'health_score': healthScore,
      'health_benefits': healthBenefits,
      'health_warnings': healthWarnings,
      'serving_size': servingSize,
      'image_path': imagePath,
      'analyzed_at': analyzedAt.toIso8601String(),
    };
  }

  Food copyWith({
    String? id,
    String? name,
    String? description,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    double? sodium,
    int? healthScore,
    List<String>? healthBenefits,
    List<String>? healthWarnings,
    String? servingSize,
    String? imagePath,
    DateTime? analyzedAt,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      healthScore: healthScore ?? this.healthScore,
      healthBenefits: healthBenefits ?? this.healthBenefits,
      healthWarnings: healthWarnings ?? this.healthWarnings,
      servingSize: servingSize ?? this.servingSize,
      imagePath: imagePath ?? this.imagePath,
      analyzedAt: analyzedAt ?? this.analyzedAt,
    );
  }
}
