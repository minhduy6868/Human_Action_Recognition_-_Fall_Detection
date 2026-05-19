import '../../models/user_profile.dart';

enum AuthStatus {
  loading,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    required this.user,
    required this.error,
  });

  final AuthStatus status;
  final UserProfile? user;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }

  factory AuthState.loading() {
    return const AuthState(status: AuthStatus.loading, user: null, error: null);
  }

  factory AuthState.unauthenticated({String? error}) {
    return AuthState(status: AuthStatus.unauthenticated, user: null, error: error);
  }

  factory AuthState.authenticated(UserProfile user) {
    return AuthState(status: AuthStatus.authenticated, user: user, error: null);
  }
}
