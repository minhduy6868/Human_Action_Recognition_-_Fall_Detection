import 'detected_object.dart';
import 'person_action.dart';

/// Trạng thái realtime mới nhất được backend gửi qua WebSocket.
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

  /// Nhãn hành động chính của frame hiện tại.
  final String action;

  /// Độ tin cậy của hành động chính trong khoảng 0.0-1.0.
  final double confidence;

  /// Đúng khi backend đang phát hiện có té ngã.
  final bool fall;

  /// Độ tin cậy của phát hiện té ngã trong khoảng 0.0-1.0.
  final double fallConfidence;

  /// Thời gian backend gửi về, tính bằng mili giây từ epoch.
  final int timestampMs;

  /// Mã track chính được backend chọn.
  final String trackId;

  /// Chi tiết hành động và té ngã theo từng người.
  final List<PersonAction> people;

  /// Tất cả vật thể được phát hiện trong frame hiện tại.
  final List<DetectedObject> objects;

  /// Trạng thái rỗng dùng trước khi nhận message WebSocket đầu tiên.
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

  /// Chuyển JSON từ WebSocket backend thành đối tượng [RealtimeStatus].
  factory RealtimeStatus.fromMap(Map<String, dynamic> map) {
    // Đọc danh sách người từ payload backend.
    final peopleList = (map['people'] as List<dynamic>?)
        ?.map((item) => PersonAction.fromMap(item as Map<String, dynamic>))
        .toList() ??
        [];

    // Đọc danh sách vật thể từ payload backend.
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

  /// Tạo bản sao mới và thay thế các trường được truyền vào.
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
