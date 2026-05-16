import '../models/camera_info.dart';
import 'api_client.dart';

class CameraApi {
  CameraApi(this.client);

  final ApiClient client;

  Future<CameraList> fetchCameras() async {
    final payload = await client.getJson('/cameras', auth: true);
    final data = payload['data'] as Map<String, dynamic>;
    return CameraList.fromMap(data);
  }
}
