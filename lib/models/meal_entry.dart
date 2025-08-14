// models/meal_entry.dart
class MealEntry {
  final String? id; // Supabase ID
  DateTime timestamp;
  List<String> foodNames;
  double calories;
  double protein;
  double carbs;
  double fat;
  String servingSize;
  String? imageUrl; // For storing image URLs in cloud storage
  final String? userId; // Foreign key to user

  MealEntry({
    this.id,
    required this.timestamp,
    required this.foodNames,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    this.imageUrl,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'food_names': foodNames,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'serving_size': servingSize,
      'image_url': imageUrl,
      'user_id': userId,
    };
  }

  static MealEntry fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: json['id'] as String?,
      timestamp: DateTime.parse(json['timestamp']),
      foodNames: List<String>.from(json['food_names']),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      servingSize: json['serving_size'],
      imageUrl: json['image_url'] as String?,
      userId: json['user_id'] as String?,
    );
  }

  static MealEntry fromSupabaseJson(Map<String, dynamic> json) {
    return MealEntry(
      id: json['id']?.toString(),
      timestamp: DateTime.parse(json['timestamp']),
      foodNames: List<String>.from(json['food_names']),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      servingSize: json['serving_size'],
      imageUrl: json['image_url'] as String?,
      userId: json['user_id'] as String?,
    );
  }

  MealEntry copyWith({
    String? id,
    DateTime? timestamp,
    List<String>? foodNames,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? servingSize,
    String? imageUrl,
    String? userId,
  }) {
    return MealEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      foodNames: foodNames ?? this.foodNames,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      servingSize: servingSize ?? this.servingSize,
      imageUrl: imageUrl ?? this.imageUrl,
      userId: userId ?? this.userId,
    );
  }
}