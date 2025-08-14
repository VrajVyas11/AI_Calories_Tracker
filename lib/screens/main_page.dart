// lib/screens/main_page.dart
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'package:ai_calories_tracker/models/calories_tracker_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/meal_entry.dart';
import '../screens/scan_food_page.dart';
import '../widgets/user_profile_sheet.dart';



/// ------------------ UI / MainPage ------------------

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Calories Tracker'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () => _showProfileSheet(context),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: model.currentUser != null
                    ? Text(_initials(model.currentUser!.fullName))
                    : const Icon(Icons.person_outline),
              ),
            ),
          ),
        ],
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
        children: const [
          ScanFoodPage(),
          DashboardPage(),
          HistoryPage(),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    final model = context.read<CaloriesTrackerModel>();
    showModalBottomSheet(
      context: context,
      builder: (_) => UserProfileSheet(user: model.currentUser, onSignOut: () async {
        await model.signOut();
        Navigator.of(context).pushReplacementNamed('/auth');
      }),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// ------------------ DashboardPage ------------------

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Progress row
          Row(
            children: [
              Expanded(
                child: _ProgressCard(
                  label: 'Calories',
                  current: model.dailyCalories,
                  goal: model.currentUser?.calorieGoal ?? 2000,
                  color: Colors.orange,
                  unit: 'kcal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProgressCard(
                  label: 'Protein',
                  current: model.dailyProtein,
                  goal: model.currentUser?.proteinGoal ?? 150,
                  color: Colors.red,
                  unit: 'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ProgressCard(
                  label: 'Carbs',
                  current: model.dailyCarbs,
                  goal: model.currentUser?.carbsGoal ?? 250,
                  color: Colors.blue,
                  unit: 'g',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProgressCard(
                  label: 'Fat',
                  current: model.dailyFat,
                  goal: model.currentUser?.fatGoal ?? 67,
                  color: Colors.purple,
                  unit: 'g',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Today's Meals header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Meals", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                        Icon(Icons.restaurant_menu_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        Text('No meals logged today', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Scan food photos to start tracking', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: model.todaysMeals.length,
                    itemBuilder: (context, index) => _MealCard(meal: model.todaysMeals[index], index: index),
                  ),
          ),
        ],
      ),
    );
  }

  void _showGoalsDialog(BuildContext context) {
    final model = context.read<CaloriesTrackerModel>();
    final calorieController = TextEditingController(text: (model.currentUser?.calorieGoal ?? 2000).toString());
    final proteinController = TextEditingController(text: (model.currentUser?.proteinGoal ?? 150).toString());
    final carbsController = TextEditingController(text: (model.currentUser?.carbsGoal ?? 250).toString());
    final fatController = TextEditingController(text: (model.currentUser?.fatGoal ?? 67).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Daily Goals'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: calorieController, decoration: const InputDecoration(labelText: 'Calories (kcal)')),
              const SizedBox(height: 8),
              TextField(controller: proteinController, decoration: const InputDecoration(labelText: 'Protein (g)')),
              const SizedBox(height: 8),
              TextField(controller: carbsController, decoration: const InputDecoration(labelText: 'Carbs (g)')),
              const SizedBox(height: 8),
              TextField(controller: fatController, decoration: const InputDecoration(labelText: 'Fat (g)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final calories = double.tryParse(calorieController.text) ?? (model.currentUser?.calorieGoal ?? 2000);
              final protein = double.tryParse(proteinController.text) ?? (model.currentUser?.proteinGoal ?? 150);
              final carbs = double.tryParse(carbsController.text) ?? (model.currentUser?.carbsGoal ?? 250);
              final fat = double.tryParse(fatController.text) ?? (model.currentUser?.fatGoal ?? 67);

              model.updateGoals(calories: calories, protein: protein, carbs: carbs, fat: fat);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;
  final String unit;
  const _ProgressCard({required this.label, required this.current, required this.goal, required this.color, required this.unit});

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Text('${current.round()} / ${goal.round()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(unit, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, backgroundColor: color.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(color)),
          const SizedBox(height: 4),
          Text('${(progress * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

/// ------------------ HistoryPage ------------------

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Today\'s Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _StatColumn(label: 'Meals', value: model.todaysMeals.length.toString(), icon: Icons.restaurant_menu),
                _StatColumn(label: 'Calories', value: model.dailyCalories.round().toString(), icon: Icons.local_fire_department),
                _StatColumn(label: 'Goal %', value: ((model.dailyCalories / (model.currentUser?.calorieGoal ?? 2000) * 100).round()).toString() + '%', icon: Icons.track_changes),
              ]),
            ]),
          ),
        ),

        const SizedBox(height: 12),

        // Quick Actions row
        Row(children: [
          Expanded(child: _QuickActionCard(icon: Icons.download, label: 'Export Data', onTap: () => _exportData(context))),
          const SizedBox(width: 8),
          Expanded(child: _QuickActionCard(icon: Icons.share, label: 'Share Progress', onTap: () => _shareProgress(context))),
          const SizedBox(width: 8),
          Expanded(child: _QuickActionCard(icon: Icons.refresh, label: 'Reset Day', onTap: () => _resetData(context))),
        ]),

        const SizedBox(height: 12),

        Text('Recent Meals', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        Expanded(
          child: model.todaysMeals.isEmpty
              ? const Center(child: Text('No meals recorded today'))
              : ListView.builder(
                  itemCount: model.todaysMeals.length,
                  itemBuilder: (context, index) {
                    final meal = model.todaysMeals[model.todaysMeals.length - 1 - index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(child: Text('${meal.calories.round()}')),
                        title: Text(meal.foodNames.join(', ')),
                        subtitle: Text('${meal.servingSize} • ${TimeOfDay.fromDateTime(meal.timestamp).format(context)}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                              _NutrientInfo(label: 'Calories', value: meal.calories.round().toString(), unit: 'kcal', color: Colors.orange),
                              _NutrientInfo(label: 'Protein', value: meal.protein.round().toString(), unit: 'g', color: Colors.red),
                              _NutrientInfo(label: 'Carbs', value: meal.carbs.round().toString(), unit: 'g', color: Colors.blue),
                              _NutrientInfo(label: 'Fat', value: meal.fat.round().toString(), unit: 'g', color: Colors.purple),
                            ]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _exportData(BuildContext context) {
    final model = context.read<CaloriesTrackerModel>();
    final exportData = {
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'daily_totals': {'calories': model.dailyCalories, 'protein': model.dailyProtein, 'carbs': model.dailyCarbs, 'fat': model.dailyFat},
      'meals': model.todaysMeals.map((m) => m.toJson()).toList(),
    };
    Clipboard.setData(ClipboardData(text: exportData.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported to clipboard')));
  }

  void _shareProgress(BuildContext context) {
    final model = context.read<CaloriesTrackerModel>();
    final progress = 'Calories: ${model.dailyCalories.round()}/${(model.currentUser?.calorieGoal ?? 2000).round()} kcal\nMeals: ${model.todaysMeals.length}';
    Clipboard.setData(ClipboardData(text: progress));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress copied')));
  }

  void _resetData(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Reset Today'),
      content: const Text('Clear all meals for today?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          Navigator.pop(context);
          final model = context.read<CaloriesTrackerModel>();
          // Clear local list and server entries (simple approach: remove via SupabaseService if needed)
          model.todaysMeals.clear();
          model._updateDailyTotals();
          // Ideally call Supabase to delete today's meals (not included here)
          model.notifyListeners();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Today reset')));
        }, child: const Text('Reset')),
      ],
    ));
  }
}

extension on CaloriesTrackerModel {
  
  void _updateDailyTotals() {
    dailyCalories = todaysMeals.fold(0, (sum, meal) => sum + meal.calories);
    dailyProtein = todaysMeals.fold(0, (sum, meal) => sum + meal.protein);
    dailyCarbs = todaysMeals.fold(0, (sum, meal) => sum + meal.carbs);
    dailyFat = todaysMeals.fold(0, (sum, meal) => sum + meal.fat);
  }
}

/// Small UI components

class _MealCard extends StatelessWidget {
  final MealEntry meal;
  final int index;
  const _MealCard({required this.meal, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${meal.calories.round()}')),
        title: Text(meal.foodNames.join(', ')),
        subtitle: Text('${meal.servingSize} • ${TimeOfDay.fromDateTime(meal.timestamp).format(context)}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('P: ${meal.protein.round()}g'),
            Text('C: ${meal.carbs.round()}g'),
            Text('F: ${meal.fat.round()}g'),
          ]),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Meal'),
      content: const Text('Remove this meal?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          Navigator.pop(ctx);
          // Notify model to remove by index — this requires mapping index; here we call removeMeal via provider
          final model = context.read<CaloriesTrackerModel>();
          model.removeMeal(index);
        }, child: const Text('Delete')),
      ],
    ));
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatColumn({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 6),
      Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(onTap: onTap, child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [Icon(icon, size: 28), const SizedBox(height: 8), Text(label)]),
      )),
    );
  }
}

class _NutrientInfo extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _NutrientInfo({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.circle, color: color, size: 16)),
      const SizedBox(height: 6),
      Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      Text('$label ($unit)', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}