import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/realtime_status.dart';
import '../../services/realtime_stream.dart';
import '../../utils/action_vote_buffer.dart';
import 'realtime_state.dart';

class RealtimeCubit extends Cubit<RealtimeState> {
  RealtimeCubit(this._stream) : super(RealtimeState.initial());

  final RealtimeStream _stream;
  StreamSubscription? _subscription;
  WebSocketChannel? _channel;
  int _connectSession = 0;
  final Map<String, ActionVoteBuffer> _actionBuffers = {};

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
            final raw = RealtimeStatus.fromMap(map);
            final status = _smoothActions(raw);
            emit(state.copyWith(status: status, isConnected: true, error: null));
          } catch (e) {
            emit(state.copyWith(isConnected: false, error: e.toString()));
          }
        },
        onError: (error) {
          if (isClosed || session != _connectSession) return;
          emit(state.copyWith(isConnected: false, error: error.toString()));
          unawaited(_disconnect());
        },
        onDone: () {
          if (isClosed || session != _connectSession) return;
          emit(state.copyWith(isConnected: false));
          unawaited(_disconnect());
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (isClosed || session != _connectSession) return;
      emit(state.copyWith(isConnected: false, error: e.toString()));
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

  @override
  Future<void> close() async {
    _connectSession++;
    await _disconnect();
    _actionBuffers.clear();
    return super.close();
  }

  RealtimeStatus _smoothActions(RealtimeStatus raw) {
    final perTrack = <String, (String, double)>{};
    perTrack[raw.trackId] = (raw.action, raw.confidence);
    for (final p in raw.people) {
      perTrack.putIfAbsent(p.trackId, () => (p.action, p.confidence));
    }

    final smoothed = <String, ({String action, double confidence})>{};
    for (final e in perTrack.entries) {
      final buf = _actionBuffers.putIfAbsent(e.key, ActionVoteBuffer.new);
      smoothed[e.key] = buf.push(e.value.$1, e.value.$2);
    }

    final main = smoothed[raw.trackId];
    final newAction = main?.action ?? raw.action;
    final newConf = main?.confidence ?? raw.confidence;

    final newPeople = raw.people.map((p) {
      final s = smoothed[p.trackId];
      if (s == null) return p;
      return p.copyWith(action: s.action, confidence: s.confidence);
    }).toList();

    return raw.copyWith(
      action: newAction,
      confidence: newConf,
      people: newPeople,
    );
  }
}
