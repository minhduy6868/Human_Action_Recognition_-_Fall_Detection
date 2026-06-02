import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/realtime_status.dart';
import '../../services/realtime_stream.dart';
import '../../services/sources_api.dart';
import 'camera_monitor_state.dart';

class CameraMonitorCubit extends Cubit<CameraMonitorState> {
  CameraMonitorCubit(this._stream, this._sourcesApi)
      : super(CameraMonitorState.initial());

  final RealtimeStream _stream;
  final SourcesApi _sourcesApi;
  StreamSubscription? _subscription;
  WebSocketChannel? _channel;
  int _connectSession = 0;

  void initialize() {
    emit(state.copyWith(
      logs: _appendSystemLog(state.logs, 'Connecting to backend stream...'),
    ));
    connect();
    loadSources();
  }

  Future<void> connect() async {
    final session = ++_connectSession;
    await _disconnect();

    try {
      final channel = _stream.connect();
      await channel.ready;
      if (isClosed || session != _connectSession) {
        await _closeChannel(channel);
        return;
      }

      _channel = channel;
      emit(state.copyWith(isConnected: true, error: null));

      _subscription = channel.stream.listen(
        (message) {
          if (isClosed || session != _connectSession) return;
          try {
            final map = _stream.decodeMessage(message);
            final status = RealtimeStatus.fromMap(map);
            emit(state.copyWith(
              status: status,
              isConnected: true,
              logs: _appendLog(state.logs, status),
            ));
          } catch (e) {
            emit(state.copyWith(
              isConnected: false,
              error: e.toString(),
            ));
          }
        },
        onError: (error) {
          if (isClosed || session != _connectSession) return;
          emit(state.copyWith(
            isConnected: false,
            error: error.toString(),
            logs: _appendSystemLog(
                state.logs, 'WebSocket error: ${error.toString()}'),
          ));
          unawaited(_disconnect());
        },
        onDone: () {
          if (isClosed || session != _connectSession) return;
          emit(state.copyWith(
            isConnected: false,
            logs: _appendSystemLog(state.logs, 'Backend stream closed.'),
          ));
          unawaited(_disconnect());
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (isClosed || session != _connectSession) return;
      emit(state.copyWith(
        isConnected: false,
        error: e.toString(),
        logs: _appendSystemLog(state.logs, 'Connect failed: $e'),
      ));
    }
  }

  Future<void> disconnect() => _disconnect();

  Future<void> _disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    await _closeChannel(channel);
  }

  Future<void> _closeChannel(WebSocketChannel? channel) async {
    if (channel == null) return;
    try {
      await channel.sink.close();
    } catch (_) {}
  }

  Future<void> loadSources() async {
    emit(state.copyWith(isLoadingSources: true));
    try {
      final sources = await _sourcesApi.listSources();
      final activeIndex = sources.indexWhere((source) => source.isActive);
      final selectedIndex = activeIndex >= 0 ? activeIndex : -1;
      emit(state.copyWith(
        sources: sources,
        selectedIndex: selectedIndex,
        isLoadingSources: false,
      ));
    } catch (error) {
      emit(state.copyWith(
        isLoadingSources: false,
        error: error.toString(),
      ));
    }
  }

  Future<void> selectSource(int index) async {
    if (index < 0 || index >= state.sources.length) {
      return;
    }

    final source = state.sources[index];
    emit(state.copyWith(selectedIndex: index, error: null));

    try {
      await _sourcesApi.activateSource(source.id);
      await loadSources();
    } catch (error) {
      emit(state.copyWith(error: error.toString()));
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
  Future<void> close() async {
    _connectSession++;
    await _disconnect();
    return super.close();
  }
}
