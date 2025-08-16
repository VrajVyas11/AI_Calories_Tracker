// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calories_tracker_model.dart';
import '../services/supabase_service.dart';
import '../main.dart'; // for rootScaffoldMessengerKey if present

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Goal controllers
  final TextEditingController _calorieController = TextEditingController(text: '2000');
  final TextEditingController _proteinController = TextEditingController(text: '150');
  final TextEditingController _carbsController = TextEditingController(text: '250');
  final TextEditingController _fatController = TextEditingController(text: '67');

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If model already has goals, prefill
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = context.read<CaloriesTrackerModel>();
      final u = model.currentUser;
      if (u != null) {
        _calorieController.text = u.calorieGoal.toStringAsFixed(0);
        _proteinController.text = u.proteinGoal.toStringAsFixed(0);
        _carbsController.text = u.carbsGoal.toStringAsFixed(0);
        _fatController.text = u.fatGoal.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _calorieController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final model = context.read<CaloriesTrackerModel>();

    final calories = double.tryParse(_calorieController.text) ?? 2000.0;
    final protein = double.tryParse(_proteinController.text) ?? 150.0;
    final carbs = double.tryParse(_carbsController.text) ?? 250.0;
    final fat = double.tryParse(_fatController.text) ?? 67.0;

    // persist to Supabase and mark onboarding completed
    final ok = await SupabaseService.completeOnboarding(calories, protein, carbs, fat);
    if (ok) {
      // refresh model state
      await model.refreshAuthState();
      // non-blocking feedback
      rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Goals saved — welcome!')));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/main');
    } else {
      rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Failed to save goals. Try again.')));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get Started')),
      body: SafeArea(
        child: Column(
          children: [
            // progress bar
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: i <= _currentPage ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _welcomePage(context),
                  _goalsPage(context),
                  _completePage(context),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage > 0
                      ? TextButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('Back'))
                      : const SizedBox(width: 64),
                  _currentPage < 2
                      ? FilledButton(
                          onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                          child: const Text('Next'),
                        )
                      : FilledButton(
                          onPressed: _isLoading ? null : _completeOnboarding,
                          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Get Started'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.restaurant_menu, size: 92, color: Theme.of(ctx).colorScheme.primary),
        const SizedBox(height: 24),
        Text('Welcome to AI Calories Tracker!', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Snap a photo, get nutrition, track your day. Quick and easy.', style: Theme.of(ctx).textTheme.bodyMedium, textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _goalsPage(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Set your daily goals', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _goalCard(icon: Icons.local_fire_department, title: 'Calories', controller: _calorieController, unit: 'kcal', color: Colors.orange, description: 'Daily energy target'),
          const SizedBox(height: 12),
          _goalCard(icon: Icons.fitness_center, title: 'Protein', controller: _proteinController, unit: 'g', color: Colors.red, description: 'Daily protein target'),
          const SizedBox(height: 12),
          _goalCard(icon: Icons.grain, title: 'Carbs', controller: _carbsController, unit: 'g', color: Colors.blue, description: 'Daily carbs target'),
          const SizedBox(height: 12),
          _goalCard(icon: Icons.opacity, title: 'Fat', controller: _fatController, unit: 'g', color: Colors.purple, description: 'Daily fat target'),
        ]),
      ),
    );
  }

  Widget _completePage(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle, size: 96, color: Colors.green),
        const SizedBox(height: 20),
        Text('You\'re all set!', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text('Your goals are saved. Start tracking meals now.', style: Theme.of(ctx).textTheme.bodyMedium, textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _goalCard({required IconData icon, required String title, required TextEditingController controller, required String unit, required Color color, required String description}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(description, style: const TextStyle(fontSize: 12))])),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: TextField(controller: controller, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: InputDecoration(suffixText: unit))),
        ]),
      ),
    );
  }
}