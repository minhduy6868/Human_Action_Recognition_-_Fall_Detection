import 'person_action.dart';

/// Vật thể được pipeline YOLO ở backend phát hiện.
class DetectedObject {
  const DetectedObject({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.trackId,
    this.clothing = const PersonClothing(upper: 'unknown', lower: 'unknown'),
    this.isPerson = false,
  });

  /// Mã lớp dạng số của vật thể từ detector.
  final int classId;

  /// Nhãn dễ đọc cho người dùng, ví dụ "person" hoặc "chair".
  final String label;

  /// Độ tin cậy của detector trong khoảng 0.0-1.0.
  final double confidence;

  /// Tọa độ khung bao quanh vật thể tính theo pixel ảnh.
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  /// Mã theo dõi do backend tracker gán nếu có.
  final String trackId;

  /// Màu quần áo, thường chỉ có khi vật thể là người.
  final PersonClothing clothing;

  /// Đúng khi vật thể này là người.
  final bool isPerson;

  /// Chuyển JSON backend thành đối tượng [DetectedObject].
  factory DetectedObject.fromMap(Map<String, dynamic> map) {
    return DetectedObject(
      classId: (map['class_id'] as num?)?.toInt() ?? -1,
      label: (map['label'] as String?) ?? 'unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      x1: (map['x1'] as num?)?.toDouble() ?? 0.0,
      y1: (map['y1'] as num?)?.toDouble() ?? 0.0,
      x2: (map['x2'] as num?)?.toDouble() ?? 0.0,
      y2: (map['y2'] as num?)?.toDouble() ?? 0.0,
      trackId: (map['track_id'] as String?) ?? '',
      clothing: map['clothing'] != null
          ? PersonClothing.fromMap(map['clothing'] as Map<String, dynamic>)
          : const PersonClothing(upper: 'unknown', lower: 'unknown'),
      isPerson: (map['is_person'] as bool?) ?? (map['class_id'] == 0),
    );
  }

  Map<String, dynamic> toMap() => {
    'class_id': classId,
    'label': label,
    'confidence': confidence,
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
    'track_id': trackId,
    'clothing': clothing.toMap(),
    'is_person': isPerson,
  };

  /// Tên hiển thị được dùng trong widget danh sách vật thể.
  String get objectType {
    if (isPerson) return 'Person';
    return label.replaceFirst(label[0], label[0].toUpperCase());
  }
}
