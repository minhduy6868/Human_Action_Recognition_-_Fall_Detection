class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.plan,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String plan;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      plan: map['plan'] as String? ?? 'free',
    );
  }
}
