// lib/main.dart
// ignore_for_file: invalid_use_of_protected_member

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Import the new service
import 'services/food_recognition_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Debug: print current working directory and whether .env exists
  // (remove these prints after debugging)
  print('CWD: ${Directory.current.path}');
  print(
      '.env exists: ${File(Directory.current.path + Platform.pathSeparator + ".env").existsSync()}');

  try {
    await dotenv.load(fileName: '.env'); // must be awaited
    print('dotenv keys: ${dotenv.env.keys.toList()}');
  } catch (e) {
    print(
        '.env not found, falling back to --dart-define values if provided. Error: $e');
  }

  runApp(const MyApp());
}

/// ====================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CaloriesTrackerModel(),
      child: MaterialApp(
        title: 'AI Calories Tracker',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
        ),
        home: const MainPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class CaloriesTrackerModel extends ChangeNotifier {
  File? imageFile;
  List<FoodItem> detectedFoods = [];
  Map<String, dynamic>? nutritionData;
  bool processing = false;
  String status = "Ready to analyze food";

  // Daily tracking
  List<MealEntry> todaysMeals = [];
  double dailyCalories = 0;
  double dailyProtein = 0;
  double dailyCarbs = 0;
  double dailyFat = 0;

  // Goals
  double calorieGoal = 2000;
  double proteinGoal = 150;
  double carbsGoal = 250;
  double fatGoal = 67;

  CaloriesTrackerModel() {
    _loadTodaysData();
  }

  Future<void> _loadTodaysData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().substring(0, 10);
    final savedData = prefs.getString('meals_$today');

    if (savedData != null) {
      final List<dynamic> mealsJson = jsonDecode(savedData);
      todaysMeals = mealsJson.map((m) => MealEntry.fromJson(m)).toList();
      _updateDailyTotals();
    }

    // Load goals
    calorieGoal = prefs.getDouble('calorie_goal') ?? 2000;
    proteinGoal = prefs.getDouble('protein_goal') ?? 150;
    carbsGoal = prefs.getDouble('carbs_goal') ?? 250;
    fatGoal = prefs.getDouble('fat_goal') ?? 67;

    notifyListeners();
  }

  Future<void> _saveTodaysData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().substring(0, 10);
    final mealsJson = todaysMeals.map((m) => m.toJson()).toList();
    await prefs.setString('meals_$today', jsonEncode(mealsJson));

    // Save goals
    await prefs.setDouble('calorie_goal', calorieGoal);
    await prefs.setDouble('protein_goal', proteinGoal);
    await prefs.setDouble('carbs_goal', carbsGoal);
    await prefs.setDouble('fat_goal', fatGoal);
  }

  void _updateDailyTotals() {
    dailyCalories = todaysMeals.fold(0, (sum, meal) => sum + meal.calories);
    dailyProtein = todaysMeals.fold(0, (sum, meal) => sum + meal.protein);
    dailyCarbs = todaysMeals.fold(0, (sum, meal) => sum + meal.carbs);
    dailyFat = todaysMeals.fold(0, (sum, meal) => sum + meal.fat);
  }

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (xfile == null) return;

    imageFile = File(xfile.path);
    detectedFoods = [];
    nutritionData = null;
    notifyListeners();

    await analyzeFood();
  }

  Future<void> analyzeFood() async {
    if (imageFile == null) return;

    processing = true;
    status = "Analyzing food image...";
    notifyListeners();

    try {
      // Use Clarifai via FoodRecognitionService
      final bytes = await imageFile!.readAsBytes();
      final recognized = await FoodRecognitionService.recognizeFood(bytes);

      if (recognized.isNotEmpty) {
        status = "Fetching nutrition data...";
        notifyListeners();

        final items = <FoodItem>[];
        for (final r in recognized) {
          final nutrition =
              await FoodRecognitionService.getNutritionData(r.name);
          final foodItem = FoodItem(
            name: r.name,
            confidence: r.confidence,
          );
          if (nutrition != null) {
            foodItem.updateNutrition(NutritionInfo(
              calories: nutrition.calories,
              protein: nutrition.protein,
              carbs: nutrition.carbs,
              fat: nutrition.fat,
              fiber: nutrition.fiber,
              servingSize: nutrition.servingSize,
            ));
          }
          items.add(foodItem);
        }

        // Assign to detectedFoods
        detectedFoods = items;

        // -------- Percentage calculation block --------
        double totalWeight = 0;
        for (var food in detectedFoods) {
          final n = food.nutrition?.toJson();
          final sumNutri = (n?["calories"] ?? 0) +
              (n?["protein"] ?? 0) +
              (n?["carbs"] ?? 0) +
              (n?["fat"] ?? 0);
          totalWeight += (food.confidence) * sumNutri;
        }

        for (var food in detectedFoods) {
          final n = food.nutrition?.toJson();
          final sumNutri = (n?["calories"] ?? 0) +
              (n?["protein"] ?? 0) +
              (n?["carbs"] ?? 0) +
              (n?["fat"] ?? 0);
          final weight = (food.confidence) * sumNutri;
          final percent = totalWeight > 0 ? (weight / totalWeight) * 100 : 0;
          food.percentage =
              percent as double?; // ← store in FoodItem (add field if needed)
          if (kDebugMode) {
            print("${food.name}: ${percent.toStringAsFixed(2)}%");
          }
        }
        // -------- End percentage calculation --------

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

  Map<String, dynamic> _generateNutritionSummary() {
    double totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;

    for (var food in detectedFoods) {
      if (food.nutrition != null) {
        totalCalories += food.nutrition!.calories;
        totalProtein += food.nutrition!.protein;
        totalCarbs += food.nutrition!.carbs;
        totalFat += food.nutrition!.fat;
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
      'serving_info': "Values shown are per 100g serving",
    };
  }

  Future<void> addToMealLog({double servingMultiplier = 1.0}) async {
    if (detectedFoods.isEmpty) return;

    double totalCalories = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
    final foodNames = <String>[];

    for (var food in detectedFoods) {
      foodNames.add(food.name);
      if (food.nutrition != null) {
        totalCalories += food.nutrition!.calories * servingMultiplier;
        totalProtein += food.nutrition!.protein * servingMultiplier;
        totalCarbs += food.nutrition!.carbs * servingMultiplier;
        totalFat += food.nutrition!.fat * servingMultiplier;
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
    );

    todaysMeals.add(meal);
    _updateDailyTotals();
    await _saveTodaysData();
    notifyListeners();
  }

  void updateGoals({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    if (calories != null) calorieGoal = calories;
    if (protein != null) proteinGoal = protein;
    if (carbs != null) carbsGoal = carbs;
    if (fat != null) fatGoal = fat;
    _saveTodaysData();
    notifyListeners();
  }

  void removeMeal(int index) {
    if (index >= 0 && index < todaysMeals.length) {
      todaysMeals.removeAt(index);
      _updateDailyTotals();
      _saveTodaysData();
      notifyListeners();
    }
  }
}

class FoodItem {
  String name;
  double confidence;
  NutritionInfo? nutrition;
  double? percentage;

  FoodItem({
    required this.name,
    required this.confidence,
    this.nutrition,
    this.percentage,
  });

  void updateNutrition(NutritionInfo nutrition) {
    this.nutrition = nutrition;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'confidence': confidence,
      'nutrition': nutrition?.toJson(),
    };
  }
}

class NutritionInfo {
  double calories;
  double protein;
  double carbs;
  double fat;
  double fiber;
  String servingSize;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.servingSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'serving_size': servingSize,
    };
  }
}

class MealEntry {
  DateTime timestamp;
  List<String> foodNames;
  double calories;
  double protein;
  double carbs;
  double fat;
  String servingSize;

  MealEntry({
    required this.timestamp,
    required this.foodNames,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'food_names': foodNames,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'serving_size': servingSize,
    };
  }

  static MealEntry fromJson(Map<String, dynamic> json) {
    return MealEntry(
      timestamp: DateTime.parse(json['timestamp']),
      foodNames: List<String>.from(json['food_names']),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      servingSize: json['serving_size'],
    );
  }
}

/// ===================== UI =====================

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CaloriesTrackerModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Calories Tracker'),
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt), text: 'Scan'),
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ScanFoodPage(),
          DashboardPage(),
          HistoryPage(),
        ],
      ),
    );
  }
}

class ScanFoodPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Status Card
          Card(
            child: ListTile(
              leading: model.processing
                  ? const CircularProgressIndicator()
                  : Icon(Icons.restaurant_menu,
                      color: Theme.of(context).colorScheme.primary),
              title: Text(model.status),
              subtitle:
                  model.processing ? const LinearProgressIndicator() : null,
            ),
          ),

          const SizedBox(height: 16),

          // Image Preview
          Expanded(
            flex: 2,
            child: model.imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      model.imageFile!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Take a photo of your food",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "AI will analyze and provide nutrition info",
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // Results
          if (model.detectedFoods.isNotEmpty)
            Expanded(
              flex: 1,
              child: _buildResultsSection(context, model),
            ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showImageSourceDialog(context),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Take Photo"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showImageSourceDialog(context, gallery: true),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("From Gallery"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(
      BuildContext context, CaloriesTrackerModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Detected Foods",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (model.detectedFoods.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showAddToMealDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text("Add to Meals"),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: model.detectedFoods.length,
                itemBuilder: (context, index) {
                  final food = model.detectedFoods[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${(food.percentage?.round())}%'),
                    ),
                    title: Text(food.name.toUpperCase()),
                    subtitle: food.nutrition != null
                        ? Text(
                            '${food.nutrition!.calories.round()} kcal per 100g')
                        : const Text('Fetching nutrition...'),
                    trailing: food.nutrition != null
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const CircularProgressIndicator(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context, {bool gallery = false}) {
    final model = context.read<CaloriesTrackerModel>();

    if (gallery) {
      model.pickImage(ImageSource.gallery);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                model.pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                model.pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToMealDialog(BuildContext context) {
    double servingMultiplier = 1.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add to Meal Log'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Adjust serving size:'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Serving:'),
                  Expanded(
                    child: Slider(
                      value: servingMultiplier,
                      min: 0.1,
                      max: 3.0,
                      divisions: 29,
                      label: '${(servingMultiplier * 100).round()}g',
                      onChanged: (value) {
                        setState(() {
                          servingMultiplier = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              Text('${(servingMultiplier * 100).round()}g serving'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context
                    .read<CaloriesTrackerModel>()
                    .addToMealLog(servingMultiplier: servingMultiplier);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to meal log!')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Daily Progress Cards
          Row(
            children: [
              Expanded(
                child: _buildProgressCard(
                  context,
                  'Calories',
                  model.dailyCalories,
                  model.calorieGoal,
                  Colors.orange,
                  'kcal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProgressCard(
                  context,
                  'Protein',
                  model.dailyProtein,
                  model.proteinGoal,
                  Colors.red,
                  'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildProgressCard(
                  context,
                  'Carbs',
                  model.dailyCarbs,
                  model.carbsGoal,
                  Colors.blue,
                  'g',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProgressCard(
                  context,
                  'Fat',
                  model.dailyFat,
                  model.fatGoal,
                  Colors.purple,
                  'g',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Today's Meals
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Meals",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () => _showGoalsDialog(context),
                icon: const Icon(Icons.tune),
                label: const Text('Goals'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Expanded(
            child: model.todaysMeals.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No meals logged today",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Scan food photos to start tracking",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: model.todaysMeals.length,
                    itemBuilder: (context, index) {
                      final meal = model.todaysMeals[index];
                      return _buildMealCard(context, meal, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    String label,
    double current,
    double goal,
    Color color,
    String unit,
  ) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${current.round()} / ${goal.round()}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(BuildContext context, MealEntry meal, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('${meal.calories.round()}'),
        ),
        title: Text(meal.foodNames.join(', ')),
        subtitle: Text(
          '${meal.servingSize} • ${TimeOfDay.fromDateTime(meal.timestamp).format(context)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('P: ${meal.protein.round()}g'),
                Text('C: ${meal.carbs.round()}g'),
                Text('F: ${meal.fat.round()}g'),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _confirmDeleteMeal(context, index),
              icon: const Icon(Icons.delete_outline),
              iconSize: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMeal(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: const Text(
            'Are you sure you want to remove this meal from your log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CaloriesTrackerModel>().removeMeal(index);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showGoalsDialog(BuildContext context) {
    final model = context.read<CaloriesTrackerModel>();
    final calorieController =
        TextEditingController(text: model.calorieGoal.toString());
    final proteinController =
        TextEditingController(text: model.proteinGoal.toString());
    final carbsController =
        TextEditingController(text: model.carbsGoal.toString());
    final fatController = TextEditingController(text: model.fatGoal.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Daily Goals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: calorieController,
                decoration: const InputDecoration(
                  labelText: 'Calories (kcal)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: proteinController,
                decoration: const InputDecoration(
                  labelText: 'Protein (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: carbsController,
                decoration: const InputDecoration(
                  labelText: 'Carbs (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fatController,
                decoration: const InputDecoration(
                  labelText: 'Fat (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final calories =
                  double.tryParse(calorieController.text) ?? model.calorieGoal;
              final protein =
                  double.tryParse(proteinController.text) ?? model.proteinGoal;
              final carbs =
                  double.tryParse(carbsController.text) ?? model.carbsGoal;
              final fat = double.tryParse(fatController.text) ?? model.fatGoal;

              model.updateGoals(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
              );

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Goals updated!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        context,
                        'Meals',
                        model.todaysMeals.length.toString(),
                        Icons.restaurant_menu,
                      ),
                      _buildStatColumn(
                        context,
                        'Calories',
                        '${model.dailyCalories.round()}',
                        Icons.local_fire_department,
                      ),
                      _buildStatColumn(
                        context,
                        'Goal',
                        '${((model.dailyCalories / model.calorieGoal) * 100).round()}%',
                        Icons.track_changes,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () => _exportData(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.download, size: 32),
                          SizedBox(height: 8),
                          Text('Export Data'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () => _shareProgress(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.share, size: 32),
                          SizedBox(height: 8),
                          Text('Share Progress'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () => _resetData(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.refresh, size: 32),
                          SizedBox(height: 8),
                          Text('Reset Day'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Detailed History
          Text(
            'Recent Meals',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: model.todaysMeals.isEmpty
                ? const Center(
                    child: Text('No meals recorded today'),
                  )
                : ListView.builder(
                    itemCount: model.todaysMeals.length,
                    itemBuilder: (context, index) {
                      final meal = model
                          .todaysMeals[model.todaysMeals.length - 1 - index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text('${meal.calories.round()}'),
                          ),
                          title: Text(meal.foodNames.join(', ')),
                          subtitle: Text(
                            '${meal.servingSize} • ${TimeOfDay.fromDateTime(meal.timestamp).format(context)}',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nutrition Breakdown',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildNutrientInfo(
                                          context,
                                          'Calories',
                                          '${meal.calories.round()}',
                                          'kcal',
                                          Colors.orange),
                                      _buildNutrientInfo(
                                          context,
                                          'Protein',
                                          '${meal.protein.round()}',
                                          'g',
                                          Colors.red),
                                      _buildNutrientInfo(
                                          context,
                                          'Carbs',
                                          '${meal.carbs.round()}',
                                          'g',
                                          Colors.blue),
                                      _buildNutrientInfo(
                                          context,
                                          'Fat',
                                          '${meal.fat.round()}',
                                          'g',
                                          Colors.purple),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
      BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildNutrientInfo(BuildContext context, String label, String value,
      String unit, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.circle, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text('$label ($unit)', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  void _exportData(BuildContext context) {
    final model = context.read<CaloriesTrackerModel>();

    final exportData = {
      'date': DateTime.now().toString().substring(0, 10),
      'daily_totals': {
        'calories': model.dailyCalories,
        'protein': model.dailyProtein,
        'carbs': model.dailyCarbs,
        'fat': model.dailyFat,
      },
      'goals': {
        'calories': model.calorieGoal,
        'protein': model.proteinGoal,
        'carbs': model.carbsGoal,
        'fat': model.fatGoal,
      },
      'meals': model.todaysMeals.map((m) => m.toJson()).toList(),
    };

    Clipboard.setData(ClipboardData(text: jsonEncode(exportData)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data exported to clipboard!')),
    );
  }

  void _shareProgress(BuildContext context) {
    final model = context.read<CaloriesTrackerModel>();

    final progress = '''
🍽️ My Daily Progress:
📊 Calories: ${model.dailyCalories.round()}/${model.calorieGoal.round()} kcal
🥩 Protein: ${model.dailyProtein.round()}g
🍞 Carbs: ${model.dailyCarbs.round()}g
🥑 Fat: ${model.dailyFat.round()}g
🍽️ Meals logged: ${model.todaysMeals.length}

Tracked with AI Calories Tracker 📱
    ''';

    Clipboard.setData(ClipboardData(text: progress));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress copied to clipboard!')),
    );
  }

  void _resetData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Today\'s Data'),
        content: const Text(
            'Are you sure you want to clear all meals for today? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final model = context.read<CaloriesTrackerModel>();
              model.todaysMeals.clear();
              model._updateDailyTotals();
              await model._saveTodaysData();
              // ignore: invalid_use_of_visible_for_testing_member
              model.notifyListeners();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Today\'s data has been reset')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
