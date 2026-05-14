import 'person_action.dart';

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

  final int classId;
  final String label;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String trackId;
  final PersonClothing clothing;
  final bool isPerson;

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

  /// Get object type description
  String get objectType {
    if (isPerson) return 'Person';
    return label.replaceFirst(label[0], label[0].toUpperCase());
  }
}
