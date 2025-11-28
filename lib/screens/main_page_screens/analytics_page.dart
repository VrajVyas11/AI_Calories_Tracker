import 'package:ai_calories_tracker/models/calories_tracker_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/supabase_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedTimeRange = '7 days';
  final List<String> _timeRangeOptions = [
    '7 days',
    '30 days',
    '90 days',
    'All time'
  ];
  bool _isLoading = true;
  List<Map<String, dynamic>> _dailySummaries = [];

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Duration _getDurationForTimeRange(String range) {
    switch (range) {
      case '7 days':
        return const Duration(days: 7);
      case '30 days':
        return const Duration(days: 30);
      case '90 days':
        return const Duration(days: 90);
      case 'All time':
        return const Duration(days: 365 * 10);
      default:
        return const Duration(days: 7);
    }
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      final endDate = DateTime.now();
      final duration = _getDurationForTimeRange(_selectedTimeRange);
      final startDate = _selectedTimeRange == 'All time' 
          ? DateTime(2020)
          : endDate.subtract(duration);

      final summaries = await SupabaseService.getDailySummaries(startDate, endDate);

      setState(() {
        _dailySummaries = summaries;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics data: ${e.toString()}')),
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
    final model = context.watch<CaloriesTrackerModel>();
    final stats = _calculateEnhancedStatistics(model);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTimeRangeSelector(),
          const SizedBox(height: 16),
          if (_isLoading)
            const LinearProgressIndicator()
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewStats(stats),
                    const SizedBox(height: 16),
                    _buildCaloriesChart(model),
                    const SizedBox(height: 16),
                    _buildNutritionAverages(stats, model),
                    const SizedBox(height: 16),
                    _buildGoalPerformance(stats),
                    const SizedBox(height: 16),
                    _buildTodaysSummary(model),
                    const SizedBox(height: 16),
                    _buildQuickActions(context, model),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 8),
            const Text('Time Range:'),
            const Spacer(),
            DropdownButton<String>(
              value: _selectedTimeRange,
              onChanged: (value) {
                setState(() {
                  _selectedTimeRange = value!;
                });
                _loadAnalyticsData();
              },
              items: _timeRangeOptions.map((String range) {
                return DropdownMenuItem<String>(
                  value: range,
                  child: Text(range),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateEnhancedStatistics(CaloriesTrackerModel model) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    int totalMeals = 0;
    int goalHitDays = 0;
    int underGoalDays = 0;
    int overGoalDays = 0;

    for (final summary in _dailySummaries) {
      final dayCalories = summary['total_calories'] as double;
      final dayProtein = summary['total_protein'] as double;
      final dayCarbs = summary['total_carbs'] as double;
      final dayFat = summary['total_fat'] as double;

      totalCalories += dayCalories;
      totalProtein += dayProtein;
      totalCarbs += dayCarbs;
      totalFat += dayFat;
      totalMeals += summary['meal_count'] as int;

      if (dayCalories >= model.calorieGoal * 0.9 && dayCalories <= model.calorieGoal * 1.1) {
        goalHitDays++;
      } else if (dayCalories < model.calorieGoal * 0.9) {
        underGoalDays++;
      } else {
        overGoalDays++;
      }
    }

    final days = _dailySummaries.length;
    final avgCalories = days > 0 ? totalCalories / days : 0;
    final avgProtein = days > 0 ? totalProtein / days : 0;
    final avgCarbs = days > 0 ? totalCarbs / days : 0;
    final avgFat = days > 0 ? totalFat / days : 0;

    return {
      'totalCalories': totalCalories,
      'totalMeals': totalMeals,
      'activeDays': days,
      'avgCalories': avgCalories,
      'avgProtein': avgProtein,
      'avgCarbs': avgCarbs,
      'avgFat': avgFat,
      'goalHitDays': goalHitDays,
      'underGoalDays': underGoalDays,
      'overGoalDays': overGoalDays,
      'goalHitRate': days > 0 ? (goalHitDays / days) * 100 : 0,
    };
  }

  Widget _buildOverviewStats(Map<String, dynamic> stats) {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Goal Hit Rate',
              value: '${stats['goalHitRate'].round()}%',
              subtitle: '${stats['goalHitDays']}/${stats['activeDays']} days',
              icon: Icons.track_changes,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              title: 'Avg Calories',
              value: '${stats['avgCalories']?.round() ?? 0}',
              subtitle: 'per day',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              title: 'Active Days',
              value: '${stats['activeDays']}',
              subtitle: 'total tracked',
              icon: Icons.calendar_today,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildCaloriesChart(CaloriesTrackerModel model) {
  final chartData = _getChartData();
  
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
                'Calories Trend - $_selectedTimeRange',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (chartData.isNotEmpty)
                Chip(
                  label: Text('${chartData.length} days'),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: chartData.isEmpty 
                ? _buildEmptyChartState()
                : chartData.length > 14 
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartData.length * 40.0, // Adjust width based on data count
                          child: _CaloriesBarChart(data: chartData, model: model),
                        ),
                      )
                    : _CaloriesBarChart(data: chartData, model: model),
          ),
          if (chartData.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildChartLegend(),
          ],
        ],
      ),
    ),
  );
}

