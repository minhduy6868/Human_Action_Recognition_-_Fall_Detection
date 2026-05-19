import '../../models/camera_info.dart';
import '../../models/realtime_status.dart';

class CameraMonitorState {
  const CameraMonitorState({
    required this.status,
    required this.isConnected,
    required this.error,
    required this.logs,
    required this.cameras,
    required this.activeIndex,
    required this.isLoadingCameras,
  });

  final RealtimeStatus status;
  final bool isConnected;
  final String? error;
  final List<String> logs;
  final List<CameraInfo> cameras;
  final int activeIndex;
  final bool isLoadingCameras;

  CameraMonitorState copyWith({
    RealtimeStatus? status,
    bool? isConnected,
    String? error,
    List<String>? logs,
    List<CameraInfo>? cameras,
    int? activeIndex,
    bool? isLoadingCameras,
  }) {
    return CameraMonitorState(
      status: status ?? this.status,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      logs: logs ?? this.logs,
      cameras: cameras ?? this.cameras,
      activeIndex: activeIndex ?? this.activeIndex,
      isLoadingCameras: isLoadingCameras ?? this.isLoadingCameras,
    );
  }

  static CameraMonitorState initial() {
    return CameraMonitorState(
      status: RealtimeStatus.initial(),
      isConnected: false,
      error: null,
      logs: const [],
      cameras: const [],
      activeIndex: 0,
      isLoadingCameras: false,
    );
  }
}
