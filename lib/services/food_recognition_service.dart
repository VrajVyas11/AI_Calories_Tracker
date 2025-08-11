import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Clarifai + USDA based food recognition service.
///
/// Requirements:
///  - Provide your Clarifai API key in [_clarifaiApiKey].
///  - Uses Clarifai food-item-recognition model version:
///    1d5fd481e0cf4826aa72ec3ff049e044
class FoodRecognitionService {
  // Use runtime getters because dotenv.env is not a compile-time constant
  static String get _clarifaiApiKey {
    final v = dotenv.env['CLARIFAI_API_KEY'];
    if (v == null || v.isEmpty) {
      throw StateError('CLARIFAI_API_KEY not set. '
          'Load dotenv or provide via --dart-define.');
    }
    return v;
  }

  static String get _usdaApiKey {
    final v = dotenv.env['USDA_API_KEY'];
    if (v == null || v.isEmpty) {
      // You can return a default or throw; throwing helps spot misconfiguration early
      throw StateError('USDA_API_KEY not set. Load dotenv or provide via --dart-define.');
    }
    return v;
  }

  static String get _clarifaiEndpoint {
    // fallback to the known endpoint if you prefer
    return dotenv.env['CLARIFAI_API_ENDPOINT'] ??
        'https://api.clarifai.com/v2/models/food-item-recognition/versions/1d5fd481e0cf4826aa72ec3ff049e044/outputs';
  }
      

