import 'package:flutter/foundation.dart';

class AppConfig {
  static String get backendHost {
    const backendHost = String.fromEnvironment('BACKEND_HOST');
    if (backendHost.isNotEmpty) {
      return backendHost;
    }

    if (kIsWeb) {
      return '127.0.0.1:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2:8000';
      case TargetPlatform.iOS:
        return '127.0.0.1:8000';
      default:
        return '127.0.0.1:8000';
    }
  }

  static String get apiBaseUrl => String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://$backendHost/api/v1',
      );

  static String get wsUrl => String.fromEnvironment(
        'WS_URL',
        defaultValue: 'ws://$backendHost/api/v1/ws',
      );

  static String get camerasUrl => String.fromEnvironment(
        'CAMERAS_URL',
        defaultValue: 'http://$backendHost/api/v1/cameras',
      );

  static String get googleServerClientId => String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue: '',
      );

  static String get mjpegUrl => String.fromEnvironment(
        'MJPEG_URL',
        defaultValue: 'http://$backendHost/api/v1/stream/mjpeg',
      );

  static String sourceMjpegUrl(String sourceId) {
    return '$apiBaseUrl/streams/$sourceId/mjpeg';
  }
}
