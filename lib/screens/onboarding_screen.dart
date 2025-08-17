// lib/screens/onboarding_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calories_tracker_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caloriesController = TextEditingController(text: '2000');
  final _proteinController = TextEditingController(text: '150');
  final _carbsController = TextEditingController(text: '250');
  final _fatController = TextEditingController(text: '67');
  
  bool _isLoading = false;

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final calories = double.tryParse(_caloriesController.text) ?? 2000;
    final protein = double.tryParse(_proteinController.text) ?? 150;
    final carbs = double.tryParse(_carbsController.text) ?? 250;
    final fat = double.tryParse(_fatController.text) ?? 67;

    final model = context.read<CaloriesTrackerModel>();
    final success = await model.completeOnboarding(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save goals. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.track_changes,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Set Your Goals',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us your daily nutrition targets to get personalized tracking',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildGoalCard(
                          icon: Icons.local_fire_department,
                          label: 'Daily Calories',
                          controller: _caloriesController,
                          unit: 'kcal',
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        _buildGoalCard(
                          icon: Icons.fitness_center,
                          label: 'Daily Protein',
                          controller: _proteinController,
                          unit: 'g',
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        _buildGoalCard(
                          icon: Icons.grain,
                          label: 'Daily Carbs',
                          controller: _carbsController,
                          unit: 'g',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        _buildGoalCard(
                          icon: Icons.opacity,
                          label: 'Daily Fat',
                          controller: _fatController,
                          unit: 'g',
                          color: Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _completeOnboarding,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Get Started'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String unit,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: unit,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a value';
                }
                final parsed = double.tryParse(value);
                if (parsed == null || parsed <= 0) {
                  return 'Please enter a valid positive number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}