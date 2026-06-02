import '../../models/source.dart';
import '../../models/realtime_status.dart';

class CameraMonitorState {
  const CameraMonitorState({
    required this.status,
    required this.isConnected,
    required this.error,
    required this.logs,
    required this.sources,
    required this.selectedIndex,
    required this.isLoadingSources,
  });

  final RealtimeStatus status;
  final bool isConnected;
  final String? error;
  final List<String> logs;
  final List<Source> sources;
  final int selectedIndex;
  final bool isLoadingSources;

  Source? get selectedSource {
    if (sources.isEmpty || selectedIndex < 0) {
      return null;
    }
    final index = selectedIndex.clamp(0, sources.length - 1);
    return sources[index];
  }

  CameraMonitorState copyWith({
    RealtimeStatus? status,
    bool? isConnected,
    String? error,
    List<String>? logs,
    List<Source>? sources,
    int? selectedIndex,
    bool? isLoadingSources,
  }) {
    return CameraMonitorState(
      status: status ?? this.status,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      logs: logs ?? this.logs,
      sources: sources ?? this.sources,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoadingSources: isLoadingSources ?? this.isLoadingSources,
    );
  }

  static CameraMonitorState initial() {
    return CameraMonitorState(
      status: RealtimeStatus.initial(),
      isConnected: false,
      error: null,
      logs: const [],
      sources: const [],
      selectedIndex: -1,
      isLoadingSources: false,
    );
  }
}
