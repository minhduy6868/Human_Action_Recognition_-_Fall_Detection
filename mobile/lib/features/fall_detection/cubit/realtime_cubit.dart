import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/realtime_status.dart';
import '../../../services/realtime_stream.dart';
import '../utils/action_vote_buffer.dart';
import 'realtime_state.dart';

class RealtimeCubit extends Cubit<RealtimeState> {
  RealtimeCubit(this._stream) : super(RealtimeState.initial());

  final RealtimeStream _stream;
  StreamSubscription? _subscription;
  int _connectSession = 0;
  final Map<String, ActionVoteBuffer> _actionBuffers = {};

  Future<void> connect() async {
    final session = ++_connectSession;
    await _subscription?.cancel();
    _subscription = null;

    try {
      print('[RealtimeCubit] Connecting to: ${_stream.url}');
      final channel = _stream.connect();
      await channel.ready;
      print('[RealtimeCubit] Connected successfully!');
      
      if (isClosed || session != _connectSession) {
        unawaited(channel.sink.close());
        return;
      }
      emit(state.copyWith(isConnected: true, error: null));

      _subscription = channel.stream.listen(
        (message) {
          final map = _stream.decodeMessage(message);
          final raw = RealtimeStatus.fromMap(map);
          final status = _smoothActions(raw);
          emit(state.copyWith(status: status, isConnected: true));
        },
        onError: (error) {
          print('[RealtimeCubit] Stream error: $error');
          emit(state.copyWith(isConnected: false, error: error.toString()));
        },
        onDone: () {
          print('[RealtimeCubit] Stream closed by server');
          emit(state.copyWith(isConnected: false));
        },
      );
    } catch (e) {
      print('[RealtimeCubit] Connection failed: $e');
      if (isClosed || session != _connectSession) return;
      emit(state.copyWith(isConnected: false, error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _connectSession++;
    _subscription?.cancel();
    _subscription = null;
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
