class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.plan,
    this.sourceCount = 0,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String plan;
  final int sourceCount;
  final String? createdAt;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      plan: map['plan'] as String? ?? 'free',
      sourceCount: map['source_count'] as int? ?? 0,
      createdAt: map['created_at']?.toString(),
    );
  }

  UserProfile copyWith({
    String? name,
    String? role,
    String? plan,
    int? sourceCount,
  }) {
    return UserProfile(
      id: id,
      email: email,
      name: name ?? this.name,
      role: role ?? this.role,
      plan: plan ?? this.plan,
      sourceCount: sourceCount ?? this.sourceCount,
      createdAt: createdAt,
    );
  }
}

class AdminStats {
  AdminStats({
    required this.totalUsers,
    required this.freeUsers,
    required this.vipUsers,
    required this.adminUsers,
    required this.totalSources,
  });

  final int totalUsers;
  final int freeUsers;
  final int vipUsers;
  final int adminUsers;
  final int totalSources;

  factory AdminStats.fromMap(Map<String, dynamic> map) {
    return AdminStats(
      totalUsers: map['total_users'] as int? ?? 0,
      freeUsers: map['free_users'] as int? ?? 0,
      vipUsers: map['vip_users'] as int? ?? 0,
      adminUsers: map['admin_users'] as int? ?? 0,
      totalSources: map['total_sources'] as int? ?? 0,
    );
  }
}

class AdminUserSource {
  AdminUserSource({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.sourceUrl,
    required this.isActive,
  });

  final String id;
  final String name;
  final String sourceType;
  final String sourceUrl;
  final bool isActive;

  factory AdminUserSource.fromMap(Map<String, dynamic> map) {
    return AdminUserSource(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      sourceType: map['source_type'] as String? ?? '',
      sourceUrl: map['source_url'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? false,
    );
  }
}
