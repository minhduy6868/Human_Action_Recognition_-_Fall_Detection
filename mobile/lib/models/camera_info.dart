/// Thông tin cơ bản của camera được backend phát hiện hoặc cấu hình.
class CameraInfo {
  const CameraInfo({
    required this.index,
  });

  /// Chỉ số camera được backend dùng khi mở nguồn webcam.
  final int index;

  /// Chuyển JSON backend thành đối tượng [CameraInfo].
  factory CameraInfo.fromMap(Map<String, dynamic> map) {
    return CameraInfo(
      index: (map['index'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Đối tượng bọc kết quả trả về từ API danh sách camera.
class CameraList {
  const CameraList({
    required this.activeIndex,
    required this.items,
  });

  /// Chỉ số camera đang được backend chọn.
  final int activeIndex;

  /// Tất cả camera backend trả về.
  final List<CameraInfo> items;

  /// Chuyển JSON backend thành đối tượng [CameraList].
  factory CameraList.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? <dynamic>[];
    return CameraList(
      activeIndex: (map['active_index'] as num?)?.toInt() ?? 0,
      items: rawItems
          .map((item) => CameraInfo.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
