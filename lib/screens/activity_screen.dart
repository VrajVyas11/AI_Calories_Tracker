import 'package:flutter/material.dart';
import '../models/meal_entry.dart';
import '../services/supabase_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:open_file/open_file.dart';

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
  bool _isExporting = false;
  String _selectedTimeRange = '7 days';

  // Enhanced time range options
  final List<String> _timeRangeOptions = [
    '24 hours',
    '7 days',
    '30 days',
    '90 days',
    '6 months',
    '1 year',
    'All time'
  ];

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

  Duration _getDurationForTimeRange(String range) {
    switch (range) {
      case '24 hours':
        return const Duration(hours: 24);
      case '7 days':
        return const Duration(days: 7);
      case '30 days':
        return const Duration(days: 30);
      case '90 days':
        return const Duration(days: 90);
      case '6 months':
        return const Duration(days: 180);
      case '1 year':
        return const Duration(days: 365);
      case 'All time':
        return const Duration(days: 365 * 10); // 10 years as "all time"
      default:
        return const Duration(days: 7);
    }
  }

  Future<void> _loadActivityData() async {
    setState(() => _isLoading = true);
    try {
      final endDate = DateTime.now();
      final duration = _getDurationForTimeRange(_selectedTimeRange);
      final startDate = _selectedTimeRange == 'All time'
          ? DateTime(2020) // Very early date to get all data
          : endDate.subtract(duration);
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
        title: const Text('Activity & Statistics'),
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
            itemBuilder: (context) => _timeRangeOptions.map((range) {
              return PopupMenuItem(
                value: range,
                child: Text(range),
              );
            }).toList(),
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
      return _buildEmptyState(
        icon: Icons.restaurant_menu,
        title: 'No meals found',
        subtitle: 'Start tracking your meals to see them here',
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

  Widget _buildStatisticsTab() {
    if (_dailySummaries.isEmpty) {
      return _buildEmptyState(
        icon: Icons.analytics,
        title: 'No data available',
        subtitle: 'Track some meals to see your statistics',
      );
    }
    // Calculate enhanced statistics
    final stats = _calculateEnhancedStatistics();
    return RefreshIndicator(
      onRefresh: _loadActivityData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Stats Cards
          _buildQuickStats(stats),
          const SizedBox(height: 16),
          // Nutrition Averages
          _buildNutritionAverages(stats),
          const SizedBox(height: 16),
          // Goal Performance
          _buildGoalPerformance(stats),
          const SizedBox(height: 16),
          // Daily Breakdown
          _buildDailyBreakdown(),
          const SizedBox(height: 24),
          // Export Section
          _buildExportSection(),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateEnhancedStatistics() {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    int totalMeals = 0;
    int goalHitDays = 0;
    int underGoalDays = 0;
    int overGoalDays = 0;
    // Assuming average goals for calculation (in real app, use user's actual goals)
    const double calorieGoal = 2000;
    // const double proteinGoal = 150;
    // const double carbsGoal = 250;
    // const double fatGoal = 67;
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
      // Goal performance
      if (dayCalories >= calorieGoal * 0.9 && dayCalories <= calorieGoal * 1.1) {
        goalHitDays++;
      } else if (dayCalories < calorieGoal * 0.9) {
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

  Widget _buildQuickStats(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _QuickStatItem(
                  label: 'Total Calories',
                  value: '${stats['totalCalories'].round()}',
                  unit: 'kcal',
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _QuickStatItem(
                  label: 'Meals Tracked',
                  value: '${stats['totalMeals']}',
                  unit: 'meals',
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _QuickStatItem(
                  label: 'Active Days',
                  value: '${stats['activeDays']}',
                  unit: 'days',
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _QuickStatItem(
                  label: 'Goal Hit Rate',
                  value: '${stats['goalHitRate'].round()}',
                  unit: '%',
                  color: Colors.purple,
                ),
                const SizedBox(width: 12),
                _QuickStatItem(
                  label: 'Avg Daily',
                  value: '${stats['avgCalories'].round()}',
                  unit: 'kcal',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionAverages(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Averages',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NutrientProgress(
                    label: 'Protein',
                    value: stats['avgProtein'],
                    goal: 150, // Use actual user goal in real implementation
                    unit: 'g',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NutrientProgress(
                    label: 'Carbs',
                    value: stats['avgCarbs'],
                    goal: 250,
                    unit: 'g',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NutrientProgress(
                    label: 'Fat',
                    value: stats['avgFat'],
                    goal: 67,
                    unit: 'g',
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Performance',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stats['goalHitDays']}/${stats['activeDays']} days',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'within target',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalPerformance(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            Row(
              children: [
                Expanded(
                  child: _PerformanceIndicator(
                    label: 'On Target',
                    count: stats['goalHitDays'],
                    total: stats['activeDays'],
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PerformanceIndicator(
                    label: 'Under Goal',
                    count: stats['underGoalDays'],
                    total: stats['activeDays'],
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PerformanceIndicator(
                    label: 'Over Goal',
                    count: stats['overGoalDays'],
                    total: stats['activeDays'],
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Breakdown',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_dailySummaries.length} days',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._dailySummaries.take(10).map((summary) {
              final date = DateTime.parse(summary['date'] as String);
              return _DailySummaryTile(summary: summary, date: date);
            }).toList(),
            if (_dailySummaries.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${_dailySummaries.length - 10} more days',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Export your nutrition data for $_selectedTimeRange',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Includes ${_dailySummaries.length} days and ${_recentMeals.length} meals',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_dailySummaries.isEmpty && _recentMeals.isEmpty) || _isExporting
                        ? null
                        : () => _exportData(context, ExportFormat.csv),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: _isExporting ? const Text('Exporting...') : const Text('Export CSV'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_dailySummaries.isEmpty && _recentMeals.isEmpty) || _isExporting
                        ? null
                        : () => _exportData(context, ExportFormat.json),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.code),
                    label: _isExporting ? const Text('Exporting...') : const Text('Export JSON'),
                  ),
                ),
              ],
            ),
            if (_dailySummaries.isEmpty && _recentMeals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'No data available for export',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
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
                _NutrientChip(
                    label: 'Calories', value: '${meal.calories.toInt()}', unit: 'kcal', color: Colors.orange),
                _NutrientChip(
                  label: 'Protein', value: '${meal.protein.toInt()}', unit: 'g', color: Colors.red),
                _NutrientChip(
                  label: 'Carbs', value: '${meal.carbs.toInt()}', unit: 'g', color: Colors.blue),
                _NutrientChip(
                   label: 'Fat', value: '${meal.fat.toInt()}', unit: 'g', color: Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, ExportFormat format) async {
    setState(() => _isExporting = true);
    try {
      final data = await _prepareExportData();
     
      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data available to export')),
          );
        }
        return;
      }
      String exportContent;
      String fileName;
      String mimeType;
      if (format == ExportFormat.csv) {
        exportContent = _convertToCsv(data);
        fileName = 'nutrition_data_${_getFormattedTimestamp()}.csv';
        mimeType = 'text/csv';
      } else {
        exportContent = _convertToJson(data);
        fileName = 'nutrition_data_${_getFormattedTimestamp()}.json';
        mimeType = 'application/json';
      }
      await _saveFile(context, exportContent, fileName, mimeType);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _prepareExportData() async {
    final List<Map<String, dynamic>> exportData = [];
    // Add daily summaries
    for (final summary in _dailySummaries) {
      exportData.add({
        'type': 'daily_summary',
        'date': summary['date'],
        'total_calories': summary['total_calories'],
        'total_protein': summary['total_protein'],
        'total_carbs': summary['total_carbs'],
        'total_fat': summary['total_fat'],
        'meal_count': summary['meal_count'],
        'export_timestamp': DateTime.now().toIso8601String(),
      });
    }
    // Add individual meals
    for (final meal in _recentMeals) {
      exportData.add({
        'type': 'meal',
        'id': meal.id,
        'timestamp': meal.timestamp.toIso8601String(),
        'food_names': meal.foodNames.join('; '),
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fat': meal.fat,
        'serving_size': meal.servingSize,
        'export_timestamp': DateTime.now().toIso8601String(),
      });
    }
    return exportData;
  }

  String _convertToCsv(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return '';
    // Get all unique keys from all data entries
    final allKeys = <String>{};
    for (final entry in data) {
      allKeys.addAll(entry.keys);
    }
    final headers = allKeys.toList()..sort();
    final csvBuffer = StringBuffer();
    // Write headers
    csvBuffer.write(headers.map(_escapeCsvField).join(','));
    csvBuffer.write('\n');
    // Write data rows
    for (final entry in data) {
      final row = headers.map((header) {
        final value = entry[header];
        return _escapeCsvField(value?.toString() ?? '');
      }).join(',');
      csvBuffer.write(row);
      csvBuffer.write('\n');
    }
    return csvBuffer.toString();
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  String _convertToJson(List<Map<String, dynamic>> data) {
    final exportObject = {
      'export_info': {
        'exported_at': DateTime.now().toIso8601String(),
        'time_range': _selectedTimeRange,
        'total_records': data.length,
        'daily_summaries_count': _dailySummaries.length,
        'meals_count': _recentMeals.length,
      },
      'data': data,
    };
    // Format JSON with indentation for readability
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(exportObject);
  }

  String _getFormattedTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveFile(BuildContext context, String content, String fileName, String mimeType) async {
    try {
      Directory? directory;
      String dirName;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
          dirName = 'External Storage';
        } else {
          dirName = 'Downloads';
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
        dirName = 'Documents';
      } else {
        directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        dirName = directory.path.contains('Download') ? 'Downloads' : 'Documents';
      }
      if (directory == null) {
        throw Exception('Could not access any directory');
      }
      // Create the file
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      // Verify file creation
      if (!await file.exists()) {
        throw Exception('Failed to create file');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to $dirName: $fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                // Show a dialog with file location and options
                _showFileSavedDialog(context, file.path, fileName, dirName);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('File saved to: ${file.path}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Copy to Clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
    }
  }

  void _showFileSavedDialog(BuildContext context, String filePath, String fileName, String dirName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Saved Successfully'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $fileName'),
            const SizedBox(height: 8),
            Text(
              'Location: $dirName',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              'The file has been saved to your $dirName folder.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Optionally open the file if possible
              _tryOpenFile(filePath);
            },
            child: const Text('Open File'),
          ),
        ],
      ),
    );
  }

  void _tryOpenFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
     
      if (result.type != ResultType.done) {
        print('Could not open file: ${result.message}');
        // You could show a snackbar here if you have context
      }
    } catch (e) {
      print('Error opening file: $e');
    }
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
}

// Helper Widgets
class _QuickStatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _QuickStatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientProgress extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final String unit;
  final Color color;

  const _NutrientProgress({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
   
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text('${value.round()}$unit', style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
          Text('of ${goal.round()}$unit', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          const SizedBox(height: 4),
          Text('${(percentage * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PerformanceIndicator extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _PerformanceIndicator({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total) * 100 : 0;
   
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          Text(
            '${percentage.round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySummaryTile extends StatelessWidget {
  final Map<String, dynamic> summary;
  final DateTime date;

  const _DailySummaryTile({
    required this.summary,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '${(summary['total_calories'] as double).toInt()}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
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
            'C: ${(summary['total_carbs'] as double).toInt()}g',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
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
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
    }
  }
}

class _NutrientChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _NutrientChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {

    return Expanded(
      child: Container(
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
              style: const TextStyle(
                fontSize: 10,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ExportFormat { csv, json }