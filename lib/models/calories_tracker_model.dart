// lib/models/calories_tracker_model.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';
import '../services/ai_service.dart';

class CaloriesTrackerModel extends ChangeNotifier {
  // Authentication state
  UserProfile? _currentUser;
  bool _isAuthenticated = false;

  // UI state
  String _status = 'Ready to scan food';
  bool _processing = false;
  File? _imageFile;
  List<DetectedFood> _detectedFoods = [];

  // Daily tracking
  List<MealEntry> _todaysMeals = [];
  double _dailyCalories = 0;
  double _dailyProtein = 0;
  double _dailyCarbs = 0;
  double _dailyFat = 0;

  // Analytics data
  List<Map<String, dynamic>> _dailySummaries = [];
  bool _isLoadingAnalytics = false;

  // Getters
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String get status => _status;
  bool get processing => _processing;
  File? get imageFile => _imageFile;
  List<DetectedFood> get detectedFoods => _detectedFoods;
  List<MealEntry> get todaysMeals => _todaysMeals;
  double get dailyCalories => _dailyCalories;
  double get dailyProtein => _dailyProtein;
  double get dailyCarbs => _dailyCarbs;
  double get dailyFat => _dailyFat;
  List<Map<String, dynamic>> get dailySummaries => _dailySummaries;
  bool get isLoadingAnalytics => _isLoadingAnalytics;

  // Authentication methods
  Future<AuthResult> signUp(String email, String password, String fullName) async {
    final result = await SupabaseService.signUp(email, password, fullName);
    if (result.success && result.user != null) {
      _currentUser = result.user;
      _isAuthenticated = true;
      notifyListeners();
    }
    return result;
  }

  Future<AuthResult> signIn(String email, String password) async {
    final result = await SupabaseService.signIn(email, password);
    if (result.success && result.user != null) {
      _currentUser = result.user;
      _isAuthenticated = true;
      await loadTodaysMeals();
      notifyListeners();
    }
    return result;
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    _currentUser = null;
    _isAuthenticated = false;
    _clearAllData();
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _isAuthenticated = await SupabaseService.isAuthenticated();
    if (_isAuthenticated) {
      _currentUser = await SupabaseService.getUserProfile();
      if (_currentUser != null) {
        await loadTodaysMeals();
      }
    }
    notifyListeners();
  }

  Future<bool> completeOnboarding({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final success = await SupabaseService.completeOnboarding(calories, protein, carbs, fat);
    if (success) {
      // Refresh user profile to get updated goals
      _currentUser = await SupabaseService.getUserProfile();
      notifyListeners();
    }
    return success;
  }

  // Food scanning methods
  void setImageFilePath(String path) {
    _imageFile = File(path);
    _detectedFoods.clear();
    _status = 'Image selected. Ready to analyze.';
    notifyListeners();
  }

  Future<void> analyzeFood() async {
    if (_imageFile == null) return;

    _processing = true;
    _status = 'Analyzing food...';
    notifyListeners();

    try {
      final foods = await AIService.detectFoodsInImage(_imageFile!);
      _detectedFoods = foods;
      
      if (foods.isNotEmpty) {
        _status = 'Found ${foods.length} food item(s). Getting nutrition data...';
        notifyListeners();

        // Get nutrition for each food
        for (int i = 0; i < foods.length; i++) {
          final food = foods[i];
          final nutrition = await AIService.getNutritionInfo(food.name);
          foods[i] = food.copyWith(nutrition: nutrition);
          
          _status = 'Getting nutrition data... (${i + 1}/${foods.length})';
          notifyListeners();
        }
        
        _detectedFoods = foods;
        _status = 'Analysis complete! ${foods.length} food(s) detected.';
      } else {
        _status = 'No food detected. Try another image.';
      }
    } catch (e) {
      _status = 'Analysis failed: $e';
      if (kDebugMode) print('Analysis error: $e');
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  Future<bool> addToMealLog({double servingMultiplier = 1.0}) async {
    if (_detectedFoods.isEmpty || !_isAuthenticated) return false;

    try {
      // Calculate total nutrition
      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      final foodNames = <String>[];
      
      for (final food in _detectedFoods) {
        if (food.nutrition != null) {
          final proportion = food.proportion ?? 1.0;
          final multiplier = servingMultiplier * proportion;
          
          totalCalories += food.nutrition!.calories * multiplier;
          totalProtein += food.nutrition!.protein * multiplier;
          totalCarbs += food.nutrition!.carbs * multiplier;
          totalFat += food.nutrition!.fat * multiplier;
          
          foodNames.add(food.name);
        }
      }

      if (foodNames.isEmpty) return false;

      final meal = MealEntry(
        id: '',
        userId: _currentUser!.id,
        timestamp: DateTime.now(),
        foodNames: foodNames,
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
        servingSize: '${(servingMultiplier * 100).round()}g',
        imageUrl: '', // Could upload image to storage if needed
      );

      final success = await SupabaseService.saveMeal(meal);
      if (success) {
        await loadTodaysMeals();
        _clearScanData();
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Add meal error: $e');
    }
    
    return false;
  }

  // Meal management
  Future<void> loadTodaysMeals() async {
    if (!_isAuthenticated) return;
    
    try {
      final meals = await SupabaseService.getMealsForDate(DateTime.now());
      _todaysMeals = meals;
      _updateDailyTotals();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Load meals error: $e');
    }
  }

  Future<void> removeMeal(int index) async {
    if (index < 0 || index >= _todaysMeals.length) return;
    
    final meal = _todaysMeals[index];
    final success = await SupabaseService.deleteMeal(meal.id);
    
    if (success) {
      _todaysMeals.removeAt(index);
      _updateDailyTotals();
      notifyListeners();
    }
  }

  Future<void> updateGoals({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final success = await SupabaseService.updateGoals(calories, protein, carbs, fat);
    if (success) {
      // Refresh user profile
      _currentUser = await SupabaseService.getUserProfile();
      notifyListeners();
    }
  }

  // Analytics methods
  Future<void> loadAnalyticsData({String period = '7 days'}) async {
    if (!_isAuthenticated) return;
    
    _isLoadingAnalytics = true;
    notifyListeners();
    
    try {
      final now = DateTime.now();
      late DateTime startDate;
      
      switch (period) {
        case '7 days':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '30 days':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '90 days':
          startDate = now.subtract(const Duration(days: 90));
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }
      
      _dailySummaries = await SupabaseService.getDailySummaries(startDate, now);
      _dailySummaries.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    } catch (e) {
      if (kDebugMode) print('Load analytics error: $e');
    } finally {
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  // Private methods
  void _updateDailyTotals() {
    _dailyCalories = _todaysMeals.fold(0, (sum, meal) => sum + meal.calories);
    _dailyProtein = _todaysMeals.fold(0, (sum, meal) => sum + meal.protein);
    _dailyCarbs = _todaysMeals.fold(0, (sum, meal) => sum + meal.carbs);
    _dailyFat = _todaysMeals.fold(0, (sum, meal) => sum + meal.fat);
  }

  void _clearScanData() {
    _imageFile = null;
    _detectedFoods.clear();
    _status = 'Ready to scan food';
    _processing = false;
  }

  void _clearAllData() {
    _clearScanData();
    _todaysMeals.clear();
    _dailyCalories = 0;
    _dailyProtein = 0;
    _dailyCarbs = 0;
    _dailyFat = 0;
    _dailySummaries.clear();
  }
}