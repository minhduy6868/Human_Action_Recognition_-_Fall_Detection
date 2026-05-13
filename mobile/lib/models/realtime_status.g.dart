// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realtime_status.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RealtimeStatus extends RealtimeStatus {
  @override
  final String action;
  @override
  final double confidence;
  @override
  final bool fall;
  @override
  final double fall_confidence;
  @override
  final int timestamp_ms;
  @override
  final String track_id;

  factory _$RealtimeStatus([void Function(RealtimeStatusBuilder)? updates]) =>
      (RealtimeStatusBuilder()..update(updates))._build();

  _$RealtimeStatus._(
      {required this.action,
      required this.confidence,
      required this.fall,
      required this.fall_confidence,
      required this.timestamp_ms,
      required this.track_id})
      : super._();
  @override
  RealtimeStatus rebuild(void Function(RealtimeStatusBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RealtimeStatusBuilder toBuilder() => RealtimeStatusBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RealtimeStatus &&
        action == other.action &&
        confidence == other.confidence &&
        fall == other.fall &&
        fall_confidence == other.fall_confidence &&
        timestamp_ms == other.timestamp_ms &&
        track_id == other.track_id;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, confidence.hashCode);
    _$hash = $jc(_$hash, fall.hashCode);
    _$hash = $jc(_$hash, fall_confidence.hashCode);
    _$hash = $jc(_$hash, timestamp_ms.hashCode);
    _$hash = $jc(_$hash, track_id.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RealtimeStatus')
          ..add('action', action)
          ..add('confidence', confidence)
          ..add('fall', fall)
          ..add('fall_confidence', fall_confidence)
          ..add('timestamp_ms', timestamp_ms)
          ..add('track_id', track_id))
        .toString();
  }
}

class RealtimeStatusBuilder
    implements Builder<RealtimeStatus, RealtimeStatusBuilder> {
  _$RealtimeStatus? _$v;

  String? _action;
  String? get action => _$this._action;
  set action(String? action) => _$this._action = action;

  double? _confidence;
  double? get confidence => _$this._confidence;
  set confidence(double? confidence) => _$this._confidence = confidence;

  bool? _fall;
  bool? get fall => _$this._fall;
  set fall(bool? fall) => _$this._fall = fall;

  double? _fall_confidence;
  double? get fall_confidence => _$this._fall_confidence;
  set fall_confidence(double? fall_confidence) =>
      _$this._fall_confidence = fall_confidence;

  int? _timestamp_ms;
  int? get timestamp_ms => _$this._timestamp_ms;
  set timestamp_ms(int? timestamp_ms) => _$this._timestamp_ms = timestamp_ms;

  String? _track_id;
  String? get track_id => _$this._track_id;
  set track_id(String? track_id) => _$this._track_id = track_id;

  RealtimeStatusBuilder();

  RealtimeStatusBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _action = $v.action;
      _confidence = $v.confidence;
      _fall = $v.fall;
      _fall_confidence = $v.fall_confidence;
      _timestamp_ms = $v.timestamp_ms;
      _track_id = $v.track_id;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RealtimeStatus other) {
    _$v = other as _$RealtimeStatus;
  }

  @override
  void update(void Function(RealtimeStatusBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RealtimeStatus build() => _build();

  _$RealtimeStatus _build() {
    final _$result = _$v ??
        _$RealtimeStatus._(
          action: BuiltValueNullFieldError.checkNotNull(
              action, r'RealtimeStatus', 'action'),
          confidence: BuiltValueNullFieldError.checkNotNull(
              confidence, r'RealtimeStatus', 'confidence'),
          fall: BuiltValueNullFieldError.checkNotNull(
              fall, r'RealtimeStatus', 'fall'),
          fall_confidence: BuiltValueNullFieldError.checkNotNull(
              fall_confidence, r'RealtimeStatus', 'fall_confidence'),
          timestamp_ms: BuiltValueNullFieldError.checkNotNull(
              timestamp_ms, r'RealtimeStatus', 'timestamp_ms'),
          track_id: BuiltValueNullFieldError.checkNotNull(
              track_id, r'RealtimeStatus', 'track_id'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
