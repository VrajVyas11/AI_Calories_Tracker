// lib/screens/main_page_screens/analytics_page.dart
import 'package:ai_calories_tracker/models/calories_tracker_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';


/// ------------------ AnalyticsPage (New Enhanced History) ------------------

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();
    final averageNutrients = model.getAverageNutrients();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Stats
            Text('Overview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Goal Hit Rate',
                    value: '${model.goalHitPercentage.round()}%',
                    subtitle: '${model.goalHitDays}/${model.totalTrackedDays} days',
                    icon: Icons.track_changes,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Avg Calories',
                    value: '${averageNutrients['calories']?.round() ?? 0}',
                    subtitle: 'per day',
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // Weekly Calories Chart
            Text('Weekly Calories', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 200,
                  child: _WeeklyCaloriesChart(data: model.getWeeklyCaloriesData()),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Average Nutrients
            Text('30-Day Averages', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NutrientCard(
                    label: 'Protein',
                    value: averageNutrients['protein']?.round() ?? 0,
                    goal: model.proteinGoal.round(),
                    unit: 'g',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NutrientCard(
                    label: 'Carbs',
                    value: averageNutrients['carbs']?.round() ?? 0,
                    goal: model.carbsGoal.round(),
                    unit: 'g',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NutrientCard(
                    label: 'Fat',
                    value: averageNutrients['fat']?.round() ?? 0,
                    goal: model.fatGoal.round(),
                    unit: 'g',
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GoalsSummaryCard(model: model),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Today's Summary
            Text('Today\'s Summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatColumn(
                          label: 'Meals', 
                          value: model.todaysMeals.length.toString(), 
                          icon: Icons.restaurant_menu
                        ),
                        _StatColumn(
                          label: 'Calories', 
                          value: model.dailyCalories.round().toString(), 
                          icon: Icons.local_fire_department
                        ),
                        _StatColumn(
                          label: 'Progress', 
                          value: '${((model.dailyCalories / model.calorieGoal) * 100).round()}%', 
                          icon: Icons.trending_up
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.download, 
                    label: 'Export Data', 
                    onTap: () => _exportData(context, model)
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.share, 
                    label: 'Share Progress', 
                    onTap: () => _shareProgress(context, model)
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.insights, 
                    label: 'View Goals', 
                    onTap: () => _showGoalDetails(context, model)
                  )
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Meals
            Text('Today\'s Meals', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            if (model.todaysMeals.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.restaurant_menu, size: 48, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 8),
                        Text('No meals recorded today', style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...model.todaysMeals.asMap().entries.map((entry) {
                final index = entry.key;
                final meal = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: Text('${meal.calories.round()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(meal.foodNames.join(', ')),
                    subtitle: Text('${meal.servingSize} • ${TimeOfDay.fromDateTime(meal.timestamp).format(context)}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _NutrientInfo(
                                  label: 'Calories',
                                  value: meal.calories.round().toString(),
                                  unit: 'kcal',
                                  color: Colors.orange,
                                ),
                                _NutrientInfo(
                                  label: 'Protein',
                                  value: meal.protein.round().toString(),
                                  unit: 'g',
                                  color: Colors.red,
                                ),
                                _NutrientInfo(
                                  label: 'Carbs',
                                  value: meal.carbs.round().toString(),
                                  unit: 'g',
                                  color: Colors.blue,
                                ),
                                _NutrientInfo(
                                  label: 'Fat',
                                  value: meal.fat.round().toString(),
                                  unit: 'g',
                                  color: Colors.purple,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => _confirmDeleteMeal(context, model, index),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete Meal'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _exportData(BuildContext context, CaloriesTrackerModel model) {
    final exportData = {
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'daily_totals': {
        'calories': model.dailyCalories,
        'protein': model.dailyProtein,
        'carbs': model.dailyCarbs,
        'fat': model.dailyFat
      },
      'goals': {
        'calories': model.calorieGoal,
        'protein': model.proteinGoal,
        'carbs': model.carbsGoal,
        'fat': model.fatGoal
      },
      'analytics': {
        'goal_hit_rate': model.goalHitPercentage,
        'tracked_days': model.totalTrackedDays,
        'goal_hit_days': model.goalHitDays
      },
      'meals': model.todaysMeals.map((m) => m.toJson()).toList(),
    };
    Clipboard.setData(ClipboardData(text: exportData.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data exported to clipboard'))
    );
  }

  void _shareProgress(BuildContext context, CaloriesTrackerModel model) {
    final progress = '''🔥 My Nutrition Progress

📅 Today: ${model.dailyCalories.round()}/${model.calorieGoal.round()} calories
📊 Goal Hit Rate: ${model.goalHitPercentage.round()}%
🥗 Meals Today: ${model.todaysMeals.length}

💪 Protein: ${model.dailyProtein.round()}/${model.proteinGoal.round()}g
🌾 Carbs: ${model.dailyCarbs.round()}/${model.carbsGoal.round()}g
🥑 Fat: ${model.dailyFat.round()}/${model.fatGoal.round()}g

#nutrition #health #tracking''';
    
    Clipboard.setData(ClipboardData(text: progress));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress copied to clipboard'))
    );
  }

  void _showGoalDetails(BuildContext context, CaloriesTrackerModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Goals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GoalRow(label: 'Calories', current: model.dailyCalories, goal: model.calorieGoal, unit: 'kcal'),
            _GoalRow(label: 'Protein', current: model.dailyProtein, goal: model.proteinGoal, unit: 'g'),
            _GoalRow(label: 'Carbs', current: model.dailyCarbs, goal: model.carbsGoal, unit: 'g'),
            _GoalRow(label: 'Fat', current: model.dailyFat, goal: model.fatGoal, unit: 'g'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMeal(BuildContext context, CaloriesTrackerModel model, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meal'),
        content: const Text('Are you sure you want to remove this meal from today?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              model.removeMeal(index);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Meal deleted'))
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Chart Widget
class _WeeklyCaloriesChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  
  const _WeeklyCaloriesChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text('No data available', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.isNotEmpty ? data.map((d) => (d['goal'] as double)).reduce((a, b) => a > b ? a : b) * 1.2 : 3000,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  return Text(
                    data[value.toInt()]['day'] as String,
                    style: const TextStyle(fontSize: 12),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final dayData = entry.value;
          final calories = dayData['calories'] as double;
          final goal = dayData['goal'] as double;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: calories,
                color: calories >= goal * 0.8 ? Colors.green : Colors.orange,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            )),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _NutrientCard extends StatelessWidget {
  final String label;
  final int value;
  final int goal;
  final String unit;
  final Color color;

  const _NutrientCard({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = goal > 0 ? (value / goal * 100).round() : 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text('$value$unit', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            Text('of $goal$unit', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (value / goal).clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
            const SizedBox(height: 4),
            Text('$percentage%', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _GoalsSummaryCard extends StatelessWidget {
  final CaloriesTrackerModel model;

  const _GoalsSummaryCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.track_changes, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text('Goals', style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('${model.calorieGoal.round()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            Text('kcal target', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('${model.goalHitDays}/${model.totalTrackedDays} days hit', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
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
        child: Column(children: [Icon(icon, size: 28), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center)]),
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

class _GoalRow extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final String unit;

  const _GoalRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = goal > 0 ? (current / goal * 100).round() : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('${current.round()}/${goal.round()}$unit ($percentage%)'),
        ],
      ),
    );
  }
}

extension on CaloriesTrackerModel {
  // ignore: unused_element
  void _updateDailyTotals() {
    dailyCalories = todaysMeals.fold(0, (sum, meal) => sum + meal.calories);
    dailyProtein = todaysMeals.fold(0, (sum, meal) => sum + meal.protein);
    dailyCarbs = todaysMeals.fold(0, (sum, meal) => sum + meal.carbs);
    dailyFat = todaysMeals.fold(0, (sum, meal) => sum + meal.fat);
  }
}