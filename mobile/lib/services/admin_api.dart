import '../models/user_profile.dart';
import 'api_client.dart';

class AdminApi {
  AdminApi(this.client);

  final ApiClient client;

  Future<AdminStats> getStats() async {
    final payload = await client.getJson('/admin/stats', auth: true);
    final data = payload['data'] as Map<String, dynamic>;
    return AdminStats.fromMap(data);
  }

  Future<List<UserProfile>> listUsers({
    String? query,
    String? plan,
    String? role,
  }) async {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (plan != null && plan.isNotEmpty) {
      params['plan'] = plan;
    }
    if (role != null && role.isNotEmpty) {
      params['role'] = role;
    }
    final queryString = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final payload = await client.getJson('/admin/users$queryString', auth: true);
    final data = payload['data'] as List<dynamic>;
    return data
        .map((item) => UserProfile.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminUserSource>> listUserSources(String userId) async {
    final payload = await client.getJson('/admin/users/$userId/sources', auth: true);
    final data = payload['data'] as List<dynamic>;
    return data
        .map((item) => AdminUserSource.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserProfile> updateUser(
    String userId, {
    String? name,
    String? role,
    String? plan,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (role != null) body['role'] = role;
    if (plan != null) body['plan'] = plan;
    final payload = await client.patchJson(
      '/admin/users/$userId',
      body: body,
      auth: true,
    );
    final data = payload['data'] as Map<String, dynamic>;
    return UserProfile.fromMap(data);
  }

  Future<void> deleteUser(String userId) async {
    await client.deleteJson('/admin/users/$userId', auth: true);
  }
}
