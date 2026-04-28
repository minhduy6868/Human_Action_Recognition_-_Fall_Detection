import 'package:built_value/built_value.dart';

part 'realtime_status.g.dart';

abstract class RealtimeStatus
    implements Built<RealtimeStatus, RealtimeStatusBuilder> {
  String get action;
  double get confidence;
  bool get fall;
  int get timestampMs;
  String get trackId;

  RealtimeStatus._();

  factory RealtimeStatus([void Function(RealtimeStatusBuilder) updates]) =
      _$RealtimeStatus;

  factory RealtimeStatus.fromMap(Map<String, dynamic> map) {
    return RealtimeStatus(
      (b) => b
        ..action = (map['action'] as String?) ?? 'unknown'
        ..confidence = (map['confidence'] as num?)?.toDouble() ?? 0.0
        ..fall = (map['fall'] as bool?) ?? false
        ..timestampMs = (map['timestamp_ms'] as int?) ?? 0
        ..trackId = (map['track_id'] as String?) ?? '0',
    );
  }
}
