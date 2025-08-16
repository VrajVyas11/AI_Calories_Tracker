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
    
    // Load analytics data when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = context.read<CaloriesTrackerModel>();
      model.loadAnalyticsData(period: '');
    });
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
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ScanFoodPage(),
          DashboardPage(),
          AnalyticsPage(),
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

/// ------------------ AnalyticsPage ------------------

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedPeriod = '7 days';
  final List<String> _periods = ['7 days', '30 days', '90 days'];

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Analytics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                items: _periods.map((period) => DropdownMenuItem(
                  value: period,
                  child: Text(period),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPeriod = value);
                    model.loadAnalyticsData(period: value);
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Overview stats
          _buildOverviewStats(model),
          
          const SizedBox(height: 20),
          
          // Goals achievement
          _buildGoalsAchievement(model),
          
          const SizedBox(height: 20),
          
          // Recent trends
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: model.isLoadingAnalytics
                ? const Center(child: CircularProgressIndicator())
                : model.dailySummaries.isEmpty
                    ? _buildEmptyState(context)
                    : _buildActivityList(model),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats(CaloriesTrackerModel model) {
    final totalDays = model.dailySummaries.length;
    final avgCalories = totalDays > 0 
        ? model.dailySummaries.map((s) => s['total_calories'] as double).reduce((a, b) => a + b) / totalDays
        : 0.0;
    final totalMeals = model.dailySummaries.fold(0, (sum, s) => sum + (s['meal_count'] as int));
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview ($_selectedPeriod)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(
                  label: 'Days Tracked',
                  value: totalDays.toString(),
                  icon: Icons.calendar_today,
                ),
                _StatColumn(
                  label: 'Avg Calories',
                  value: avgCalories.round().toString(),
                  icon: Icons.local_fire_department,
                ),
                _StatColumn(
                  label: 'Total Meals',
                  value: totalMeals.toString(),
                  icon: Icons.restaurant_menu,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsAchievement(CaloriesTrackerModel model) {
    final user = model.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    int calorieGoalDays = 0;
    int proteinGoalDays = 0;
    int carbsGoalDays = 0;
    int fatGoalDays = 0;
    
    for (final summary in model.dailySummaries) {
      final calories = summary['total_calories'] as double;
      final protein = summary['total_protein'] as double;
      final carbs = summary['total_carbs'] as double;
      final fat = summary['total_fat'] as double;
      
      if (calories >= user.calorieGoal * 0.9 && calories <= user.calorieGoal * 1.1) calorieGoalDays++;
      if (protein >= user.proteinGoal * 0.9) proteinGoalDays++;
      if (carbs >= user.carbsGoal * 0.9 && carbs <= user.carbsGoal * 1.1) carbsGoalDays++;
      if (fat >= user.fatGoal * 0.9 && fat <= user.fatGoal * 1.1) fatGoalDays++;
    }
    
    final totalDays = model.dailySummaries.length;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal Achievement',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildGoalProgress('Calories', calorieGoalDays, totalDays, Colors.orange),
            const SizedBox(height: 12),
            _buildGoalProgress('Protein', proteinGoalDays, totalDays, Colors.red),
            const SizedBox(height: 12),
            _buildGoalProgress('Carbs', carbsGoalDays, totalDays, Colors.blue),
            const SizedBox(height: 12),
            _buildGoalProgress('Fat', fatGoalDays, totalDays, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgress(String label, int achievedDays, int totalDays, Color color) {
    final percentage = totalDays > 0 ? (achievedDays / totalDays) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '$achievedDays/$totalDays days (${(percentage * 100).round()}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }
}

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Start logging meals to see your analytics',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList(CaloriesTrackerModel model) {
    return ListView.builder(
      itemCount: model.dailySummaries.length,
      itemBuilder: (context, index) {
        final summary = model.dailySummaries[index];
        final date = DateTime.parse(summary['date'] as String);
        final calories = summary['total_calories'] as double;
        final protein = summary['total_protein'] as double;
        final carbs = summary['total_carbs'] as double;
        final fat = summary['total_fat'] as double;
        final mealCount = summary['meal_count'] as int;
        
        final user = model.currentUser;
        final calorieGoal = user?.calorieGoal ?? 2000;
        final calorieProgress = calories / calorieGoal;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getProgressColor(calorieProgress).withOpacity(0.1),
              child: Text(
                '${(calorieProgress * 100).round()}%',
                style: TextStyle(
                  color: _getProgressColor(calorieProgress),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              _formatDate(date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$mealCount meals • ${calories.round()} kcal',
            ),
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
                          value: calories.round().toString(),
                          unit: 'kcal',
                          color: Colors.orange,
                        ),
                        _NutrientInfo(
                          label: 'Protein',
                          value: protein.round().toString(),
                          unit: 'g',
                          color: Colors.red,
                        ),
                        _NutrientInfo(
                          label: 'Carbs',
                          value: carbs.round().toString(),
                          unit: 'g',
                          color: Colors.blue,
                        ),
                        _NutrientInfo(
                          label: 'Fat',
                          value: fat.round().toString(),
                          unit: 'g',
                          color: Colors.purple,
                        ),
                      ],
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Goal Progress',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniProgressBar(
                              label: 'Cal',
                              current: calories,
                              goal: user.calorieGoal,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniProgressBar(
                              label: 'Pro',
                              current: protein,
                              goal: user.proteinGoal,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniProgressBar(
                              label: 'Car',
                              current: carbs,
                              goal: user.carbsGoal,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MiniProgressBar(
                              label: 'Fat',
                              current: fat,
                              goal: user.fatGoal,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.8) return Colors.red;
    if (progress < 1.2) return Colors.green;
    return Colors.orange;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';
    
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
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

class _NutrientInfo extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _NutrientInfo({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(8), 
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(8)
        ), 
        child: Icon(Icons.circle, color: color, size: 16)
      ),
      const SizedBox(height: 6),
      Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      Text('$label ($unit)', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _MiniProgressBar extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;
  
  const _MiniProgressBar({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation(color),
        ),
        const SizedBox(height: 2),
        Text(
          '${(progress * 100).round()}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}