// lib/main.dart
import 'package:ai_calories_tracker/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'models/calories_tracker_model.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/auth_screen.dart';
import 'screens/main_page.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('Environment loaded successfully');
  } catch (e) {
    debugPrint('.env not found, using fallback. Error: $e');
  }

  runApp(
    ChangeNotifierProvider<CaloriesTrackerModel>(
      create: (_) => CaloriesTrackerModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Calories Tracker',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green, brightness: Brightness.dark)),
      home: const AuthWrapper(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/main': (context) => const MainPage(),
      },
    );
  }
}
