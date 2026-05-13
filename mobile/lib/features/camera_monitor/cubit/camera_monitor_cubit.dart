import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/realtime_status.dart';
import '../../../services/realtime_stream.dart';
import '../../../services/camera_api.dart';
import 'camera_monitor_state.dart';

class CameraMonitorCubit extends Cubit<CameraMonitorState> {
  CameraMonitorCubit(this._stream, this._cameraApi)
      : super(CameraMonitorState.initial());

  final RealtimeStream _stream;
  final CameraApi _cameraApi;
  StreamSubscription? _subscription;

  void initialize() {
    emit(state.copyWith(
      logs: _appendSystemLog(state.logs, 'Connecting to backend stream...'),
    ));
    connect();
    loadCameras();
  }

  void connect() {
    final channel = _stream.connect();
    emit(state.copyWith(isConnected: true, error: null));

    _subscription = channel.stream.listen(
      (message) {
        final map = _stream.decodeMessage(message);
        final status = RealtimeStatus.fromMap(map);
        emit(state.copyWith(
          status: status,
          isConnected: true,
          logs: _appendLog(state.logs, status),
        ));
      },
      onError: (error) {
        emit(state.copyWith(
          isConnected: false,
          error: error.toString(),
          logs: _appendSystemLog(
              state.logs, 'WebSocket error: ${error.toString()}'),
        ));
      },
      onDone: () {
        emit(state.copyWith(
          isConnected: false,
          logs: _appendSystemLog(state.logs, 'Backend stream closed.'),
        ));
      },
    );
  }

  Future<void> loadCameras() async {
    emit(state.copyWith(isLoadingCameras: true));
    try {
      final response = await _cameraApi.fetchCameras();
      emit(state.copyWith(
        cameras: response.items,
        activeIndex: response.activeIndex,
        isLoadingCameras: false,
      ));
    } catch (error) {
      emit(state.copyWith(
        isLoadingCameras: false,
        error: error.toString(),
      ));
    }
  }

  List<String> _appendLog(List<String> logs, RealtimeStatus status) {
    final timestamp = status.timestampMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(status.timestampMs)
        : DateTime.now();
    final line =
        '[${_formatTime(timestamp)}] action=${status.action} conf=${status.confidence.toStringAsFixed(2)} fall=${status.fall} track=${status.trackId}';

    final updated = List<String>.from(logs)..add(line);
    if (updated.length > 50) {
      return updated.sublist(updated.length - 50);
    }
    return updated;
  }

  List<String> _appendSystemLog(List<String> logs, String message) {
    final timestamp = _formatTime(DateTime.now());
    final updated = List<String>.from(logs)..add('[$timestamp] $message');
    if (updated.length > 50) {
      return updated.sublist(updated.length - 50);
    }
    return updated;
  }

  String _formatTime(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
