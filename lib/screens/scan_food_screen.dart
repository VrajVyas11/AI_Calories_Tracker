import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/calories_tracker_model.dart';
import '../main.dart' show rootScaffoldMessengerKey;

class ScanFoodPage extends StatefulWidget {
  const ScanFoodPage({super.key});
  @override
  State<ScanFoodPage> createState() => _ScanFoodPageState();
}

class _ScanFoodPageState extends State<ScanFoodPage> {
  double _servingGrams = 100;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageAndAnalyze(ImageSource source) async {
    final XFile? xfile = await _picker.pickImage(
        source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (xfile == null) return;
    final model = context.read<CaloriesTrackerModel>();
    model.setImageFilePath(xfile.path);
    await model.analyzeFood();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(
            child: ListTile(
          leading: model.processing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.restaurant_menu, color: colorScheme.primary),
          title: Text(model.status),
          subtitle: model.processing ? const LinearProgressIndicator() : null,
        )),
        const SizedBox(height: 12),
        Expanded(
          flex: 2,
          child: model.imageFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(model.imageFile!,
                      width: double.infinity, fit: BoxFit.cover))
              : Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: colorScheme.surfaceVariant,
                      border: Border.all(color: colorScheme.outline, width: 2)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            size: 64, color: colorScheme.primary),
                        const SizedBox(height: 12),
                        Text("Take a photo of your food",
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text("AI will analyze and provide nutrition info",
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center),
                      ]),
                ),
        ),
        const SizedBox(height: 12),
        if (model.detectedFoods.isNotEmpty)
          Expanded(
              flex: 3,
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Detected Foods",
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  FilledButton.icon(
                                      onPressed: () =>
                                          _showAddToMealDialog(context, model),
                                      icon: const Icon(Icons.add),
                                      label: const Text("Add to Meals"))
                                ]),
                            const SizedBox(height: 8),
                            Expanded(
                                child: ListView.builder(
                                    itemCount: model.detectedFoods.length,
                                    itemBuilder: (context, i) {
                                      final f = model.detectedFoods[i];
                                      final pct = f.proportion != null
                                          ? (f.proportion! * 100).round()
                                          : null;
                                      final conf = (f.confidence * 100).round();

                                      final estimatedCalories = f.nutrition !=
                                                  null &&
                                              f.proportion != null
                                          ? _calculateRealisticCalories(f, 100)
                                          : 0;

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        color: colorScheme.surface,
                                        child: ListTile(
                                            leading: CircleAvatar(
                                                backgroundColor: colorScheme
                                                    .primaryContainer,
                                                child: Text(pct != null ? '$pct%' : '${conf}%',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: colorScheme
                                                            .onPrimaryContainer))),
                                            title: Text(f.name.toUpperCase(),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            subtitle: f.nutrition != null
                                                ? Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                          '${f.nutrition!.calories.round()} kcal per 100g'),
                                                      if (f.proportion !=
                                                              null &&
                                                          estimatedCalories > 0)
                                                        Text(
                                                            'Est: ${estimatedCalories.round()} kcal • ${(f.proportion! * 100).round()}%',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: colorScheme
                                                                    .primary)),
                                                    ],
                                                  )
                                                : Text('Nutrition data loading...',
                                                    style: TextStyle(
                                                        color: colorScheme.onSurface
                                                            .withOpacity(0.6))),
                                            trailing: f.nutrition != null
                                                ? Icon(Icons.check_circle,
                                                    color: colorScheme.primary)
                                                : const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(strokeWidth: 2))),
                                      );
                                    }))
                          ])))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: () => _showImageSourceActionSheet(context),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'))),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => _pickImageAndAnalyze(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('From Gallery'))),
        ])
      ]),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageAndAnalyze(ImageSource.camera);
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageAndAnalyze(ImageSource.gallery);
                  }),
            ])));
  }

  void _showAddToMealDialog(BuildContext context, CaloriesTrackerModel model) {
    final editableFoods = model.detectedFoods
        .map((food) => _EditableFoodItem(
              name: food.name,
              confidence: food.confidence,
              nutrition: food.nutrition,
              proportion: food.proportion ?? (1.0 / model.detectedFoods.length),
            ))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        final nutrition =
            _calculateTotalNutritionFromFoods(editableFoods, _servingGrams);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final totalPercentage = _calculateTotalPercentage(editableFoods);
        final isTotalValid = totalPercentage.round() == 100;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(19.3)),
          child: Container(
            padding: const EdgeInsets.all(16.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant,
                        color: colorScheme.primary, size: 19.9),
                    const SizedBox(width: 13.2),
                    Text('Add to Meal Log', style: theme.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 16.6),

                // Serving Size
                Card(
                  color: colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(13.2),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.scale,
                                size: 16.6, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6.6),
                            Text('Serving Size',
                                style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 9.9),
                        Text('${_servingGrams.round()}g',
                            style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary)),
                        Slider(
                          value: _servingGrams,
                          min: 10,
                          max: 1500,
                          divisions: 149,
                          inactiveColor:
                              theme.colorScheme.inverseSurface.withOpacity(0.3),
                          label: '${_servingGrams.round()}g',
                          onChanged: (v) => setState(() => _servingGrams = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 13.2),

                // Ingredients Adjustment
                Card(
                  margin: EdgeInsets.zero,
                  color: colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(13.2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with total percentage
                        Row(
                          children: [
                            Icon(Icons.tune,
                                size: 16.6, color: colorScheme.primary),
                            const SizedBox(width: 6.6),
                            Text('Adjust Portions',
                                style: theme.textTheme.titleMedium),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9.9, vertical: 5),
                              decoration: BoxDecoration(
                                color: isTotalValid
                                    ? colorScheme.primary.withOpacity(0.15)
                                    : colorScheme.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(9.9),
                                border: Border.all(
                                  color: isTotalValid
                                      ? colorScheme.primary.withOpacity(0.3)
                                      : colorScheme.error.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isTotalValid
                                        ? Icons.check_circle
                                        : Icons.warning,
                                    size: 13.2,
                                    color: isTotalValid
                                        ? colorScheme.primary
                                        : colorScheme.error,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${totalPercentage.round()}%',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isTotalValid
                                          ? colorScheme.primary
                                          : colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Instruction text
                        Padding(
                          padding: const EdgeInsets.only(top: 6.6, left: 23.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTotalValid
                                    ? 'Adjust each ingredient independently'
                                    : 'Total must be exactly 100% to add to log',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isTotalValid
                                      ? colorScheme.onSurface.withOpacity(0.7)
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 9.9),

                        // Ingredients list
                        Container(
                          height: 165.4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6.6),
                          ),
                          child: ListView.separated(
                            itemCount: editableFoods.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 6.6),
                            itemBuilder: (context, index) {
                              final food = editableFoods[index];
                              return _buildIngredientAdjustmentItem(
                                  food, setState, editableFoods, index, theme);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 13.2),

                // Nutrition Summary
                _buildNutritionSummary(nutrition, _servingGrams, theme),
                const SizedBox(height: 16.6),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 9.9),
                    Expanded(
                      child: FilledButton(
                        onPressed: isTotalValid
                            ? () async {
                                for (int i = 0; i < editableFoods.length; i++) {
                                  if (i < model.detectedFoods.length) {
                                    model.detectedFoods[i].proportion =
                                        editableFoods[i].proportion;
                                  }
                                }

                                Navigator.pop(context);
                                final success = await model.addToMealLog(
                                    servingMultiplier: _servingGrams / 100.0);

                                if (success) {
                                  rootScaffoldMessengerKey.currentState
                                      ?.showSnackBar(const SnackBar(
                                          content: Text('Added to meal log!')));
                                } else {
                                  rootScaffoldMessengerKey.currentState
                                      ?.showSnackBar(const SnackBar(
                                          content: Text(
                                              'Failed to add meal. Check logs.')));
                                }
                              }
                            : null,
                        child: const Text('Add to Log'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildIngredientAdjustmentItem(
      _EditableFoodItem food,
      StateSetter setState,
      List<_EditableFoodItem> allFoods,
      int currentIndex,
      ThemeData theme) {
    final percentage = (food.proportion * 100).round();
    final colorScheme = theme.colorScheme;
    final estimatedCalories = food.nutrition != null
        ? (food.nutrition!.calories * food.proportion * (_servingGrams / 100.0))
            .round()
        : 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(19.8, 13.2, 19.8, 6.6),
      decoration: BoxDecoration(
        color: colorScheme.inversePrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(36.4),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row - more compact
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name.toUpperCase(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (food.nutrition != null)
                      Text(
                        '${estimatedCalories} kcal • ${food.nutrition!.calories.round()} kcal/100g',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.6, vertical: 3.3),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.95),
                ),
                child: Text(
                  '$percentage%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6.6),

          // Nutrition info - more compact single line
          if (food.nutrition != null)
            Row(
              children: [
                _NutritionChip(
                    'P:${food.nutrition!.protein.roundToDouble()}g', theme),
                const SizedBox(width: 5),
                _NutritionChip(
                    'C:${food.nutrition!.carbs.roundToDouble()}g', theme),
                const SizedBox(width: 5),
                _NutritionChip(
                    'F:${food.nutrition!.fat.roundToDouble()}g', theme),
              ],
            ),

          const SizedBox(height: 9.9),

          // Slider with better UX
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove,
                        size: 13.2, color: colorScheme.onSurface),
                    onPressed: () {
                      setState(() {
                        if (food.proportion > 0.00) {
                          food.proportion -= 0.01;
                          // No redistribution - let user control each independently
                        }
                      });
                    },
                    style: IconButton.styleFrom(
                      backgroundColor:
                          colorScheme.inversePrimary.withOpacity(0.4),
                      padding: const EdgeInsets.all(3.3),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Expanded(
    child: Slider(
                      value: food.proportion,
                      min:0.00,
                      inactiveColor:
                          theme.colorScheme.inverseSurface.withOpacity(0.3),
                      max: 1.00,
                      divisions: 149,
                      onChanged: (value) {
                        setState(() {
                          food.proportion = value;
                          // No redistribution - let user control each independently
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.add, size: 13.2, color: colorScheme.onSurface),
                    onPressed: () {
                      setState(() {
                        if (food.proportion < 1) {
                          food.proportion += 0.01;
                          // No redistribution - let user control each independently
                        }
                      });
                    },
                    style: IconButton.styleFrom(
                      backgroundColor:
                          colorScheme.inversePrimary.withOpacity(0.4),
                      padding: const EdgeInsets.all(3.3),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary(
      Map<String, double> nutrition, double servingGrams, ThemeData theme) {
    final totalCalories = nutrition['calories'] ?? 0;
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(13.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics,
                    size: 16.6, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6.6),
                Text('Nutrition Summary', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 9.9),

            // Nutrition metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NutritionMetric(
                    'Calories', '${totalCalories.round()}', 'kcal', theme),
                _NutritionMetric(
                    'Protein', '${nutrition['protein']?.round()}', 'g', theme),
                _NutritionMetric(
                    'Carbs', '${nutrition['carbs']?.round()}', 'g', theme),
                _NutritionMetric(
                    'Fat', '${nutrition['fat']?.round()}', 'g', theme),
              ],
            ),
            const SizedBox(height: 9.9),

            // Serving info
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 13.2, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 3.3),
                Text('Total serving: ${servingGrams.round()}g',
                    style: theme.textTheme.bodySmall),
              ],
            ),
            if (totalCalories > 2000)
              Padding(
                padding: const EdgeInsets.only(top: 6.6),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 13.2, color: colorScheme.error),
                    const SizedBox(width: 3.3),
                    Text(
                      'High calorie meal detected',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.error),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalPercentage(List<_EditableFoodItem> foods) {
    return foods.fold(0.0, (sum, food) => sum + (food.proportion * 100));
  }

  double _calculateRealisticCalories(FoodItem food, double grams) {
    if (food.nutrition == null || food.proportion == null) return 0;
    return food.nutrition!.calories * (grams / 100.0) * food.proportion!;
  }

  Map<String, double> _calculateTotalNutritionFromFoods(
      List<_EditableFoodItem> foods, double servingGrams) {
    double calories = 0, protein = 0, carbs = 0, fat = 0;

    for (final food in foods) {
      if (food.nutrition != null) {
        final densityFactor = _getFoodDensity(food.name);
        final servingMultiplier =
            (servingGrams / 100.0) * food.proportion * densityFactor;

        calories += food.nutrition!.calories * servingMultiplier;
        protein += food.nutrition!.protein * servingMultiplier;
        carbs += food.nutrition!.carbs * servingMultiplier;
        fat += food.nutrition!.fat * servingMultiplier;
      }
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  double _getFoodDensity(String foodName) {
    final lower = foodName.toLowerCase();

    if (lower.contains('chicken') ||
        lower.contains('beef') ||
        lower.contains('pork') ||
        lower.contains('fish') ||
        lower.contains('nut') ||
        lower.contains('cheese') ||
        lower.contains('meat')) {
      return 1.2;
    }

    if (lower.contains('bread') ||
        lower.contains('rice') ||
        lower.contains('pasta') ||
        lower.contains('potato') ||
        lower.contains('bean')) {
      return 0.9;
    }

    if (lower.contains('salad') ||
        lower.contains('vegetable') ||
        lower.contains('fruit') ||
        lower.contains('berry') ||
        lower.contains('leaf')) {
      return 0.6;
    }

    if (lower.contains('soup') ||
        lower.contains('sauce') ||
        lower.contains('drink')) {
      return 1.0;
    }

    return 0.8;
  }
}

// Helper Widgets
class _NutritionChip extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _NutritionChip(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.6, vertical: 3.3),
      decoration: BoxDecoration(
        color: theme.colorScheme.inversePrimary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4.95),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}

class _NutritionMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final ThemeData theme;

  const _NutritionMetric(this.label, this.value, this.unit, this.theme);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        Text(unit, style: theme.textTheme.bodySmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _EditableFoodItem {
  String name;
  double confidence;
  NutritionInfo? nutrition;
  double proportion;

  _EditableFoodItem({
    required this.name,
    required this.confidence,
    this.nutrition,
    required this.proportion,
  });
}