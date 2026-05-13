import 'package:get_it/get_it.dart';

import 'core/app_config.dart';
import 'features/camera_monitor/cubit/camera_monitor_cubit.dart';
import 'features/fall_detection/cubit/realtime_cubit.dart';
import 'services/camera_api.dart';
import 'services/realtime_stream.dart';
import 'shared_customization/helpers/utilizations/storages.dart';
import 'state/app_settings_cubit.dart';

final getIt = GetIt.instance;

Future<void> initGetItDependencies() async {
  // Initialize shared preferences storage
  final storage = CustomSharedPreferences();
  await storage.init();
  getIt.registerSingleton<CustomSharedPreferences>(storage);

  // Register singletons / factories used across the app
  getIt.registerSingleton<RealtimeStream>(RealtimeStream(AppConfig.wsUrl));
  getIt.registerSingleton<CameraApi>(CameraApi());

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
