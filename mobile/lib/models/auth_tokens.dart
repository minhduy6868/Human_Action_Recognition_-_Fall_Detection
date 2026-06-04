/// Dữ liệu token trả về từ các API xác thực của backend.
class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshExpiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final int refreshExpiresIn;

  /// Tạo đối tượng token từ JSON backend trả về.
  factory AuthTokens.fromMap(Map<String, dynamic> map) {
    return AuthTokens(
      accessToken: map['access_token'] as String,
      refreshToken: map['refresh_token'] as String,
      tokenType: map['token_type'] as String? ?? 'bearer',
      expiresIn: map['expires_in'] as int? ?? 0,
      refreshExpiresIn: map['refresh_expires_in'] as int? ?? 0,
    );
  }
}
