import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/realtime_status.dart';
import '../../../services/realtime_stream.dart';
import 'realtime_state.dart';

class RealtimeCubit extends Cubit<RealtimeState> {
  RealtimeCubit(this._stream) : super(RealtimeState.initial());

  final RealtimeStream _stream;
  StreamSubscription? _subscription;

  void connect() {
    final channel = _stream.connect();
    emit(state.copyWith(isConnected: true, error: null));

    _subscription = channel.stream.listen(
      (message) {
        final map = _stream.decodeMessage(message);
        final status = RealtimeStatus.fromMap(map);
        emit(state.copyWith(status: status, isConnected: true));
      },
      onError: (error) {
        emit(state.copyWith(isConnected: false, error: error.toString()));
      },
      onDone: () {
        emit(state.copyWith(isConnected: false));
      },
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
