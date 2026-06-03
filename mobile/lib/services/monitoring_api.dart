import 'api_client.dart';

class MonitoringApi {
  MonitoringApi(this._client);

  final ApiClient _client;

  List<dynamic> _extractList(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      if (data['items'] is List) return data['items'] as List<dynamic>;
      if (data['results'] is List) return data['results'] as List<dynamic>;
    }
    if (payload['items'] is List) return payload['items'] as List<dynamic>;
    if (payload['results'] is List) return payload['results'] as List<dynamic>;
    return [];
  }

  Future<List<dynamic>> getReports({
    int limit = 100,
    String? sourceId,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (sourceId != null && sourceId.isNotEmpty) {
      params['source_id'] = sourceId;
    }
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final resp = await _client.getJson('/reports?$query', auth: true);
    return _extractList(resp);
  }

  Future<List<dynamic>> getHistory({
    int limit = 200,
    String? sourceId,
    int? fromMs,
    int? toMs,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (sourceId != null && sourceId.isNotEmpty) {
      params['source_id'] = sourceId;
    }
    if (fromMs != null) params['from_ms'] = '$fromMs';
    if (toMs != null) params['to_ms'] = '$toMs';
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final resp = await _client.getJson('/history?$query', auth: true);
    return _extractList(resp);
  }

  Future<List<dynamic>> getLogs({
    int limit = 500,
    String? sourceId,
    int? fromMs,
    int? toMs,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
    };
    if (sourceId != null && sourceId.isNotEmpty) {
      params['source_id'] = sourceId;
    }
    if (fromMs != null) {
      params['from_ms'] = '$fromMs';
    }
    if (toMs != null) {
      params['to_ms'] = '$toMs';
    }
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final resp = await _client.getJson('/logs?$query', auth: true);
    return _extractList(resp);
  }

  Future<Map<String, dynamic>> getStreamStatus(String sourceId) async {
    final resp = await _client.getJson('/streams/$sourceId/status', auth: true);
    final data = resp['data'];
    if (data is Map<String, dynamic>) return data;
    return {};
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
    String? sourceId,
  }) async {
    final body = <String, dynamic>{'question': question};
    if (windowMs != null && windowMs > 0) {
      body['window_ms'] = windowMs;
    }
    if (sourceId != null && sourceId.isNotEmpty) {
      body['source_id'] = sourceId;
    }
    final resp = await _client.postJson('/chat/query', body: body, auth: true);
    final data = resp['data'];
    if (data is Map<String, dynamic>) return data;
    return resp;
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
    final data = resp['data'];
    if (data is Map<String, dynamic>) return data;
    return resp;
  }
}
