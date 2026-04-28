import 'package:get_it/get_it.dart';

import 'core/app_config.dart';
import 'features/fall_detection/cubit/realtime_cubit.dart';
import 'services/realtime_stream.dart';
import 'shared_customization/helpers/utilizations/storages.dart';

final getIt = GetIt.instance;

Future<void> initGetItDependencies() async {
  // Initialize shared preferences storage
  final storage = CustomSharedPreferences();
  await storage.init();
  getIt.registerSingleton<CustomSharedPreferences>(storage);

  // Register singletons / factories used across the app
  getIt.registerSingleton<RealtimeStream>(RealtimeStream(AppConfig.wsUrl));

  // Cubits / Blocs as factories so each consumer gets a fresh instance
  getIt.registerFactory<RealtimeCubit>(() => RealtimeCubit(getIt<RealtimeStream>()));
}
