// lib/models/calories_tracker_model.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../services/food_recognition_service.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';

class CaloriesTrackerModel extends ChangeNotifier {
  File? imageFile;
  List<FoodItem> detectedFoods = [];
  Map<String, dynamic>? nutritionData;
  bool processing = false;
  String status = "Ready to analyze food";

  UserProfile? currentUser;
  bool isAuthenticated = false;
  bool isCheckingAuth = true;

  List<MealEntry> todaysMeals = [];
  double dailyCalories = 0;
  double dailyProtein = 0;
  double dailyCarbs = 0;
  double dailyFat = 0;

  // Analytics data
  List<Map<String, dynamic>> weeklyData = [];
  List<Map<String, dynamic>> monthlyData = [];
  int goalHitDays = 0;
  int totalTrackedDays = 0;

  CaloriesTrackerModel() {
    refreshAuthState();
  }

  double get calorieGoal => currentUser?.calorieGoal ?? 2000;
  double get proteinGoal => currentUser?.proteinGoal ?? 150;
  double get carbsGoal => currentUser?.carbsGoal ?? 250;
  double get fatGoal => currentUser?.fatGoal ?? 67;

  Future<void> refreshAuthState() async {
    isCheckingAuth = true;
    notifyListeners();

    isAuthenticated = await SupabaseService.isAuthenticated();
    if (isAuthenticated) {
      currentUser = await SupabaseService.getUserProfile();
      await _loadTodaysData();
      await _loadAnalyticsData();
    } else {
      currentUser = null;
      todaysMeals = [];
      weeklyData = [];
      monthlyData = [];
      _updateDailyTotals();
    }
    
    isCheckingAuth = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    currentUser = null;
    isAuthenticated = false;
    todaysMeals.clear();
    weeklyData.clear();
    monthlyData.clear();
    _updateDailyTotals();
    notifyListeners();
  }

  Future<void> _loadTodaysData() async {
    if (!isAuthenticated) return;
    todaysMeals = await SupabaseService.getMealsForDate(DateTime.now());
    _updateDailyTotals();
    notifyListeners();
  }

  Future<void> _loadAnalyticsData() async {
    if (!isAuthenticated) return;
    
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    
    // Load weekly data
    weeklyData = await SupabaseService.getDailySummaries(weekAgo, now);
    
    // Load monthly data
    monthlyData = await SupabaseService.getDailySummaries(monthAgo, now);
    
    // Calculate goal hit days
    _calculateGoalStatistics();
    
    notifyListeners();
  }

  void _calculateGoalStatistics() {
    goalHitDays = 0;
    totalTrackedDays = monthlyData.length;
    
    for (final day in monthlyData) {
      final calories = (day['total_calories'] as num?)?.toDouble() ?? 0;
      final calorieGoalHit = calories >= (calorieGoal * 0.8) && calories <= (calorieGoal * 1.2);
      
      if (calorieGoalHit) {
        goalHitDays++;
      }
    }
  }

  void _updateDailyTotals() {
    dailyCalories = todaysMeals.fold(0, (sum, meal) => sum + meal.calories);
    dailyProtein = todaysMeals.fold(0, (sum, meal) => sum + meal.protein);
    dailyCarbs = todaysMeals.fold(0, (sum, meal) => sum + meal.carbs);
    dailyFat = todaysMeals.fold(0, (sum, meal) => sum + meal.fat);
  }

  void setImageFilePath(String path) {
    imageFile = File(path);
    detectedFoods = [];
    nutritionData = null;
    notifyListeners();
  }

