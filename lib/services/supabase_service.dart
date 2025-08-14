// lib/services/supabase_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_entry.dart';
import '../models/user_profile.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final String? _url = dotenv.env['SUPABASE_URL'] ;
  static final String _anonKey = (dotenv.env['SUPABASE_ANONKEY']) as String;

  static String? _accessToken;
  static String? _userId;

  // ---------------- Auth ----------------

  static Future<AuthResult> signUp(String email, String password, String fullName) async {
    try {
      final uri = Uri.parse('$_url/auth/v1/signup');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {'full_name': fullName}
        }),
      );

      if (kDebugMode) {
        print('Supabase signup status: ${response.statusCode}');
        print('Supabase signup body: ${response.body}');
      }

      if (response.body.isEmpty) {
        return AuthResult(success: false, error: 'Empty response from auth server');
      }

      final data = jsonDecode(response.body);

      // Case 1: signed in immediately (access_token + user)
      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['access_token'] != null &&
          data['user'] != null) {
        _accessToken = data['access_token'] as String?;
        _userId = (data['user'] as Map<String, dynamic>)['id'] as String?;
        await _saveAuthData();

        // Best-effort create user profile row (requires token)
        await ensureUserProfileExists(fullName: data['user']['user_metadata']?['full_name'] ?? fullName, email: email);

        final user = UserProfile(
          id: _userId ?? '',
          email: email,
          fullName: data['user']['user_metadata']?['full_name'] ?? fullName,
          createdAt: DateTime.now(),
        );

        return AuthResult(success: true, user: user);
      }

      // Case 2: Supabase returns a user object (account created but not authenticated)
      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['id'] != null &&
          data['email'] != null) {
        _userId = data['id'] as String?;
        // Save user id (no token)
        await _saveAuthData();

        final user = UserProfile(
          id: _userId ?? '',
          email: data['email'] as String? ?? email,
          fullName: data['user_metadata']?['full_name'] ?? fullName,
          createdAt: DateTime.now(),
        );

        return AuthResult(
          success: true,
          user: user,
          message: 'Account created. Please check your email to confirm and sign in.',
          createdButNotAuthenticated: true,
        );
      }

      String? err;
      if (data is Map<String, dynamic>) {
        err = data['error_description'] as String? ??
              data['error'] as String? ??
              data['message'] as String? ??
              (data['msg'] as String?);
      }
      err ??= 'Signup failed (status ${response.statusCode})';
      return AuthResult(success: false, error: err);
    } catch (e) {
      if (kDebugMode) print('Signup error: $e');
      return AuthResult(success: false, error: e.toString());
    }
  }

  static Future<AuthResult> signIn(String email, String password) async {
    try {
      final uri = Uri.parse('$_url/auth/v1/token?grant_type=password');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (kDebugMode) {
        print('Supabase signIn status: ${response.statusCode}');
        print('Supabase signIn body: ${response.body}');
      }

      if (response.body.isEmpty) {
        return AuthResult(success: false, error: 'Empty response from auth server');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>?;

      if (response.statusCode == 200 && data != null && data['access_token'] != null) {
        _accessToken = data['access_token'] as String?;
        _userId = (data['user'] as Map<String, dynamic>?)?['id'] as String?;
        await _saveAuthData();

        // Ensure profile exists (create if missing)
        await ensureUserProfileExists();

        final profile = await getUserProfile();
        return AuthResult(success: true, user: profile);
      }

      String? err;
      if (data != null) {
        err = data['error_description'] as String? ??
              data['error'] as String? ??
              data['message'] as String?;
      }
      err ??= 'Login failed (status ${response.statusCode})';
      return AuthResult(success: false, error: err);
    } catch (e) {
      if (kDebugMode) print('SignIn error: $e');
      return AuthResult(success: false, error: e.toString());
    }
  }

  static Future<void> signOut() async {
    try {
      if (_accessToken != null) {
        await http.post(
          Uri.parse('$_url/auth/v1/logout'),
          headers: {
            'Content-Type': 'application/json',
            'apikey': _anonKey,
            'Authorization': 'Bearer $_accessToken',
          },
        );
      }
    } catch (e) {
      if (kDebugMode) print('SignOut error: $e');
    } finally {
      _accessToken = null;
      _userId = null;
      await _clearAuthData();
    }
  }

  static Future<bool> isAuthenticated() async {
    if (_accessToken == null) {
      await _loadAuthData();
    }
    return _accessToken != null;
  }

  static String? get currentUserId => _userId;

  // ---------------- Database operations ----------------

  static Future<bool> saveMeal(MealEntry meal) async {
    if (!await isAuthenticated()) return false;

    try {
      final response = await http.post(
        Uri.parse('$_url/rest/v1/meals'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer $_accessToken',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({
          'user_id': _userId,
          'date': meal.timestamp.toIso8601String().substring(0, 10),
          'timestamp': meal.timestamp.toIso8601String(),
          'food_names': meal.foodNames,
          'calories': meal.calories,
          'protein': meal.protein,
          'carbs': meal.carbs,
          'fat': meal.fat,
          'serving_size': meal.servingSize,
          'image_url': meal.imageUrl,
        }),
      );

      if (kDebugMode) {
        print('saveMeal status: ${response.statusCode}');
        print('saveMeal body: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        if (kDebugMode) print('Failed to save meal: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('Save meal error: $e');
      return false;
    }
  }

  static Future<List<MealEntry>> getMealsForDate(DateTime date) async {
    if (!await isAuthenticated()) return [];

    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final response = await http.get(
        Uri.parse('$_url/rest/v1/meals?user_id=eq.$_userId&date=eq.$dateStr&order=timestamp.desc'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MealEntry.fromSupabaseJson(json)).toList();
      } else {
        if (kDebugMode) print('GetMealsForDate non-200: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('Get meals error: $e');
    }

    return [];
  }

  static Future<bool> updateGoals(double calories, double protein, double carbs, double fat) async {
    if (!await isAuthenticated()) return false;

    try {
      final response = await http.patch(
        Uri.parse('$_url/rest/v1/user_profiles?id=eq.$_userId'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'calorie_goal': calories,
          'protein_goal': protein,
          'carbs_goal': carbs,
          'fat_goal': fat,
        }),
      );

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Update goals error: $e');
      return false;
    }
  }

  /// Ensure a user_profiles row exists for the current user.
  /// If fullName/email provided, uses them; otherwise fetches from auth endpoint.
  static Future<bool> ensureUserProfileExists({String? fullName, String? email}) async {
    // require token
    if (!await isAuthenticated()) return false;
    try {
      // Check if exists
      final check = await http.get(
        Uri.parse('$_url/rest/v1/user_profiles?id=eq.$_userId&select=id'),
        headers: {'apikey': _anonKey, 'Authorization': 'Bearer $_accessToken'},
      );

      if (kDebugMode) print('ensureUserProfileExists.check: ${check.statusCode} ${check.body}');
      if (check.statusCode == 200) {
        final List<dynamic> data = jsonDecode(check.body);
        if (data.isNotEmpty) return true; // exists
      }

      // If no profile, try to get auth user info
      String useFull = fullName ?? '';
      String useEmail = email ?? '';
      try {
        final resp = await http.get(Uri.parse('$_url/auth/v1/user'), headers: {'apikey': _anonKey, 'Authorization': 'Bearer $_accessToken'});
        if (kDebugMode) print('ensureUserProfileExists.authUser: ${resp.statusCode} ${resp.body}');
        if (resp.statusCode == 200 && resp.body.isNotEmpty) {
          final ud = jsonDecode(resp.body) as Map<String, dynamic>;
          useFull = useFull.isEmpty ? (ud['user_metadata']?['full_name'] as String? ?? useFull) : useFull;
          useEmail = useEmail.isEmpty ? (ud['email'] as String? ?? useEmail) : useEmail;
          _userId = ud['id'] as String? ?? _userId;
        }
      } catch (e) {
        if (kDebugMode) print('ensureUserProfileExists: failed to fetch auth user: $e');
      }

      // Create profile row
      final createResp = await http.post(Uri.parse('$_url/rest/v1/user_profiles'), headers: {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
        'Authorization': 'Bearer $_accessToken',
        'Prefer': 'return=representation',
      }, body: jsonEncode({
        'id': _userId,
        'email': useEmail,
        'full_name': useFull,
        'calorie_goal': 2000.0,
        'protein_goal': 150.0,
        'carbs_goal': 250.0,
        'fat_goal': 67.0,
        'created_at': DateTime.now().toIso8601String(),
      }));

      if (kDebugMode) print('ensureUserProfileExists.create: ${createResp.statusCode} ${createResp.body}');
      return createResp.statusCode == 201 || createResp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('ensureUserProfileExists error: $e');
      return false;
    }
  }

  /// Get user profile row, fallback to auth user; if missing optionally create
  static Future<UserProfile?> getUserProfile() async {
    if (!await isAuthenticated()) return null;

    // Try table first
    try {
      final response = await http.get(Uri.parse('$_url/rest/v1/user_profiles?id=eq.$_userId&select=*'), headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_accessToken',
      });

      if (kDebugMode) print('GetUserProfile table: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> rows = jsonDecode(response.body);
        if (rows.isNotEmpty) {
          return UserProfile.fromJson(rows.first as Map<String, dynamic>);
        }
        // If not present, attempt to create it from auth user
        final created = await ensureUserProfileExists();
        if (created) {
          // re-fetch
          final r2 = await http.get(Uri.parse('$_url/rest/v1/user_profiles?id=eq.$_userId&select=*'), headers: {
            'apikey': _anonKey,
            'Authorization': 'Bearer $_accessToken',
          });
          if (r2.statusCode == 200) {
            final List<dynamic> rows2 = jsonDecode(r2.body);
            if (rows2.isNotEmpty) return UserProfile.fromJson(rows2.first as Map<String, dynamic>);
          }
        }
      } else {
        if (kDebugMode) print('GetUserProfile table non-200: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('GetUserProfile table error: $e');
    }

    // Fallback to /auth/v1/user
    try {
      final resp = await http.get(Uri.parse('$_url/auth/v1/user'), headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_accessToken',
      });

      if (kDebugMode) print('GetUserProfile auth endpoint: ${resp.statusCode} ${resp.body}');
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final ud = jsonDecode(resp.body) as Map<String, dynamic>;
        final fullName = (ud['user_metadata']?['full_name'] as String?) ?? (ud['email'] as String? ?? 'User');
        final email = ud['email'] as String? ?? '';
        final id = ud['id'] as String? ?? _userId ?? '';
        final created = DateTime.tryParse(ud['created_at'] as String? ?? '') ?? DateTime.now();
        return UserProfile(
          id: id,
          email: email,
          fullName: fullName,
          calorieGoal: 2000.0,
          proteinGoal: 150.0,
          carbsGoal: 250.0,
          fatGoal: 67.0,
          createdAt: created,
          updatedAt: null,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Get auth user fallback error: $e');
    }

    return null;
  }

  static Future<bool> deleteMeal(String mealId) async {
    if (!await isAuthenticated()) return false;
    try {
      final response = await http.delete(Uri.parse('$_url/rest/v1/meals?id=eq.$mealId&user_id=eq.$_userId'), headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_accessToken',
      });
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Delete meal error: $e');
      return false;
    }
  }

  // Nutrition cache functions unchanged...
  static Future<bool> cacheNutritionData(String foodName, Map<String, dynamic> nutritionData) async {
    if (!await isAuthenticated()) return false;
    try {
      final response = await http.post(Uri.parse('$_url/rest/v1/nutrition_cache'), headers: {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
        'Authorization': 'Bearer $_accessToken',
        'Prefer': 'return=minimal',
      }, body: jsonEncode({
        'food_name': foodName.toLowerCase(),
        'nutrition_data': nutritionData,
        'cached_at': DateTime.now().toIso8601String(),
        'user_id': _userId,
      }));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Cache nutrition error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCachedNutrition(String foodName) async {
    if (!await isAuthenticated()) return null;
    try {
      final response = await http.get(Uri.parse('$_url/rest/v1/nutrition_cache?food_name=eq.${foodName.toLowerCase()}&select=nutrition_data&limit=1'), headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_accessToken',
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) return data.first['nutrition_data'] as Map<String, dynamic>;
      } else {
        if (kDebugMode) print('GetCachedNutrition non-200: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('Get cached nutrition error: $e');
    }
    return null;
  }

  // Private helpers
  static Future<void> _saveAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
    if (_userId != null) await prefs.setString('user_id', _userId!);
  }

  static Future<void> _loadAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _userId = prefs.getString('user_id');
  }

  static Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_id');
  }
}

class AuthResult {
  final bool success;
  final String? error;
  final UserProfile? user;
  final bool createdButNotAuthenticated;
  final String? message;

  AuthResult({
    required this.success,
    this.error,
    this.user,
    this.createdButNotAuthenticated = false,
    this.message,
  });
}