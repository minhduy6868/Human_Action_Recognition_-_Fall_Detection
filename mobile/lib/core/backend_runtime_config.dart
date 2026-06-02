import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class BackendRuntimeConfig {
  BackendRuntimeConfig({
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.camerasUrl,
    required this.mjpegUrl,
  });

  static const String defaultConfigSourceUrl =
      'https://love-app-19405-default-rtdb.asia-southeast1.firebasedatabase.app/.json';
  static const Duration configFetchTimeout = Duration(seconds: 3);

  final String apiBaseUrl;
  final String wsUrl;
  final String camerasUrl;
  final String mjpegUrl;

  static String get configSourceUrl => String.fromEnvironment(
        'BACKEND_CONFIG_URL',
        defaultValue: defaultConfigSourceUrl,
      );

  static Future<BackendRuntimeConfig> load() async {
    try {
      final response = await http
          .get(Uri.parse(configSourceUrl))
          .timeout(configFetchTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return fallback();
      }

      final values = <String, String>{};
      _collectStringValues(decoded, values);
      return BackendRuntimeConfig.fromValues(values);
    } catch (_) {
      return fallback();
    }
  }

  factory BackendRuntimeConfig.fromValues(Map<String, String> values) {
    final apiBaseUrl = _normalizeApiBaseUrl(
      _firstNonEmpty(values, const [
            'api_base_url',
            'backend_api_base_url',
            'backend_url',
            'base_url',
          ]) ??
          AppConfig.apiBaseUrl,
    );

    final wsUrl = _firstNonEmpty(values, const [
          'ws_url',
          'websocket_url',
        ]) ??
        _normalizeWsUrl(apiBaseUrl);

    final camerasUrl = _firstNonEmpty(values, const [
          'cameras_url',
        ]) ??
        '$apiBaseUrl/cameras';

    final mjpegUrl = _firstNonEmpty(values, const [
          'mjpeg_url',
          'stream_url',
        ]) ??
        '$apiBaseUrl/stream/mjpeg';

    return BackendRuntimeConfig(
      apiBaseUrl: apiBaseUrl,
      wsUrl: wsUrl,
      camerasUrl: camerasUrl,
      mjpegUrl: mjpegUrl,
    );
  }

  static BackendRuntimeConfig fallback() {
    return BackendRuntimeConfig(
      apiBaseUrl: AppConfig.apiBaseUrl,
      wsUrl: AppConfig.wsUrl,
      camerasUrl: AppConfig.camerasUrl,
      mjpegUrl: AppConfig.mjpegUrl,
    );
  }

  String sourceMjpegUrl(String sourceId) {
    return '$apiBaseUrl/streams/$sourceId/mjpeg';
  }

  static void _collectStringValues(
    dynamic value,
    Map<String, String> output,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        final child = entry.value;
        if (child is String) {
          final trimmed = child.trim();
          if (trimmed.isNotEmpty) {
            output.putIfAbsent(key, () => trimmed);
          }
        } else if (child is num || child is bool) {
          output.putIfAbsent(key, () => child.toString());
        } else {
          _collectStringValues(child, output);
        }
      }
      return;
    }

    if (value is List) {
      for (final item in value) {
        _collectStringValues(item, output);
      }
    }
  }

  static String? _firstNonEmpty(Map<String, String> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key.toLowerCase()];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _normalizeApiBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AppConfig.apiBaseUrl;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final normalized = _trimTrailingSlash(trimmed);
      if (normalized.endsWith('/api/v1')) {
        return normalized;
      }
      return '$normalized/api/v1';
    }

    return 'http://$_trimmedHost(value)/api/v1';
  }

  static String _normalizeWsUrl(String apiBaseUrl) {
    final normalizedApiBaseUrl = _trimTrailingSlash(apiBaseUrl);
    if (normalizedApiBaseUrl.startsWith('https://')) {
      return 'wss://${normalizedApiBaseUrl.substring('https://'.length)}/ws';
    }
    if (normalizedApiBaseUrl.startsWith('http://')) {
      return 'ws://${normalizedApiBaseUrl.substring('http://'.length)}/ws';
    }
    return '$normalizedApiBaseUrl/ws';
  }

  static String _trimTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static String _trimmedHost(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }
}