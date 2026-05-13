import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../models/camera_info.dart';

class CameraApi {
  Future<CameraList> fetchCameras() async {
    final response = await http.get(Uri.parse(AppConfig.camerasUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load cameras: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return CameraList.fromMap(payload);
  }
}
