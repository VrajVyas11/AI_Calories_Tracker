// lib/widgets/auth_wrapper.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../screens/auth_screen.dart';
import '../screens/main_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Use SupabaseService.isAuthenticated() — does not depend on Provider
    final isAuth = await SupabaseService.isAuthenticated();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = isAuth;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Provider is available (because provider wraps MaterialApp in main.dart).
    // We can safely return MainPage (which will use Provider).
    return _isAuthenticated ? const MainPage() : const AuthScreen();
  }
}