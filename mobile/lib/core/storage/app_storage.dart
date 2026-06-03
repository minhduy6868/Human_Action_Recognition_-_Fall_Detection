import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension StringExtensions on String? {
  bool get isEmptyOrNull => this == null || this!.isEmpty;
}

class CustomSharedPreferences {
  late final SharedPreferences prefs;

  String? get accessToken => prefs.getString('access_token');
  String? get refreshToken => prefs.getString('refresh_token');

  Map<String, String> get authorizationHeaders {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      return const {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  bool get loggedBefore => prefs.getBool('logged_before') ?? false;
  set loggedBefore(bool value) => prefs.setBool('logged_before', value);

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  Future<void> setToken(String access, String refresh) async {
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> clear() async {
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await prefs.setString('theme_mode', mode.toString());
  }

  Future<ThemeMode> getThemeMode() async {
    final mode = prefs.getString('theme_mode');
    return mode == null
        ? ThemeMode.system
        : ThemeMode.values
            .firstWhere((e) => e.toString() == mode, orElse: () => ThemeMode.system);
  }

  Future<void> setLanguageCode(String code) async {
    await prefs.setString('language_code', code);
  }

  Future<String> getLanguageCode() async {
    return prefs.getString('language_code') ?? 'en';
  }
}