  /// Recognize foods from image bytes using Clarifai model.
  /// Returns a list of RecognizedFood (name + confidence).
  static Future<List<RecognizedFood>> recognizeFood(
      Uint8List imageBytes) async {
    try {
      final imageBase64 = base64Encode(imageBytes);

      final body = {
        "user_app_id": {
          "user_id": "vrajvyas",
          "app_id": "food_ingredients_teller"
        },
        "inputs": [
          {
            "data": {
              "image": {"base64": imageBase64}
            }
          }
        ]
      };

      final response = await http
          .post(
            Uri.parse(_clarifaiEndpoint),
            headers: {
              'Authorization': 'Key $_clarifaiApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print(
              'Clarifai returned non-200: ${response.statusCode} ${response.body}');
        }
        return _fallbackRecognitionsFromBytes(imageBytes);
      }

      final Map<String, dynamic> parsed = jsonDecode(response.body);
      final outputs = parsed['outputs'] as List? ?? [];

      if (outputs.isEmpty) {
        return _fallbackRecognitionsFromBytes(imageBytes);
      }

      final firstOutput = outputs.first as Map<String, dynamic>;
      final data = firstOutput['data'] as Map<String, dynamic>? ?? {};
      final concepts = (data['concepts'] as List? ?? []);

      final recognized = <RecognizedFood>[];

      for (final c in concepts) {
        final name = (c['name'] ?? '').toString();
        final value = (c['value'] ?? 0).toDouble();
        if (name.isNotEmpty) {
          recognized.add(RecognizedFood(
            name: name,
            confidence: value,
          ));
        }
      }

      // Clarifai returns many concepts; keep top 5 with min confidence threshold
      recognized.sort((a, b) => b.confidence.compareTo(a.confidence));
      final filtered =
          recognized.where((r) => r.confidence > 0.04).take(5).toList();

      if (filtered.isEmpty) {
        return _fallbackRecognitionsFromBytes(imageBytes);
      }

      return filtered;
    } catch (e) {
      if (kDebugMode) print('Clarifai recognition error: $e');
      return _fallbackRecognitionsFromBytes(imageBytes);
    }
  }

  /// Fallback simple recognitions when Clarifai fails: returns a few
  /// estimated common foods (keeps app usable offline).
  static Future<List<RecognizedFood>> _fallbackRecognitionsFromBytes(
      Uint8List imageBytes) async {
    // Simple heuristic fallback -- reuse small heuristics from previous impl.
    final brightness = _approximateBrightness(imageBytes);
    final recognized = <RecognizedFood>[];

    if (brightness > 150) {
      recognized.add(RecognizedFood(name: 'apple', confidence: 0.7));
      recognized.add(RecognizedFood(name: 'banana', confidence: 0.6));
    } else if (brightness < 90) {
      recognized.add(RecognizedFood(name: 'grilled chicken', confidence: 0.65));
      recognized.add(RecognizedFood(name: 'beef', confidence: 0.5));
    } else {
      recognized.add(RecognizedFood(name: 'salad', confidence: 0.65));
      recognized.add(RecognizedFood(name: 'sandwich', confidence: 0.55));
    }

    return recognized;
  }

  static double _approximateBrightness(Uint8List bytes) {
    if (bytes.isEmpty) return 128.0;
    // Sample up to 2000 bytes for speed
    final step = (bytes.length / 2000).ceil().clamp(1, bytes.length);
    double sum = 0;
    var count = 0;
    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
      count++;
    }
    return count > 0 ? sum / count : 128.0;
  }

  /// Get nutrition for a food name using USDA search (same logic as before).
  /// Returns NutritionData or an estimated fallback.
  static Future<NutritionData?> getNutritionData(String foodName) async {
    try {
      final query = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
        'api_key': _usdaApiKey,
        'query': foodName,
        'pageSize': '1',
        'dataType': 'Foundation,SR Legacy',
      });

      final response = await http.get(query).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final foods = data['foods'] as List? ?? [];
        if (foods.isNotEmpty) {
          return _parseNutritionData(foods.first as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (kDebugMode) print('USDA fetch error for "$foodName": $e');
    }

    // fallback estimates
    return _getEstimatedNutrition(foodName);
  }

  static NutritionData _parseNutritionData(Map<String, dynamic> foodData) {
    final nutrients = foodData['foodNutrients'] as List? ?? [];

    double calories = 0, protein = 0, carbs = 0, fat = 0, fiber = 0;

    for (final nutrient in nutrients) {
      final name = (nutrient['nutrientName'] ?? '').toString().toLowerCase();
      final value = (nutrient['value'] ?? 0).toDouble();

      if (name.contains('energy') || name.contains('calories')) {
        calories = value;
      } else if (name.contains('protein')) {
        protein = value;
      } else if (name.contains('carbohydrate')) {
        carbs = value;
      } else if (name.contains('total lipid') || name.contains('fat')) {
        fat = value;
      } else if (name.contains('fiber')) {
        fiber = value;
      }
    }

    return NutritionData(
      foodName: (foodData['description'] ?? 'Unknown Food').toString(),
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      servingSize: '100g',
    );
  }

  static NutritionData _getEstimatedNutrition(String foodName) {
    final nutritionMap = {
      'apple': NutritionData(foodName: 'Apple', calories: 52, protein: 0.3, carbs: 14, fat: 0.2, fiber: 2.4, servingSize: '100g'),
      'banana': NutritionData(foodName: 'Banana', calories: 89, protein: 1.1, carbs: 23, fat: 0.3, fiber: 2.6, servingSize: '100g'),
      'chicken breast': NutritionData(foodName: 'Chicken Breast', calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0, servingSize: '100g'),
      'rice': NutritionData(foodName: 'White Rice', calories: 130, protein: 2.7, carbs: 28, fat: 0.3, fiber: 0.4, servingSize: '100g'),
      'bread': NutritionData(foodName: 'White Bread', calories: 265, protein: 9, carbs: 49, fat: 3.2, fiber: 2.7, servingSize: '100g'),
      'pasta': NutritionData(foodName: 'Pasta', calories: 131, protein: 5, carbs: 25, fat: 1.1, fiber: 1.8, servingSize: '100g'),
      'salad': NutritionData(foodName: 'Mixed Salad', calories: 20, protein: 1.5, carbs: 4, fat: 0.2, fiber: 2, servingSize: '100g'),
      'pizza': NutritionData(foodName: 'Pizza', calories: 266, protein: 11, carbs: 33, fat: 10, fiber: 2.3, servingSize: '100g'),
      'burger': NutritionData(foodName: 'Hamburger', calories: 295, protein: 17, carbs: 25, fat: 15, fiber: 2, servingSize: '100g'),
      'sandwich': NutritionData(foodName: 'Sandwich', calories: 250, protein: 12, carbs: 30, fat: 8, fiber: 3, servingSize: '100g'),
      'eggs': NutritionData(foodName: 'Eggs', calories: 155, protein: 13, carbs: 1.1, fat: 11, fiber: 0, servingSize: '100g'),
      'milk': NutritionData(foodName: 'Milk', calories: 42, protein: 3.4, carbs: 5, fat: 1, fiber: 0, servingSize: '100g'),
    };

    final lower = foodName.toLowerCase();
    for (final key in nutritionMap.keys) {
      if (lower.contains(key)) return nutritionMap[key]!;
    }

    return NutritionData(
      foodName: foodName,
      calories: 150,
      protein: 5,
      carbs: 20,
      fat: 5,
      fiber: 2,
      servingSize: '100g',
    );
  }
}

class RecognizedFood {
  final String name;
  final double confidence;
  NutritionData? nutrition;

  RecognizedFood({
    required this.name,
    required this.confidence,
    this.nutrition,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'confidence': confidence,
      'nutrition': nutrition?.toJson(),
    };
  }
}

class NutritionData {
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String servingSize;

  NutritionData({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.servingSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'food_name': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'serving_size': servingSize,
    };
  }
}