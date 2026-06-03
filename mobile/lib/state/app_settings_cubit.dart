import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/storage/app_storage.dart';
import 'app_settings_state.dart';

class AppSettingsCubit extends Cubit<AppSettingsState> {
  final CustomSharedPreferences storage;

  AppSettingsCubit(this.storage)
      : super(const AppSettingsState());

  Future<void> initialize() async {
    final theme = await storage.getThemeMode();
    final langCode = await storage.getLanguageCode();
    
    emit(
      state.copyWith(
        themeMode: theme,
        locale: Locale(langCode),
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await storage.setThemeMode(mode);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setLanguage(String languageCode) async {
    await storage.setLanguageCode(languageCode);
    emit(state.copyWith(locale: Locale(languageCode)));
  }

  Future<void> toggleDarkMode() async {
    final newMode = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}
