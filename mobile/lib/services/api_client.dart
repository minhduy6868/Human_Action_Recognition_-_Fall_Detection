import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl;

  Future<Map<String, dynamic>> health() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
