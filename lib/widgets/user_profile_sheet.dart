// lib/widgets/user_profile_sheet.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../screens/account_settings_screen.dart';
import '../screens/activity_screen.dart';

class UserProfileSheet extends StatelessWidget {
  final UserProfile? user;
  final VoidCallback onSignOut;
  final Function(UserProfile) onUserUpdated;

  const UserProfileSheet({
    super.key,
    required this.user,
    required this.onSignOut,
    required this.onUserUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName ?? 'Guest';
    final email = user?.email ?? 'Not signed in';
    final joinedDate = user?.createdAt != null
        ? 'Joined ${_formatJoinDate(user!.createdAt)}'
        : 'Account status unknown';

    // limit sheet to 85% of height
    // final maxHeight = MediaQuery.of(context).size.height * 0.85;
        // constraints: BoxConstraints(minHeight: maxHeight),

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          // Make the content scrollable so it won't overflow
          child: SingleChildScrollView(
            child: Column(
              // mainAxisSize.min keeps column from expanding beyond its content,
              // SingleChildScrollView + maxHeight constraint prevent overflow.
              // mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar (give it a height so it's visible)
                Container(
                  width: 40,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),

                // Profile header
                _buildProfileHeader(context, name, email, joinedDate),

                // const SizedBox(height: 32),

                // Quick stats (if user is available)
                // if (user != null) _buildQuickStats(context),

                const SizedBox(height: 16),

                // Menu items
                _buildMenuItems(context),

                // const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, String name, String email, String joinedDate) {
    return Row(
      children: [
        _buildAvatar(name),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                joinedDate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String name) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade400,
            Colors.purple.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

// Widget _buildQuickStats(BuildContext context) {
//   return Container(
//     padding: const EdgeInsets.all(16),
//     decoration: BoxDecoration(
//       color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
//       borderRadius: BorderRadius.circular(12),
//       border: Border.all(
//         color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
//       ),
//     ),
//     child: Row(
//       children: [
//         Expanded(
//           child: _buildStatColumn(
//             'Daily Goal',
//             '${user!.calorieGoal.toInt()}',
//             'kcal',
//             Colors.green,
//           ),
//         ),
//         Container(
//           width: 1,
//           height: 40,
//           color: Colors.grey[300],
//         ),
//         Expanded(
//           child: _buildStatColumn(
//             'Protein',
//             '${user!.proteinGoal.toInt()}',
//             'g',
//             const Color.fromARGB(255, 215, 162, 0),
//           ),
//         ),
//         Container(
//           width: 1,
//           height: 40,
//           color: Colors.grey[300],
//         ),
//         Expanded(
//           child: _buildStatColumn(
//             'Carbs',
//             '${user!.carbsGoal.toInt()}',
//             'g',
//             Colors.blue,
//           ),
//         ),
//         Container(
//           width: 1,
//           height: 40,
//           color: Colors.grey[300],
//         ),
//         Expanded(
//           child: _buildStatColumn(
//             'Fat',
//             '${user!.fatGoal.toInt()}',
//             'g',
//             Colors.purple,
//           ),
//         ),
//       ],
//     ),
//   );
// }
  
  
  // Widget _buildStatColumn(String label, String value, String unit, Color color) {
  //   return Column(
  //     children: [
  //       RichText(
  //         text: TextSpan(
  //           text: value,
  //           style: TextStyle(
  //             fontSize: 18,
  //             fontWeight: FontWeight.bold,
  //             color: color,
  //           ),
  //           children: unit.isNotEmpty
  //               ? [
  //                   TextSpan(
  //                     text: ' $unit',
  //                     style: TextStyle(
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.normal,
  //                       color: color.withOpacity(0.8),
  //                     ),
  //                   ),
  //                 ]
  //               : null,
  //         ),
  //       ),
  //       const SizedBox(height: 4),
  //       Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: 12,
  //           color: Colors.grey[600],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildMenuItems(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          icon: Icons.settings_outlined,
          title: 'Account Settings',
          subtitle: 'Manage your profile and goals',
          onTap: () {
            Navigator.pop(context); // Close bottom sheet
            if (user != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountSettingsScreen(
                    user: user!,
                    onUserUpdated: onUserUpdated,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please sign in to access settings')),
              );
            }
          },
        ),
        _buildMenuItem(
          context,
          icon: Icons.analytics_outlined,
          title: 'Activity & Stats',
          subtitle: 'View your nutrition history',
          onTap: () {
            Navigator.pop(context); // Close bottom sheet
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ActivityScreen()),
            );
          },
        ),
        _buildMenuItem(
          context,
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: () {
            Navigator.pop(context);
            _showHelpDialog(context);
          },
        ),
        const Divider(height: 32),
        _buildMenuItem(
          context,
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          isDestructive: true,
          onTap: () => _showSignOutDialog(context),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close bottom sheet
              onSignOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help with the app?'),
            SizedBox(height: 16),
            Text('• Check our FAQ section'),
            Text('• Contact support via email'),
            Text('• Join our community forum'),
            SizedBox(height: 16),
            Text(
                'This feature will be implemented soon with proper help resources and contact information.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _formatJoinDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 30) {
      return 'this month';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }
}