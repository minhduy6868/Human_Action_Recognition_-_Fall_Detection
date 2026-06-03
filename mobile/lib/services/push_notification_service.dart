import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/storage/app_storage.dart';
import 'auth_api.dart';

class PushNotificationService {
  PushNotificationService(this._authApi, this._storage);

  final AuthApi _authApi;
  final CustomSharedPreferences _storage;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> initialize() async {
    if (kIsWeb) return;

    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.android &&
        platform != TargetPlatform.iOS &&
        platform != TargetPlatform.macOS) {
      return;
    }

    try {
      if (!_initialized) {
        await Firebase.initializeApp();
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _syncToken(await messaging.getToken());

      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((token) {
        unawaited(_syncToken(token));
      });

      if (!_initialized) {
        FirebaseMessaging.onMessage.listen((message) {
          debugPrint('FCM foreground message: ${message.notification?.title ?? ''}');
        });
      }

      _initialized = true;
    } catch (error) {
      debugPrint('Push notification init failed: $error');
    }
  }

  Future<void> refreshNow() async {
    if (!_initialized) return;
    await _syncToken(await FirebaseMessaging.instance.getToken());
  }

  Future<void> unregister() async {
    if (!_initialized) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await _authApi.removeDeviceToken(token);
    } catch (_) {}
  }

  Future<void> _syncToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _authApi.registerDeviceToken(token, platform: _platformName());
      await _storage.prefs.setString('fcm_token', token);
    } catch (error) {
      debugPrint('Failed to register FCM token: $error');
    }
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}