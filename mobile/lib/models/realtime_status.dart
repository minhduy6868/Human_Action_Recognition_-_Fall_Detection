import 'detected_object.dart';
import 'person_action.dart';

class RealtimeStatus {
  const RealtimeStatus({
    required this.action,
    required this.confidence,
    required this.fall,
    required this.fallConfidence,
    required this.timestampMs,
    required this.trackId,
    this.people = const [],
    this.objects = const [],
  });

  final String action;
  final double confidence;
  final bool fall;
  final double fallConfidence;
  final int timestampMs;
  final String trackId;
  final List<PersonAction> people;
  final List<DetectedObject> objects;

  factory RealtimeStatus.initial() {
    return const RealtimeStatus(
      action: 'unknown',
      confidence: 0.0,
      fall: false,
      fallConfidence: 0.0,
      timestampMs: 0,
      trackId: '0',
      people: [],
      objects: [],
    );
  }

  factory RealtimeStatus.fromMap(Map<String, dynamic> map) {
    // Parse people list
    final peopleList = (map['people'] as List<dynamic>?)
        ?.map((item) => PersonAction.fromMap(item as Map<String, dynamic>))
        .toList() ??
        [];

    // Parse objects list
    final objectsList = (map['objects'] as List<dynamic>?)
        ?.map((item) => DetectedObject.fromMap(item as Map<String, dynamic>))
        .toList() ??
        [];

    return RealtimeStatus(
      action: (map['action'] as String?) ?? 'unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      fall: (map['fall'] as bool?) ?? false,
      fallConfidence: (map['fall_confidence'] as num?)?.toDouble() ?? 0.0,
      timestampMs: (map['timestamp_ms'] as num?)?.toInt() ?? 0,
      trackId: (map['track_id'] as String?) ?? '0',
      people: peopleList,
      objects: objectsList,
    );
  }

  RealtimeStatus copyWith({
    String? action,
    double? confidence,
    bool? fall,
    double? fallConfidence,
    int? timestampMs,
    String? trackId,
    List<PersonAction>? people,
    List<DetectedObject>? objects,
  }) {
    return RealtimeStatus(
      action: action ?? this.action,
      confidence: confidence ?? this.confidence,
      fall: fall ?? this.fall,
      fallConfidence: fallConfidence ?? this.fallConfidence,
      timestampMs: timestampMs ?? this.timestampMs,
      trackId: trackId ?? this.trackId,
      people: people ?? this.people,
      objects: objects ?? this.objects,
    );
  }
}
