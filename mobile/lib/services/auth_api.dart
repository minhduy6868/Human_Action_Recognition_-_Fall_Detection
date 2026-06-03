import '../models/auth_tokens.dart';
import '../models/user_profile.dart';
import '../core/storage/app_storage.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi(this.client, this.storage);

  final ApiClient client;
  final CustomSharedPreferences storage;

  Future<AuthTokens> login(String email, String password) async {
    final payload = await client.postJson(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );
    final data = payload['data'] as Map<String, dynamic>;
    final tokens = AuthTokens.fromMap(data);
    await storage.setToken(tokens.accessToken, tokens.refreshToken);
    return tokens;
  }

  Future<AuthTokens> loginWithGoogle(String idToken) async {
    final payload = await client.postJson(
      '/auth/google',
      body: {
        'id_token': idToken,
      },
    );
    final data = payload['data'] as Map<String, dynamic>;
    final tokens = AuthTokens.fromMap(data);
    await storage.setToken(tokens.accessToken, tokens.refreshToken);
    return tokens;
  }

  Future<AuthTokens> refresh() async {
    final refreshToken = storage.refreshToken;
    if (refreshToken == null) {
      throw Exception('Missing refresh token');
    }
    final payload = await client.postJson(
      '/auth/refresh',
      body: {
        'refresh_token': refreshToken,
      },
    );
    final data = payload['data'] as Map<String, dynamic>;
    final tokens = AuthTokens.fromMap(data);
    await storage.setToken(tokens.accessToken, tokens.refreshToken);
    return tokens;
  }

  Future<void> logout() async {
    final refreshToken = storage.refreshToken;
    if (refreshToken != null) {
      await client.postJson(
        '/auth/logout',
        body: {
          'refresh_token': refreshToken,
        },
      );
    }
    await storage.clear();
  }

  Future<UserProfile> me() async {
    final payload = await client.getJson('/auth/me', auth: true);
    final data = payload['data'] as Map<String, dynamic>;
    return UserProfile.fromMap(data);
  }

  Future<AuthTokens> register(
      String email, String name, String password) async {
    final payload = await client.postJson(
      '/auth/register',
      body: {'email': email, 'name': name, 'password': password},
    );
    final data = payload['data'] as Map<String, dynamic>;
    final tokens = AuthTokens.fromMap(data);
    await storage.setToken(tokens.accessToken, tokens.refreshToken);
    return tokens;
  }

  Future<String?> requestOtp(String email, {String purpose = 'reset'}) async {
    final payload = await client.postJson('/auth/otp/request',
        body: {'email': email, 'purpose': purpose});
    final data = payload['data'] as Map<String, dynamic>;
    return data['otp'] as String?;
  }

  Future<bool> verifyOtp(String email, String otp,
      {String purpose = 'reset'}) async {
    final payload = await client.postJson('/auth/otp/verify',
        body: {'email': email, 'otp': otp, 'purpose': purpose});
    final data = payload['data'] as Map<String, dynamic>;
    return data['ok'] as bool;
  }

  Future<void> resetPassword(
      String email, String otp, String newPassword) async {
    await client.postJson('/auth/password/reset',
        body: {'email': email, 'otp': otp, 'new_password': newPassword});
  }

  Future<void> registerDeviceToken(String token,
      {String platform = 'unknown', String? sourceId}) async {
    await client.postJson(
      '/auth/device-token/register',
      body: {
        'token': token,
        'platform': platform,
        if (sourceId != null) 'source_id': sourceId,
      },
      auth: true,
    );
  }

  Future<void> removeDeviceToken(String token) async {
    await client.postJson(
      '/auth/device-token/remove',
      body: {'token': token},
      auth: true,
    );
  }
}
