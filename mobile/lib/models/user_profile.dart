/// Thông tin người dùng đang đăng nhập do backend trả về.
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

  /// Mã người dùng trên backend.
  final String id;

  /// Địa chỉ email dùng để đăng nhập.
  final String email;

  /// Tên hiển thị của người dùng.
  final String name;

  /// Vai trò người dùng, ví dụ user hoặc admin.
  final String role;

  /// Gói sử dụng, ví dụ free hoặc vip.
  final String plan;

  /// Số lượng nguồn camera/video của người dùng này.
  final int sourceCount;

  /// Thời gian tạo tài khoản backend trả về nếu có.
  final String? createdAt;

  /// Chuyển JSON backend thành đối tượng [UserProfile].
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

  /// Tạo bản sao mới và thay thế các trường có thể chỉnh sửa.
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

/// Các chỉ số tổng hợp cho màn hình quản trị.
class AdminStats {
  AdminStats({
    required this.totalUsers,
    required this.freeUsers,
    required this.vipUsers,
    required this.adminUsers,
    required this.totalSources,
  });

  /// Tổng số người dùng trong hệ thống.
  final int totalUsers;

  /// Số người dùng đang ở gói free.
  final int freeUsers;

  /// Số người dùng đang ở gói VIP.
  final int vipUsers;

  /// Số người dùng có quyền admin.
  final int adminUsers;

  /// Tổng số nguồn đã cấu hình trên tất cả người dùng.
  final int totalSources;

  /// Chuyển JSON backend thành đối tượng [AdminStats].
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

/// Thông tin nguồn hiển thị trong màn hình quản lý người dùng của admin.
class AdminUserSource {
  AdminUserSource({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.sourceUrl,
    required this.isActive,
  });

  /// Mã nguồn trên backend.
  final String id;

  /// Tên nguồn để hiển thị cho người dùng.
  final String name;

  /// Loại nguồn, ví dụ rtsp, webcam, file hoặc mjpeg.
  final String sourceType;

  /// URL, đường dẫn file hoặc chỉ số webcam được lưu dạng chuỗi.
  final String sourceUrl;

  /// Đúng khi nguồn này đang hoạt động.
  final bool isActive;

  /// Chuyển JSON backend thành đối tượng [AdminUserSource].
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
