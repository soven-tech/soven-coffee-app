class User {
  final String userId;
  final String name;
  final Map<String, dynamic> preferences;

  User({
    required this.userId,
    required this.name,
    this.preferences = const {},
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      name: json['name'],
      preferences: json['preferences'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'preferences': preferences,
    };
  }
}