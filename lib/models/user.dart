class User {
  final String id;
  final String name;
  final String email;
  final double totalCredits;
  final List<String> achievements;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.totalCredits = 0.0,
    this.achievements = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'totalCredits': totalCredits,
      'achievements': achievements,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      totalCredits: json['totalCredits'] ?? 0.0,
      achievements:
          (json['achievements'] as List?)?.map((e) => e as String).toList() ??
              [],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
