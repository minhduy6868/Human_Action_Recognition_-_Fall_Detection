import 'dart:convert';

import 'package:http/http.dart' as http;

import '../shared_customization/helpers/utilizations/storages.dart';

class ApiClient {
  ApiClient(this.baseUrl, this.storage);

  final String baseUrl;
  final CustomSharedPreferences storage;

  Future<Map<String, dynamic>> getJson(
    String path, {
    bool auth = false,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    bool auth = false,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
    );
    return _decode(response);
  }

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth && storage.accessToken != null) {
      headers['Authorization'] = 'Bearer ${storage.accessToken}';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final error = payload['error'] as Map<String, dynamic>?;
      final message = error?['message']?.toString() ?? 'Request failed';
      throw Exception(message);
    }
    return payload;
  }
}
