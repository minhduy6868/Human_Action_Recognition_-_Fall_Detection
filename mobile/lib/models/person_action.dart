class PersonClothing {
  const PersonClothing({
    required this.upper,
    required this.lower,
  });

  final String upper;
  final String lower;

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

  final String trackId;
  final String action;
  final double confidence;
  final bool fall;
  final double fallConfidence;
  final double bboxX1;
  final double bboxY1;
  final double bboxX2;
  final double bboxY2;
  final PersonClothing clothing;
  final String personId;

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

  /// Get action display name
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

  /// Get clothing description
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
