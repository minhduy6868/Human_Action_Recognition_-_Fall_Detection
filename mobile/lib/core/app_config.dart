import 'package:flutter/foundation.dart';

class AppConfig {
  static String get _backendHost {
    const backendHost = String.fromEnvironment('BACKEND_HOST');
    if (backendHost.isNotEmpty) {
      return backendHost;
    }

    if (kIsWeb) {
      return '127.0.0.1:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '192.168.1.5:8000'; // Updated to current PC IP
      case TargetPlatform.iOS:
        return '127.0.0.1:8000';
      default:
        return '127.0.0.1:8000';
    }
  }

  static String get apiBaseUrl => String.fromEnvironment(
        'API_BASE_URL',
      defaultValue: 'http://$_backendHost/api/v1',
      );

  static String get wsUrl => String.fromEnvironment(
        'WS_URL',
      defaultValue: 'ws://$_backendHost/api/v1/ws',
      );

  static String get camerasUrl => String.fromEnvironment(
        'CAMERAS_URL',
      defaultValue: 'http://$_backendHost/api/v1/cameras',
      );

  static String get mjpegUrl => String.fromEnvironment(
        'MJPEG_URL',
      defaultValue: 'http://$_backendHost/api/v1/stream/mjpeg',
      );
}
