import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/app_config.dart';
import '../features/camera_monitor/cubit/camera_monitor_cubit.dart';
import '../features/camera_monitor/camera_monitor_screen.dart';
import '../features/fall_detection/cubit/realtime_cubit.dart';
import '../features/fall_detection/fall_detection_screen.dart';
import '../services/camera_api.dart';
import '../services/realtime_stream.dart';

class AppRouter {
  static const String fallDetection = '/fall-detection';
  static const String cameraMonitor = '/camera-monitor';

  static Map<String, WidgetBuilder> routes = {
    fallDetection: (_) => BlocProvider(
          create: (_) => RealtimeCubit(RealtimeStream(AppConfig.wsUrl)),
          child: const FallDetectionScreen(),
        ),
    cameraMonitor: (_) => BlocProvider(
          create: (_) => CameraMonitorCubit(
            RealtimeStream(AppConfig.wsUrl),
            CameraApi(),
          ),
          child: const CameraMonitorScreen(),
        ),
  };
}
