import 'api_client.dart';

class MonitoringApi {
  MonitoringApi(this._client);

  final ApiClient _client;

  List<dynamic> _extractList(Map<String, dynamic> payload) {
    if (payload.containsKey('items') && payload['items'] is List) return payload['items'] as List<dynamic>;
    if (payload.containsKey('data') && payload['data'] is List) return payload['data'] as List<dynamic>;
    if (payload.containsKey('results') && payload['results'] is List) return payload['results'] as List<dynamic>;
    // Fallback: return empty list
    return [];
  }

  Future<List<dynamic>> getReports({int limit = 100}) async {
    final resp = await _client.getJson('/reports?limit=$limit', auth: true);
    return _extractList(resp);
  }

  Future<List<dynamic>> getHistory({int limit = 200}) async {
    final resp = await _client.getJson('/history?limit=$limit', auth: true);
    return _extractList(resp);
  }

  Future<List<dynamic>> getLogs({int limit = 200}) async {
    final resp = await _client.getJson('/logs?limit=$limit', auth: true);
    return _extractList(resp);
  }

  Future<List<dynamic>> getAlerts({int limit = 200}) async {
    final resp = await _client.getJson('/alerts?limit=$limit', auth: true);
    return _extractList(resp);
  }
}
