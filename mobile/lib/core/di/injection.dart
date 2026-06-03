import 'package:get_it/get_it.dart';

import '../backend_runtime_config.dart';
import '../storage/app_storage.dart';
import '../../services/admin_api.dart';
import '../../services/api_client.dart';
import '../../services/auth_api.dart';
import '../../services/camera_api.dart';
import '../../services/monitoring_api.dart';
import '../../services/push_notification_service.dart';
import '../../services/realtime_stream.dart';
import '../../services/sources_api.dart';
import '../../state/app_settings_cubit.dart';
import '../../state/camera_monitor/camera_monitor_cubit.dart';
import '../../state/fall_detection/realtime_cubit.dart';

final getIt = GetIt.instance;

Future<void> initDependencies() async {
  final storage = CustomSharedPreferences();
  await storage.init();
  getIt.registerSingleton<CustomSharedPreferences>(storage);

  final backendConfig = await BackendRuntimeConfig.load();
  getIt.registerSingleton<BackendRuntimeConfig>(backendConfig);

  getIt.registerSingleton<ApiClient>(ApiClient(backendConfig.apiBaseUrl, storage));
  getIt.registerSingleton<AuthApi>(AuthApi(getIt<ApiClient>(), storage));
  getIt.registerSingleton<PushNotificationService>(
    PushNotificationService(getIt<AuthApi>(), storage),
  );
  getIt.registerFactory<RealtimeStream>(() {
    final token = getIt<CustomSharedPreferences>().accessToken;
    final url = token != null && token.isNotEmpty
        ? '${backendConfig.wsUrl}?token=$token'
        : backendConfig.wsUrl;
    return RealtimeStream(url);
  });
  getIt.registerSingleton<CameraApi>(CameraApi(getIt<ApiClient>()));
  getIt.registerSingleton<SourcesApi>(SourcesApi(getIt<ApiClient>()));
  getIt.registerSingleton<MonitoringApi>(MonitoringApi(getIt<ApiClient>()));
  getIt.registerSingleton<AdminApi>(AdminApi(getIt<ApiClient>()));

  final settingsCubit = AppSettingsCubit(storage);
  await settingsCubit.initialize();
  getIt.registerSingleton<AppSettingsCubit>(settingsCubit);

  getIt.registerFactory<RealtimeCubit>(() => RealtimeCubit(getIt<RealtimeStream>()));
  getIt.registerFactory<CameraMonitorCubit>(
    () => CameraMonitorCubit(
      getIt<RealtimeStream>(),
      getIt<SourcesApi>(),
    ),
  );
}
