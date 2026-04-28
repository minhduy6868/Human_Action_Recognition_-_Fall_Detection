import '../../../models/realtime_status.dart';

class RealtimeState {
  const RealtimeState({
    required this.status,
    required this.isConnected,
    required this.error,
  });

  final RealtimeStatus status;
  final bool isConnected;
  final String? error;

  RealtimeState copyWith({
    RealtimeStatus? status,
    bool? isConnected,
    String? error,
  }) {
    return RealtimeState(
      status: status ?? this.status,
      isConnected: isConnected ?? this.isConnected,
      error: error,
    );
  }

  static RealtimeState initial() {
    return RealtimeState(
      status: RealtimeStatus.fromMap(const {}),
      isConnected: false,
      error: null,
    );
  }
}
