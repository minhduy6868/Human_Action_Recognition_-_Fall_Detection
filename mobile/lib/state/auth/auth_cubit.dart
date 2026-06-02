import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/auth_api.dart';
import '../../services/push_notification_service.dart';
import '../../services/sources_api.dart';
import '../../shared_customization/helpers/utilizations/storages.dart';
import '../../get_it_dependencies.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authApi, this._storage) : super(AuthState.loading());

  final AuthApi _authApi;
  final CustomSharedPreferences _storage;

  Future<void> bootstrap() async {
    if (_storage.refreshToken == null && _storage.accessToken == null) {
      emit(AuthState.unauthenticated());
      return;
    }

    try {
      if (_storage.refreshToken != null) {
        await _authApi.refresh();
      }
      final user = await _authApi.me();
      emit(AuthState.authenticated(user));
    } catch (e) {
      await _storage.clear();
      emit(AuthState.unauthenticated(error: e.toString()));
    }
  }

  Future<void> login(String email, String password) async {
    emit(AuthState.loading());
    try {
      await _authApi.login(email, password);
      final user = await _authApi.me();
      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.unauthenticated(error: e.toString()));
    }
  }

  Future<void> loginWithGoogle(String idToken) async {
    emit(AuthState.loading());
    try {
      await _authApi.loginWithGoogle(idToken);
      final user = await _authApi.me();
      emit(AuthState.authenticated(user));
    } catch (e) {
      emit(AuthState.unauthenticated(error: e.toString()));
    }
  }

  Future<void> refreshProfile() async {
    final user = await _authApi.me();
    if (state.status == AuthStatus.authenticated) {
      emit(AuthState.authenticated(user));
    }
  }

  Future<void> logout() async {
    emit(AuthState.loading());
    try {
      try {
        await getIt<PushNotificationService>().unregister();
      } catch (_) {}
      await _authApi.logout();
    } catch (_) {
      await _storage.clear();
    }
    // Try to stop active streams for this user (best-effort)
    try {
      final sourcesApi = getIt<SourcesApi>();
      final list = await sourcesApi.listSources();
      for (final s in list) {
        if (s.isActive) {
          await sourcesApi.stopStream(s.id);
        }
      }
    } catch (_) {}

    emit(AuthState.unauthenticated());
  }
}
