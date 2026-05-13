import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'get_it_dependencies.dart';
import 'features/camera_monitor/cubit/camera_monitor_cubit.dart';
import 'features/camera_monitor/camera_monitor_screen.dart';
import 'shared_customization/localization/app_localizations.dart';
import 'shared_customization/theme/app_theme.dart';
import 'state/app_settings_cubit.dart';
import 'state/app_settings_state.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppSettingsCubit>(
      create: (_) => getIt<AppSettingsCubit>(),
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, settingsState) {
          return MaterialApp(
            title: 'Video AI Detect',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settingsState.themeMode,
            locale: settingsState.locale,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('vi'),
            ],
            home: BlocProvider(
              create: (_) => getIt<CameraMonitorCubit>(),
              child: const CameraMonitorScreen(),
            ),
          );
        },
      ),
    );
  }
}

