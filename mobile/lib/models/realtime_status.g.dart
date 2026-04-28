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
  final int timestampMs;
  @override
  final String trackId;

  factory _$RealtimeStatus([void Function(RealtimeStatusBuilder)? updates]) =>
      (RealtimeStatusBuilder()..update(updates))._build();

  _$RealtimeStatus._(
      {required this.action,
      required this.confidence,
      required this.fall,
      required this.timestampMs,
      required this.trackId})
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
        timestampMs == other.timestampMs &&
        trackId == other.trackId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, confidence.hashCode);
    _$hash = $jc(_$hash, fall.hashCode);
    _$hash = $jc(_$hash, timestampMs.hashCode);
    _$hash = $jc(_$hash, trackId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RealtimeStatus')
          ..add('action', action)
          ..add('confidence', confidence)
          ..add('fall', fall)
          ..add('timestampMs', timestampMs)
          ..add('trackId', trackId))
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

  int? _timestampMs;
  int? get timestampMs => _$this._timestampMs;
  set timestampMs(int? timestampMs) => _$this._timestampMs = timestampMs;

  String? _trackId;
  String? get trackId => _$this._trackId;
  set trackId(String? trackId) => _$this._trackId = trackId;

  RealtimeStatusBuilder();

  RealtimeStatusBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _action = $v.action;
      _confidence = $v.confidence;
      _fall = $v.fall;
      _timestampMs = $v.timestampMs;
      _trackId = $v.trackId;
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
          timestampMs: BuiltValueNullFieldError.checkNotNull(
              timestampMs, r'RealtimeStatus', 'timestampMs'),
          trackId: BuiltValueNullFieldError.checkNotNull(
              trackId, r'RealtimeStatus', 'trackId'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
