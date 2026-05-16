import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'get_it_dependencies.dart';
import 'state/auth/auth_cubit.dart';
import 'state/auth/auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_shell.dart';
import 'screens/sources_screen.dart';
import 'screens/history_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/reports_screen.dart';
import 'state/camera_monitor/camera_monitor_cubit.dart';
import 'state/fall_detection/realtime_cubit.dart';
import 'shared_customization/localization/app_localizations.dart';
import 'shared_customization/theme/app_theme.dart';
import 'state/app_settings_cubit.dart';
import 'state/app_settings_state.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppSettingsCubit>(
          create: (_) => getIt<AppSettingsCubit>(),
        ),
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(getIt(), getIt())..bootstrap(),
        ),
      ],
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
            routes: {
              '/register': (_) => const RegisterScreen(),
              '/forgot': (_) => const ForgotPasswordScreen(),
              '/sources': (_) => const SourcesScreen(),
              '/history': (_) => const HistoryScreen(),
              '/logs': (_) => const LogsScreen(),
              '/reports': (_) => const ReportsScreen(),
            },
            home: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, authState) {
                if (authState.status == AuthStatus.loading) {
                  return const _SplashScreen();
                }
                if (authState.status == AuthStatus.authenticated) {
                  return MultiBlocProvider(
                    providers: [
                      BlocProvider(create: (_) => getIt<CameraMonitorCubit>()),
                      BlocProvider(create: (_) => getIt<RealtimeCubit>()),
                    ],
                    child: const HomeShell(),
                  );
                }
                return const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Preparing workspace...',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