  Future<void> analyzeFood() async {
    if (imageFile == null) return;
    processing = true;
    status = "Analyzing food image...";
    notifyListeners();
    try {
      final bytes = await imageFile!.readAsBytes();
      final recognized = await FoodRecognitionService.recognizeFood(bytes);
      if (recognized.isNotEmpty) {
        status = "Fetching nutrition data...";
        notifyListeners();
        final items = <FoodItem>[];
        for (final r in recognized) {
          var cached = await SupabaseService.getCachedNutrition(r.name);
          NutritionData? nutrition;
          if (cached != null) {
            nutrition = NutritionData(
              foodName: cached['food_name'] ?? r.name,
              calories: (cached['calories'] ?? 0).toDouble(),
              protein: (cached['protein'] ?? 0).toDouble(),
              carbs: (cached['carbs'] ?? 0).toDouble(),
              fat: (cached['fat'] ?? 0).toDouble(),
              fiber: (cached['fiber'] ?? 0).toDouble(),
              servingSize: cached['serving_size'] ?? '100g',
            );
          } else {
            nutrition = await FoodRecognitionService.getNutritionData(r.name);
            if (nutrition != null) await SupabaseService.cacheNutritionData(r.name, nutrition.toJson());
          }
          final foodItem = FoodItem(name: r.name, confidence: r.confidence, nutrition: nutrition != null ? NutritionInfo.fromNutritionData(nutrition) : null);
          items.add(foodItem);
        }
        detectedFoods = items;
        _calculateFoodProportions();
        nutritionData = _generateNutritionSummary();
        status = "Analysis complete!";
      } else {
        status = "No food items detected. Try a clearer image.";
      }
    } catch (e) {
      status = "Error analyzing image: $e";
      if (kDebugMode) print("Analysis error: $e");
    } finally {
      processing = false;
      notifyListeners();
    }
  }

  void _calculateFoodProportions() {
    if (detectedFoods.isEmpty) return;
    double totalScore = 0;
    for (var f in detectedFoods) {
      final cals = f.nutrition?.calories ?? 100.0;
      f.nutritionScore = f.confidence * cals;
      totalScore += f.nutritionScore ?? 0;
    }
    if (totalScore <= 0) {
      final each = 1.0 / detectedFoods.length;
      for (var f in detectedFoods) {
        f.proportion = each;
      }
      return;
    }
    for (var f in detectedFoods) {
      f.proportion = (f.nutritionScore ?? 0) / totalScore;
    }
    final sum = detectedFoods.fold(0.0, (s, f) => s + (f.proportion ?? 0));
    if (sum > 0) {
      for (var f in detectedFoods) {
        f.proportion = (f.proportion ?? 0) / sum;
      }
    }
  }

