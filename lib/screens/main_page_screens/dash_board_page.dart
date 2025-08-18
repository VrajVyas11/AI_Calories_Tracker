// lib/screens/main_page_screens/dash_board_page.dart
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member, deprecated_member_use
import 'package:ai_calories_tracker/models/calories_tracker_model.dart';
import 'package:ai_calories_tracker/models/meal_entry.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
          final model = context.read<CaloriesTrackerModel>();
          model.removeMeal(index);
        }, child: const Text('Delete')),
      ],
    ));
  }
}

