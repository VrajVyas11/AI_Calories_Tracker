// lib/screens/scan_food_page.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/calories_tracker_model.dart';
import '../main.dart' show rootScaffoldMessengerKey; // import the messenger key

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
              : Icon(Icons.restaurant_menu,
                  color: Theme.of(context).colorScheme.primary),
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
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 2)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 12),
                        Text("Take a photo of your food",
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text("AI will analyze and provide nutrition info",
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center),
                      ]),
                ),
        ),
        const SizedBox(height: 12),
        if (model.detectedFoods.isNotEmpty)
          Expanded(
              flex: 1,
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  TextButton.icon(
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
                                      return ListTile(
                                          leading: CircleAvatar(
                                              child: Text(pct != null
                                                  ? '$pct%'
                                                  : '${conf}%')),
                                          title: Text(f.name.toUpperCase()),
                                          subtitle: f.nutrition != null
                                              ? Text(
                                                  '${f.nutrition!.calories.round()} kcal per 100g')
                                              : const Text('Nutrition unknown'),
                                          trailing: f.nutrition != null
                                              ? const Icon(Icons.check_circle,
                                                  color: Colors.green)
                                              : const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2)));
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
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, setState) {
              return AlertDialog(
                title: const Text('Add to Meal Log'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Select total serving size (grams) for this meal:'),
                  const SizedBox(height: 12),
                  Text('${_servingGrams.round()} g',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                      value: _servingGrams,
                      min: 10,
                      max: 1500,
                      divisions: 149,
                      label: '${_servingGrams.round()} g',
                      onChanged: (v) => setState(() => _servingGrams = v)),
                  const SizedBox(height: 6),
                  const Text(
                      'You can edit proportions for each detected item on the list before adding.'),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () async {
                        Navigator.pop(context); // close dialog first
                        final multiplier = _servingGrams / 100.0;
                        final success = await model.addToMealLog(
                            servingMultiplier: multiplier);
                        // Use root scaffold messenger key to avoid "deactivated widget" error
                        if (success) {
                          rootScaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(
                                  content: Text('Added to meal log!')));
                        } else {
                          rootScaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Failed to add meal. Check logs.')));
                        }
                      },
                      child: const Text('Add'))
                ],
              );
            }));
  }
}
