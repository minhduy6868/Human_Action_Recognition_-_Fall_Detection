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

  Future<List<dynamic>> getChatHistory({int limit = 100}) async {
    final resp = await _client.getJson('/chat/history?limit=$limit', auth: true);
    return _extractList(resp);
  }

  Future<Map<String, dynamic>> askAssistant(
    String question, {
    int? windowMs,
  }) async {
    final body = <String, dynamic>{'question': question};
    if (windowMs != null && windowMs > 0) {
      body['window_ms'] = windowMs;
    }
    final resp = await _client.postJson('/chat/query', body: body, auth: true);
    return resp['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> summarizeActivity({
    required String question,
    required DateTime from,
    required DateTime to,
    List<String> sourceIds = const [],
  }) async {
    final body = <String, dynamic>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'question': question,
    };
    if (sourceIds.isNotEmpty) {
      body['source_ids'] = sourceIds;
    }
    final resp = await _client.postJson('/summary/query', body: body, auth: true);
    return resp['data'] as Map<String, dynamic>;
  }
}