Widget _buildChartLegend() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          const Text('On Target', style: TextStyle(fontSize: 10)),
        ],
      ),
      Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          const Text('Under Goal', style: TextStyle(fontSize: 10)),
        ],
      ),
      Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          const Text('Over Goal', style: TextStyle(fontSize: 10)),
        ],
      ),
    ],
  );
}
List<Map<String, dynamic>> _getChartData() {
  if (_dailySummaries.isEmpty) return [];

  return _dailySummaries.map((summary) {
    final date = DateTime.parse(summary['date'] as String);
    
    String displayLabel;
    if (_selectedTimeRange == '7 days') {
      // For 7 days, show day names
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      displayLabel = dayNames[date.weekday - 1];
    } else if (_selectedTimeRange == '30 days') {
      // For 30 days, show day numbers
      displayLabel = '${date.day}';
    } else {
      // For longer ranges, show month/day
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      displayLabel = '${months[date.month - 1]} ${date.day}';
    }
    
    return {
      'day': displayLabel,
      'calories': (summary['total_calories'] as num?)?.toDouble() ?? 0,
      'date': date,
    };
  }).toList();
}

  Widget _buildEmptyChartState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No data available for chart',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track meals to see your progress',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionAverages(Map<String, dynamic> stats, CaloriesTrackerModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_selectedTimeRange Averages',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (_dailySummaries.isEmpty)
              _buildNoDataState('No nutrition data available')
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NutrientCard(
                          label: 'Protein',
                          value: stats['avgProtein']?.round() ?? 0,
                          goal: model.proteinGoal.round(),
                          unit: 'g',
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _NutrientCard(
                          label: 'Carbs',
                          value: stats['avgCarbs']?.round() ?? 0,
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
                          value: stats['avgFat']?.round() ?? 0,
                          goal: model.fatGoal.round(),
                          unit: 'g',
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GoalsSummaryCard(model: model, stats: stats),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalPerformance(Map<String, dynamic> stats) {
    final goalHitRate = stats['goalHitRate'];
    final remaining = (100 - goalHitRate).clamp(0, 100);
    final underRate = remaining * 0.4;
    final overRate = remaining * 0.6;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (stats['activeDays'] == 0)
              _buildNoDataState('No goal performance data yet')
            else
              SizedBox(
                height: 100,
                child: Row(
                  children: [
                    _PerformanceCircle(
                      label: 'On Target',
                      percentage: goalHitRate,
                      color: Colors.green,
                    ),
                    _PerformanceCircle(
                      label: 'Under',
                      percentage: underRate,
                      color: Colors.blue,
                    ),
                    _PerformanceCircle(
                      label: 'Over',
                      percentage: overRate,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysSummary(CaloriesTrackerModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(
                      label: 'Meals',
                      value: model.todaysMeals.length.toString(),
                      icon: Icons.restaurant_menu),
                  _StatColumn(
                      label: 'Calories',
                      value: model.dailyCalories.round().toString(),
                      icon: Icons.local_fire_department),
                  _StatColumn(
                      label: 'Progress',
                      value: model.calorieGoal > 0
                          ? '${((model.dailyCalories / model.calorieGoal) * 100).round()}%'
                          : '0%',
                      icon: Icons.trending_up),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, CaloriesTrackerModel model) {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
              child: _QuickActionCard(
                  icon: Icons.copy,
                  label: 'Copy Data To Clipboard',
                  onTap: () => _exportData(context, model))),
          const SizedBox(width: 8),
          Expanded(
              child: _QuickActionCard(
                  icon: Icons.share,
                  label: 'Share Progress',
                  onTap: () => _shareProgress(context, model))),
          const SizedBox(width: 8),
          Expanded(
              child: _QuickActionCard(
                  icon: Icons.insights,
                  label: 'View Goals',
                  onTap: () => _showGoalDetails(context, model))),
        ],
      ),
    );
  }

  // String _formatTime(DateTime dateTime) {
  //   final hour = dateTime.hour;
  //   final minute = dateTime.minute;
  //   final period = hour >= 12 ? 'PM' : 'AM';
  //   final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  //   return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  // }

  void _exportData(BuildContext context, CaloriesTrackerModel model) {
    final stats = _calculateEnhancedStatistics(model);
    final dailyTotals = {
      'calories': model.dailyCalories,
      'protein': model.dailyProtein,
      'carbs': model.dailyCarbs,
      'fat': model.dailyFat
    };
    final goals = {
      'calories': model.calorieGoal,
      'protein': model.proteinGoal,
      'carbs': model.carbsGoal,
      'fat': model.fatGoal
    };

    final exportText = '''
Nutrition Data Export
Date: ${DateTime.now().toIso8601String().substring(0, 10)}
Time Range: $_selectedTimeRange

Today's Totals:
- Calories: ${dailyTotals['calories']?.round() ?? 0} kcal
- Protein: ${dailyTotals['protein']?.round() ?? 0} g
- Carbs: ${dailyTotals['carbs']?.round() ?? 0} g
- Fat: ${dailyTotals['fat']?.round() ?? 0} g

Goals:
- Calories: ${goals['calories']?.round() ?? 0} kcal
- Protein: ${goals['protein']?.round() ?? 0} g
- Carbs: ${goals['carbs']?.round() ?? 0} g
- Fat: ${goals['fat']?.round() ?? 0} g

Analytics:
- Goal Hit Rate: ${stats['goalHitRate']?.round() ?? 0}%
- Tracked Days: ${stats['activeDays'] ?? 0}
- Goal Hit Days: ${stats['goalHitDays'] ?? 0}
- Meals Today: ${model.todaysMeals.length}
''';
    Clipboard.setData(ClipboardData(text: exportText));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data exported to clipboard')));
  }

  void _shareProgress(BuildContext context, CaloriesTrackerModel model) {
    final stats = _calculateEnhancedStatistics(model);
    final progress = '''🔥 My Nutrition Progress - $_selectedTimeRange

📅 Today: ${model.dailyCalories.round()}/${model.calorieGoal.round()} calories
📊 Goal Hit Rate: ${stats['goalHitRate'].round()}%
🥗 Meals Today: ${model.todaysMeals.length}

💪 Protein: ${model.dailyProtein.round()}/${model.proteinGoal.round()}g
🌾 Carbs: ${model.dailyCarbs.round()}/${model.carbsGoal.round()}g
🥑 Fat: ${model.dailyFat.round()}/${model.fatGoal.round()}g

#NutritionTracker #HealthGoals''';

    Clipboard.setData(ClipboardData(text: progress));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress copied to clipboard')));
  }

  void _showGoalDetails(BuildContext context, CaloriesTrackerModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Nutrition Goals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GoalRow(
                  label: 'Calories',
                  current: model.dailyCalories,
                  goal: model.calorieGoal,
                  unit: 'kcal'),
              _GoalRow(
                  label: 'Protein',
                  current: model.dailyProtein,
                  goal: model.proteinGoal,
                  unit: 'g'),
              _GoalRow(
                  label: 'Carbs',
                  current: model.dailyCarbs,
                  goal: model.carbsGoal,
                  unit: 'g'),
              _GoalRow(
                  label: 'Fat',
                  current: model.dailyFat,
                  goal: model.fatGoal,
                  unit: 'g'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Goal hit ${model.goalHitDays} out of ${model.totalTrackedDays} days',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
}

class _CaloriesBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final CaloriesTrackerModel model;

  const _CaloriesBarChart({
    required this.data,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    final maxCalories = data.isNotEmpty 
        ? data.map((d) => (d['calories'] as num).toDouble()).reduce((a, b) => a > b ? a : b)
        : 0;
    final maxY = (maxCalories > model.calorieGoal ? maxCalories : model.calorieGoal) * 1.2;

    // Calculate bar width based on data count
    final barWidth = data.length > 14 ? 8.0 : 16.0;
    final groupsSpace = data.length > 14 ? 4.0 : 12.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        groupsSpace: groupsSpace,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final dayData = data[groupIndex];
              final day = dayData['day'];
              final date = dayData['date'] as DateTime;
              final calories = rod.toY.round();
              
              String tooltipText;
              if (_selectedTimeRange == '7 days') {
                tooltipText = '$day\n$calories kcal';
              } else {
                final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                tooltipText = '${months[date.month - 1]} ${date.day}\n$calories kcal';
              }
              
              return BarTooltipItem(
                tooltipText,
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: data.length > 14 ? 20 : 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < data.length) {
                  final label = data[value.toInt()]['day'].toString();
                  
                  // For longer data sets, show fewer labels to avoid crowding
                  if (data.length > 14) {
                    // Show every 3rd label for better readability
                    if (value.toInt() % 3 != 0) {
                      return const SizedBox.shrink();
                    }
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: data.length > 14 ? 8 : 10,
                        fontWeight: data.length > 14 ? FontWeight.normal : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY > 0 ? maxY / 5 : 500,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: data.length > 14 ? 8 : 10,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 5 : 500,
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final dayData = entry.value;
          final calories = (dayData['calories'] as num).toDouble();
          final isOverGoal = calories > model.calorieGoal;
          final isUnderGoal = calories < model.calorieGoal * 0.8;
          
          Color barColor;
          if (isOverGoal) {
            barColor = Colors.orange;
          } else if (isUnderGoal) {
            barColor = Colors.blue;
          } else {
            barColor = Colors.green;
          }

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: calories,
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
                color: barColor,
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: model.calorieGoal,
                  color: Colors.grey.withOpacity(0.1),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

String get _selectedTimeRange {
  // This getter is needed to access the current selected time range in the chart widget
  return _selectedTimeRange;
}

class _PerformanceCircle extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;

  const _PerformanceCircle({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 8,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(
                '${percentage.round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 12,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 18,
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
            ),
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
    final progressValue = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text('$value$unit',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            Text('of $goal$unit', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressValue,
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
  final Map<String, dynamic> stats;

  const _GoalsSummaryCard({required this.model, required this.stats});

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
            Text('${model.calorieGoal.round()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            Text('kcal target', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('${stats['goalHitDays']}/${stats['activeDays']} days hit',
                style: Theme.of(context).textTheme.bodySmall),
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
  const _StatColumn(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                )),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 24, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
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
    final isOnTrack = percentage >= 80 && percentage <= 120;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isOnTrack
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isOnTrack ? Colors.green : Colors.orange,
            ),
          ),
          Text(
            '${current.round()}/${goal.round()}$unit ($percentage%)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isOnTrack ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}