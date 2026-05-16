import 'package:get_it/get_it.dart';

import 'core/app_config.dart';
import 'state/camera_monitor/camera_monitor_cubit.dart';
import 'state/fall_detection/realtime_cubit.dart';
import 'services/api_client.dart';
import 'services/auth_api.dart';
import 'services/camera_api.dart';
import 'services/sources_api.dart';
import 'services/realtime_stream.dart';
import 'services/monitoring_api.dart';
import 'shared_customization/helpers/utilizations/storages.dart';
import 'state/app_settings_cubit.dart';

final getIt = GetIt.instance;

Future<void> initGetItDependencies() async {
  // Initialize shared preferences storage
  final storage = CustomSharedPreferences();
  await storage.init();
  getIt.registerSingleton<CustomSharedPreferences>(storage);

  // Register singletons / factories used across the app
  getIt.registerSingleton<ApiClient>(ApiClient(AppConfig.apiBaseUrl, storage));
  getIt.registerSingleton<AuthApi>(AuthApi(getIt<ApiClient>(), storage));
  getIt.registerFactory<RealtimeStream>(() {
    final token = getIt<CustomSharedPreferences>().accessToken;
    final url = token != null && token.isNotEmpty ? '${AppConfig.wsUrl}?token=$token' : AppConfig.wsUrl;
    return RealtimeStream(url);
  });
  getIt.registerSingleton<CameraApi>(CameraApi(getIt<ApiClient>()));
  getIt.registerSingleton<SourcesApi>(SourcesApi(getIt<ApiClient>()));
  getIt.registerSingleton<MonitoringApi>(MonitoringApi(getIt<ApiClient>()));

  // App Settings Cubit for theme and language
  final settingsCubit = AppSettingsCubit(storage);
  await settingsCubit.initialize();
  getIt.registerSingleton<AppSettingsCubit>(settingsCubit);

  // Cubits / Blocs as factories so each consumer gets a fresh instance
  getIt.registerFactory<RealtimeCubit>(() => RealtimeCubit(getIt<RealtimeStream>()));
  getIt.registerFactory<CameraMonitorCubit>(
    () => CameraMonitorCubit(
      getIt<RealtimeStream>(),
      getIt<CameraApi>(),
    ),
  );
}