  Map<String, dynamic> _generateNutritionSummary() {
    double totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    for (var food in detectedFoods) {
      if (food.nutrition != null && food.proportion != null) {
        totalCalories += food.nutrition!.calories * food.proportion!;
        totalProtein += food.nutrition!.protein * food.proportion!;
        totalCarbs += food.nutrition!.carbs * food.proportion!;
        totalFat += food.nutrition!.fat * food.proportion!;
      }
    }
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'detected_foods': detectedFoods.map((f) => f.toJson()).toList(),
      'nutrition_summary': {
        'calories': totalCalories.round(),
        'protein': totalProtein.round(),
        'carbs': totalCarbs.round(),
        'fat': totalFat.round(),
      },
      'serving_info': "Values shown are weighted by food proportions (per 100g basis)",
    };
  }

  /// Complete onboarding with goals
  Future<bool> completeOnboarding({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    if (!isAuthenticated) return false;

    final success = await SupabaseService.completeOnboarding(calories, protein, carbs, fat);
    if (success) {
      currentUser = await SupabaseService.getUserProfile();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Add to meal log. Ensures user_profile exists and retries once if FK caused failure.
  Future<bool> addToMealLog({required double servingMultiplier}) async {
    if (detectedFoods.isEmpty) return false;
    isAuthenticated = await SupabaseService.isAuthenticated();
    if (!isAuthenticated) return false;

    double totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    final foodNames = <String>[];
    for (var food in detectedFoods) {
      foodNames.add(food.name);
      if (food.nutrition != null && food.proportion != null) {
        final factor = food.proportion! * servingMultiplier;
        totalCalories += food.nutrition!.calories * factor;
        totalProtein += food.nutrition!.protein * factor;
        totalCarbs += food.nutrition!.carbs * factor;
        totalFat += food.nutrition!.fat * factor;
      }
    }

    final meal = MealEntry(
      timestamp: DateTime.now(),
      foodNames: foodNames,
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      servingSize: "${(servingMultiplier * 100).round()}g",
      userId: currentUser?.id,
    );

    // Try saving
    var success = await SupabaseService.saveMeal(meal);
    if (success) {
      await _loadTodaysData();
      await _loadAnalyticsData(); // Refresh analytics after new meal
      notifyListeners();
      return true;
    }

    // If failed, try to ensure user_profile exists and retry once
    final ensured = await SupabaseService.ensureUserProfileExists();
    if (ensured) {
      success = await SupabaseService.saveMeal(meal);
      if (success) {
        await _loadTodaysData();
        await _loadAnalyticsData();
        notifyListeners();
        return true;
      }
    }

    // failed
    return false;
  }

  Future<void> updateGoals({double? calories, double? protein, double? carbs, double? fat}) async {
    if (!isAuthenticated) return;
    final success = await SupabaseService.updateGoals(
      calories ?? currentUser?.calorieGoal ?? 2000,
      protein ?? currentUser?.proteinGoal ?? 150,
      carbs ?? currentUser?.carbsGoal ?? 250,
      fat ?? currentUser?.fatGoal ?? 67,
    );
    if (success) {
      currentUser = await SupabaseService.getUserProfile();
      notifyListeners();
    }
  }

  Future<void> removeMeal(int index) async {
    if (index < 0 || index >= todaysMeals.length) return;
    final meal = todaysMeals[index];
    if (meal.id != null) {
      final success = await SupabaseService.deleteMeal(meal.id!);
      if (success) {
        await _loadTodaysData();
        await _loadAnalyticsData();
        notifyListeners();
      }
    }
  }

  Future<List<MealEntry>> getMealsForDateRange(DateTime start, DateTime end) async {
    if (!isAuthenticated) return [];
    return await SupabaseService.getMealsForDateRange(start, end);
  }

  // Get analytics data for charts
  List<Map<String, dynamic>> getWeeklyCaloriesData() {
    return weeklyData.map((day) {
      final date = DateTime.parse(day['date']);
      return {
        'day': _getDayName(date.weekday),
        'calories': (day['total_calories'] as num?)?.toDouble() ?? 0,
        'goal': calorieGoal,
      };
    }).toList();
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  double get goalHitPercentage {
    if (totalTrackedDays == 0) return 0;
    return (goalHitDays / totalTrackedDays) * 100;
  }

  Map<String, double> getAverageNutrients() {
    if (monthlyData.isEmpty) {
      return {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0};
    }

    double totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    
    for (final day in monthlyData) {
      totalCalories += (day['total_calories'] as num?)?.toDouble() ?? 0;
      totalProtein += (day['total_protein'] as num?)?.toDouble() ?? 0;
      totalCarbs += (day['total_carbs'] as num?)?.toDouble() ?? 0;
      totalFat += (day['total_fat'] as num?)?.toDouble() ?? 0;
    }

    final days = monthlyData.length;
    return {
      'calories': totalCalories / days,
      'protein': totalProtein / days,
      'carbs': totalCarbs / days,
      'fat': totalFat / days,
    };
  }
}

class FoodItem {
  String name;
  double confidence;
  NutritionInfo? nutrition;
  double? proportion;
  double? nutritionScore;

  FoodItem({required this.name, required this.confidence, this.nutrition, this.proportion, this.nutritionScore});
  void updateNutrition(NutritionInfo ni) => nutrition = ni;
  Map<String, dynamic> toJson() => {'name': name, 'confidence': confidence, 'proportion': proportion, 'nutrition': nutrition?.toJson()};
}

class NutritionInfo {
  double calories;
  double protein;
  double carbs;
  double fat;
  double fiber;
  String servingSize;

  NutritionInfo({required this.calories, required this.protein, required this.carbs, required this.fat, required this.fiber, required this.servingSize});

  factory NutritionInfo.fromNutritionData(NutritionData d) => NutritionInfo(calories: d.calories, protein: d.protein, carbs: d.carbs, fat: d.fat, fiber: d.fiber, servingSize: d.servingSize);

  Map<String, dynamic> toJson() => {'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat, 'fiber': fiber, 'serving_size': servingSize};
}