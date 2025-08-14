// lib/widgets/user_profile_sheet.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class UserProfileSheet extends StatelessWidget {
  final UserProfile? user;
  final VoidCallback onSignOut;

  const UserProfileSheet({super.key, required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName ?? 'Guest';
    final email = user?.email ?? 'Not signed in';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(children: [
          Row(children: [
            CircleAvatar(radius: 28, child: Text(_initials(name), style: const TextStyle(fontSize: 18))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(email, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
          const SizedBox(height: 12),
          ListTile(leading: const Icon(Icons.settings), title: const Text('Account settings'), onTap: () {
            // TODO: implement account settings screen
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account settings opened (not implemented)')));
          }),
          ListTile(leading: const Icon(Icons.history), title: const Text('Activity'), onTap: () {
            // TODO: implement activity screen
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity opened (not implemented)')));
          }),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Sign out'), onTap: () {
            // Confirm sign out
            showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Sign out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(onPressed: () {
                  Navigator.pop(ctx); // dismiss dialog
                  onSignOut();
                }, child: const Text('Sign out')),
              ],
            ));
          }),
        ]),
      ),
    );
  }

  String _initials(String n) {
    final parts = n.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}