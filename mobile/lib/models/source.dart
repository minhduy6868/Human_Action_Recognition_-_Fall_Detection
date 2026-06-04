/// Nguồn camera hoặc video được cấu hình cho backend giám sát.
class Source {
  const Source({
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

  /// Đúng khi nguồn này là stream đang hoạt động trên backend.
  final bool isActive;

  /// Chuyển JSON backend thành đối tượng [Source].
  factory Source.fromMap(Map<String, dynamic> map) {
    return Source(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      sourceType: map['source_type'] as String? ?? '',
      sourceUrl: map['source_url'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? false,
    );
  }
}
