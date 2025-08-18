// lib/screens/account_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  final UserProfile user;
  final Function(UserProfile) onUserUpdated;

  const AccountSettingsScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late UserProfile _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildProfileSection(),
                const SizedBox(height: 24),
                _buildNutritionGoalsSection(),
                const SizedBox(height: 24),
                _buildSecuritySection(),
                const SizedBox(height: 24),
                _buildDataSection(),
              ],
            ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Full Name'),
              subtitle: Text(_currentUser.fullName),
              trailing: const Icon(Icons.edit),
              onTap: () => _showEditNameDialog(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(_currentUser.email),
              trailing: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              onTap: () => _showEmailInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionGoalsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Goals',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildGoalTile(
              icon: Icons.local_fire_department,
              title: 'Daily Calories',
              value: '${_currentUser.calorieGoal.toInt()} kcal',
              color: Colors.orange,
            ),
            _buildGoalTile(
              icon: Icons.fitness_center,
              title: 'Protein',
              value: '${_currentUser.proteinGoal.toInt()} g',
              color: Colors.red,
            ),
            _buildGoalTile(
              icon: Icons.grain,
              title: 'Carbohydrates',
              value: '${_currentUser.carbsGoal.toInt()} g',
              color: Colors.blue,
            ),
            _buildGoalTile(
              icon: Icons.opacity,
              title: 'Fat',
              value: '${_currentUser.fatGoal.toInt()} g',
              color: Colors.purple,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showEditGoalsDialog(),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Goals'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showChangePasswordDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data & Privacy',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Export Data'),
              subtitle: const Text('Download your nutrition data'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showExportDataDialog(),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red[600]),
              title: Text('Delete Account', style: TextStyle(color: Colors.red[600])),
              subtitle: const Text('Permanently delete your account and data'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showDeleteAccountDialog(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _currentUser.fullName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _currentUser.fullName) {
                Navigator.pop(context);
                await _updateProfile(fullName: newName);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditGoalsDialog() {
    final caloriesController = TextEditingController(text: _currentUser.calorieGoal.toInt().toString());
    final proteinController = TextEditingController(text: _currentUser.proteinGoal.toInt().toString());
    final carbsController = TextEditingController(text: _currentUser.carbsGoal.toInt().toString());
    final fatController = TextEditingController(text: _currentUser.fatGoal.toInt().toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Nutrition Goals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Daily Calories',
                  suffixText: 'kcal',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: proteinController,
                decoration: const InputDecoration(
                  labelText: 'Protein',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: carbsController,
                decoration: const InputDecoration(
                  labelText: 'Carbohydrates',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fatController,
                decoration: const InputDecoration(
                  labelText: 'Fat',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final calories = double.tryParse(caloriesController.text) ?? _currentUser.calorieGoal;
              final protein = double.tryParse(proteinController.text) ?? _currentUser.proteinGoal;
              final carbs = double.tryParse(carbsController.text) ?? _currentUser.carbsGoal;
              final fat = double.tryParse(fatController.text) ?? _currentUser.fatGoal;

              Navigator.pop(context);
              await _updateGoals(calories, protein, carbs, fat);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureCurrentPassword = !obscureCurrentPassword),
                    ),
                  ),
                  obscureText: obscureCurrentPassword,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureNewPassword = !obscureNewPassword),
                    ),
                  ),
                  obscureText: obscureNewPassword,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
                    ),
                  ),
                  obscureText: obscureConfirmPassword,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _changePassword(currentPasswordController.text, newPasswordController.text);
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Address'),
        content: const Text('Email addresses cannot be changed directly. Please contact support if you need to update your email address.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('This feature will export all your nutrition data to a CSV file. This functionality is not yet implemented.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone and all your data will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion not implemented yet')),
              );
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile({String? fullName}) async {
    setState(() => _isLoading = true);
    
    try {
      // Note: This would require implementing an update profile method in SupabaseService
      // For now, we'll just update locally and show a success message
      
      if (fullName != null) {
        setState(() {
          _currentUser = UserProfile(
            id: _currentUser.id,
            email: _currentUser.email,
            fullName: fullName,
            calorieGoal: _currentUser.calorieGoal,
            proteinGoal: _currentUser.proteinGoal,
            carbsGoal: _currentUser.carbsGoal,
            fatGoal: _currentUser.fatGoal,
            onboardingCompleted: _currentUser.onboardingCompleted,
            createdAt: _currentUser.createdAt,
            updatedAt: DateTime.now(),
          );
        });
        
        widget.onUserUpdated(_currentUser);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateGoals(double calories, double protein, double carbs, double fat) async {
    setState(() => _isLoading = true);
    
    try {
      final success = await SupabaseService.updateGoals(calories, protein, carbs, fat);
      
      if (success) {
        setState(() {
          _currentUser = UserProfile(
            id: _currentUser.id,
            email: _currentUser.email,
            fullName: _currentUser.fullName,
            calorieGoal: calories,
            proteinGoal: protein,
            carbsGoal: carbs,
            fatGoal: fat,
            onboardingCompleted: _currentUser.onboardingCompleted,
            createdAt: _currentUser.createdAt,
            updatedAt: DateTime.now(),
          );
        });
        
        widget.onUserUpdated(_currentUser);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals updated successfully')),
        );
      } else {
        throw Exception('Failed to update goals');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update goals: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword(String currentPassword, String newPassword) async {
    setState(() => _isLoading = true);
    
    try {
      // Note: This would require implementing a change password method in SupabaseService
      // For now, we'll show a placeholder message
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password change not implemented yet')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change password: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}