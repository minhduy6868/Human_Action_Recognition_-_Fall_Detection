/// Màu quần áo được phát hiện cho một người.
class PersonClothing {
  const PersonClothing({
    required this.upper,
    required this.lower,
  });

  /// Màu chủ đạo của phần áo.
  final String upper;

  /// Màu chủ đạo của phần quần.
  final String lower;

  /// Chuyển JSON backend thành dữ liệu màu quần áo.
  factory PersonClothing.fromMap(Map<String, dynamic> map) {
    return PersonClothing(
      upper: (map['upper'] as String?) ?? 'unknown',
      lower: (map['lower'] as String?) ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() => {
    'upper': upper,
    'lower': lower,
  };
}

/// Kết quả realtime về hành động và té ngã của từng người.
class PersonAction {
  const PersonAction({
    required this.trackId,
    required this.action,
    required this.confidence,
    required this.fall,
    required this.fallConfidence,
    required this.bboxX1,
    required this.bboxY1,
    required this.bboxX2,
    required this.bboxY2,
    this.clothing = const PersonClothing(upper: 'unknown', lower: 'unknown'),
    this.personId = '',
  });

  /// Mã tracker dùng để giữ cùng một người ổn định qua các frame.
  final String trackId;

  /// Nhãn hành động hiện tại do backend dự đoán.
  final String action;

  /// Độ tin cậy của hành động trong khoảng 0.0-1.0.
  final double confidence;

  /// Đúng khi người này đang được xem là bị ngã hoặc đã ngã.
  final bool fall;

  /// Độ tin cậy của phát hiện té ngã trong khoảng 0.0-1.0.
  final double fallConfidence;

  /// Tọa độ khung bao quanh người tính theo pixel ảnh.
  final double bboxX1;
  final double bboxY1;
  final double bboxX2;
  final double bboxY2;

  /// Mô tả màu quần áo nếu backend cung cấp.
  final PersonClothing clothing;

  /// Mã định danh người ổn định nếu backend có thể cung cấp.
  final String personId;

  /// Chuyển JSON backend thành đối tượng [PersonAction].
  factory PersonAction.fromMap(Map<String, dynamic> map) {
    return PersonAction(
      trackId: (map['track_id'] as String?) ?? '0',
      action: (map['action'] as String?) ?? 'unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      fall: (map['fall'] as bool?) ?? false,
      fallConfidence: (map['fall_confidence'] as num?)?.toDouble() ?? 0.0,
      bboxX1: (map['bbox_x1'] as num?)?.toDouble() ?? 0.0,
      bboxY1: (map['bbox_y1'] as num?)?.toDouble() ?? 0.0,
      bboxX2: (map['bbox_x2'] as num?)?.toDouble() ?? 0.0,
      bboxY2: (map['bbox_y2'] as num?)?.toDouble() ?? 0.0,
      clothing: map['clothing'] != null
          ? PersonClothing.fromMap(map['clothing'] as Map<String, dynamic>)
          : const PersonClothing(upper: 'unknown', lower: 'unknown'),
      personId: (map['person_id'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'track_id': trackId,
    'action': action,
    'confidence': confidence,
    'fall': fall,
    'fall_confidence': fallConfidence,
    'bbox_x1': bboxX1,
    'bbox_y1': bboxY1,
    'bbox_x2': bboxX2,
    'bbox_y2': bboxY2,
    'clothing': clothing.toMap(),
    'person_id': personId,
  };

  /// Tạo bản sao mới và thay thế các trường được truyền vào.
  PersonAction copyWith({
    String? trackId,
    String? action,
    double? confidence,
    bool? fall,
    double? fallConfidence,
    double? bboxX1,
    double? bboxY1,
    double? bboxX2,
    double? bboxY2,
    PersonClothing? clothing,
    String? personId,
  }) {
    return PersonAction(
      trackId: trackId ?? this.trackId,
      action: action ?? this.action,
      confidence: confidence ?? this.confidence,
      fall: fall ?? this.fall,
      fallConfidence: fallConfidence ?? this.fallConfidence,
      bboxX1: bboxX1 ?? this.bboxX1,
      bboxY1: bboxY1 ?? this.bboxY1,
      bboxX2: bboxX2 ?? this.bboxX2,
      bboxY2: bboxY2 ?? this.bboxY2,
      clothing: clothing ?? this.clothing,
      personId: personId ?? this.personId,
    );
  }

  /// Tên hành động để hiển thị cho người dùng.
  String get actionDisplay {
    switch (action.toLowerCase()) {
      case 'standing':
        return 'Standing';
      case 'walking':
        return 'Walking';
      case 'sitting':
        return 'Sitting';
      case 'lying':
        return 'Lying';
      case 'crouching':
        return 'Crouching';
      case 'running':
        return 'Running';
      default:
        return 'Unknown';
    }
  }

  /// Mô tả quần áo để hiển thị cho người dùng.
  String get clothingDescription {
    if (clothing.upper == 'unknown' && clothing.lower == 'unknown') {
      return 'Unknown clothing';
    }
    return '${_capitalizeColor(clothing.upper)} top, ${_capitalizeColor(clothing.lower)} bottom';
  }

  String _capitalizeColor(String color) {
    if (color.isEmpty || color == 'unknown') return 'unknown';
    return color[0].toUpperCase() + color.substring(1);
  }
}
