// lib/widgets/auth_wrapper.dart
import 'package:ai_calories_tracker/screens/splash_screen.dart'
    show SplashScreen;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calories_tracker_model.dart';
import '../screens/auth_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CaloriesTrackerModel>(
      builder: (context, model, _) {
        // Show loading while checking auth state
        if (model.isCheckingAuth) {
          return const Scaffold(
            body: Center(
              child: SplashScreen(),
            ),
          );
        }

        // if (!model.isAuthenticated) {
        //   return const SplashScreen(
        //       autoNavigate: true, displayDuration: Duration(milliseconds: 900));
        // }

        // Not authenticated - show auth screen
        if (!model.isAuthenticated) {
          return const AuthScreen();
        }

        // Authenticated but no user profile or onboarding not completed
        if (model.currentUser == null ||
            !model.currentUser!.onboardingCompleted) {
          return const OnboardingScreen();
        }

        // Fully authenticated and onboarded - show main app
        return const MainPage();
      },
    );
  }
}
