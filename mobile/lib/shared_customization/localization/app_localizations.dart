import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const Map<String, Map<String, String>> _localizedStrings = {
    'en': {
      'title': 'Video AI Detect',
      'status': 'Status',
      'history': 'History',
      'summary': 'Summary',
      'chat': 'Chat',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'darkMode': 'Dark Mode',
      'action': 'Action',
      'confidence': 'Confidence',
      'fall_detected': 'Fall Detected',
      'no_data': 'No data available',
    },
    'vi': {
      'title': 'Phát hiện hành động AI',
      'status': 'Trạng thái',
      'history': 'Lịch sử',
      'summary': 'Tóm tắt',
      'chat': 'Trò chuyện',
      'settings': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'theme': 'Giao diện',
      'darkMode': 'Chế độ tối',
      'action': 'Hành động',
      'confidence': 'Độ tin cậy',
      'fall_detected': 'Phát hiện té ngã',
      'no_data': 'Không có dữ liệu',
    },
  };

  String translate(String key) {
    final langCode = locale.languageCode;
    return _localizedStrings[langCode]?[key] ?? _localizedStrings['en']?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => 
      Future.value(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
