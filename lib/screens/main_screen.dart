// lib/screens/main_page.dart
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member, deprecated_member_use
import 'package:ai_calories_tracker/models/calories_tracker_model.dart';
import 'package:ai_calories_tracker/screens/main_page_screens/analytics_page.dart';
import 'package:ai_calories_tracker/screens/main_page_screens/dash_board_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/scan_food_screen.dart';
import '../widgets/user_profile_sheet.dart';

/// ------------------ UI / MainPage ------------------

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CaloriesTrackerModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Calories Tracker'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () => _showProfileSheet(context),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: model.currentUser != null
                    ? Text(_initials(model.currentUser!.fullName))
                    : const Icon(Icons.person_outline),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt), text: 'Scan'),
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ScanFoodPage(),
          DashboardPage(),
          AnalyticsPage(),
        ],
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    final model = context.read<CaloriesTrackerModel>();
    showModalBottomSheet(
      context: context,
      builder: (_) => UserProfileSheet(user: model.currentUser, onSignOut: () async {
        await model.signOut();
        Navigator.of(context).pushReplacementNamed('/auth');
      }, onUserUpdated: (UserProfile ) {  },),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
