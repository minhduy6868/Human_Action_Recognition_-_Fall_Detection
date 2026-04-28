import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension StringExtensions on String? {
  bool get isEmptyOrNull => this == null || this!.isEmpty;
}

class CustomSharedPreferences {
  late final SharedPreferences prefs;

  String? get accessToken => prefs.getString('access_token');
  String? get refreshToken => prefs.getString('refresh_token');

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
}
