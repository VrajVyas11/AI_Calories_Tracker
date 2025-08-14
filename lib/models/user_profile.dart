// models/user_profile.dart
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final double calorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.calorieGoal = 2000.0,
    this.proteinGoal = 150.0,
    this.carbsGoal = 250.0,
    this.fatGoal = 67.0,
    required this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      calorieGoal: (json['calorie_goal'] as num?)?.toDouble() ?? 2000.0,
      proteinGoal: (json['protein_goal'] as num?)?.toDouble() ?? 150.0,
      carbsGoal: (json['carbs_goal'] as num?)?.toDouble() ?? 250.0,
      fatGoal: (json['fat_goal'] as num?)?.toDouble() ?? 67.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'calorie_goal': calorieGoal,
      'protein_goal': proteinGoal,
      'carbs_goal': carbsGoal,
      'fat_goal': fatGoal,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    double? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}