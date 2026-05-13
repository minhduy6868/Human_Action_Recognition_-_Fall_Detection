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
        return '10.0.2.2:8000';
      case TargetPlatform.iOS:
        return '127.0.0.1:8000';
      default:
        return '127.0.0.1:8000';
    }
  }

  static String get apiBaseUrl => String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://$_backendHost/api',
      );

  static String get wsUrl => String.fromEnvironment(
        'WS_URL',
        defaultValue: 'ws://$_backendHost/api/ws',
      );

  static String get camerasUrl => String.fromEnvironment(
        'CAMERAS_URL',
        defaultValue: 'http://$_backendHost/api/cameras',
      );

  static String get mjpegUrl => String.fromEnvironment(
        'MJPEG_URL',
        defaultValue: 'http://$_backendHost/api/stream/mjpeg',
      );
}
