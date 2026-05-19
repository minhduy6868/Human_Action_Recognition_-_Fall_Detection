import '../models/source.dart';
import 'api_client.dart';

class SourcesApi {
  SourcesApi(this.client);

  final ApiClient client;

  Future<List<Source>> listSources() async {
    final payload = await client.getJson('/sources', auth: true);
    final data = payload['data'] as List<dynamic>;
    return data.map((e) => Source.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> activateSource(String sourceId) async {
    await client.postJson('/sources/$sourceId/activate', auth: true);
  }

  Future<void> stopStream(String sourceId) async {
    await client.postJson('/streams/stop', body: {'source_id': sourceId}, auth: true);
  }

  Future<Source> createSource(String name, String sourceType, String sourceUrl, {bool isActive = false}) async {
    final payload = await client.postJson('/sources', body: {
      'name': name,
      'source_type': sourceType,
      'source_url': sourceUrl,
      'is_active': isActive,
    }, auth: true);
    final data = payload['data'] as Map<String, dynamic>;
    return Source.fromMap(data);
  }

  Future<void> deleteSource(String sourceId) async {
    await client.deleteJson('/sources/$sourceId', auth: true);
  }

  Future<void> patchSource(String sourceId, Map<String, dynamic> body) async {
    await client.patchJson('/sources/$sourceId', body: body, auth: true);
  }
}
