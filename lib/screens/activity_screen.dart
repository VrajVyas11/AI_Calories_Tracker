// lib/screens/activity_screen.dart
import 'package:flutter/material.dart';
import '../models/meal_entry.dart';
import '../services/supabase_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<MealEntry> _recentMeals = [];
  List<Map<String, dynamic>> _dailySummaries = [];
  bool _isLoading = true;
  String _selectedTimeRange = '7 days';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActivityData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadActivityData() async {
    setState(() => _isLoading = true);

    try {
      final endDate = DateTime.now();
      final startDate =
          endDate.subtract(Duration(days: _selectedTimeRange == '7 days' ? 7 : 30));

      final meals =
          await SupabaseService.getMealsForDateRange(startDate, endDate);
      final summaries =
          await SupabaseService.getDailySummaries(startDate, endDate);

      setState(() {
        _recentMeals = meals;
        _dailySummaries = summaries;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load activity data: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recent Meals', icon: Icon(Icons.restaurant)),
            Tab(text: 'Statistics', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedTimeRange,
            onSelected: (value) {
              setState(() => _selectedTimeRange = value);
              _loadActivityData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7 days', child: Text('Last 7 days')),
              const PopupMenuItem(value: '30 days', child: Text('Last 30 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedTimeRange, style: const TextStyle(fontSize: 14)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecentMealsTab(),
                _buildStatisticsTab(),
              ],
            ),
    );
  }

  Widget _buildRecentMealsTab() {
    if (_recentMeals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No meals found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Start tracking your meals to see them here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivityData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recentMeals.length,
        itemBuilder: (context, index) {
          final meal = _recentMeals[index];
          return _buildMealCard(meal);
        },
      ),
    );
  }

  Widget _buildMealCard(MealEntry meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                  child: meal.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            meal.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.restaurant,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.restaurant,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.foodNames.join(', '),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(meal.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNutrientChip(
                    'Calories',
                    '${meal.calories.toInt()}',
                    'kcal',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildNutrientChip(
                    'Protein',
                    '${meal.protein.toInt()}',
                    'g',
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildNutrientChip(
                    'Carbs',
                    '${meal.carbs.toInt()}',
                    'g',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildNutrientChip(
                    'Fat',
                    '${meal.fat.toInt()}',
                    'g',
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientChip(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    if (_dailySummaries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Track some meals to see your statistics',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Calculate totals and averages
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    int totalMeals = 0;

    for (final summary in _dailySummaries) {
      totalCalories += summary['total_calories'] as double;
      totalProtein += summary['total_protein'] as double;
      totalCarbs += summary['total_carbs'] as double;
      totalFat += summary['total_fat'] as double;
      totalMeals += summary['meal_count'] as int;
    }

    final avgCalories = totalCalories / _dailySummaries.length;
    final avgProtein = totalProtein / _dailySummaries.length;
    final avgCarbs = totalCarbs / _dailySummaries.length;
    final avgFat = totalFat / _dailySummaries.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatisticsCard(
          'Summary',
          [
            _buildStatItem('Total Calories', '${totalCalories.toInt()} kcal', Colors.orange),
            _buildStatItem('Total Meals', totalMeals.toString(), Colors.green),
            _buildStatItem('Active Days', '${_dailySummaries.length} days', Colors.blue),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatisticsCard(
          'Daily Averages',
          [
            _buildStatItem('Calories', '${avgCalories.toInt()} kcal', Colors.orange),
            _buildStatItem('Protein', '${avgProtein.toInt()} g', Colors.red),
            _buildStatItem('Carbs', '${avgCarbs.toInt()} g', Colors.blue),
            _buildStatItem('Fat', '${avgFat.toInt()} g', Colors.purple),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatisticsCard(
          'Daily Breakdown',
          _dailySummaries.map((summary) {
            final date = DateTime.parse(summary['date'] as String);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _formatDate(date),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('${summary['meal_count']} meals'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(summary['total_calories'] as double).toInt()} kcal',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'P: ${(summary['total_protein'] as double).toInt()}g | '
                    'C: ${(summary['total_carbs'] as double).toInt()}g | '
                    'F: ${(summary['total_fat'] as double).toInt()}g',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatisticsCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago at ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
    }
  }
}