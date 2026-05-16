import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/camera_monitor/camera_monitor_cubit.dart';
import '../screens/camera_monitor_screen.dart';
import '../state/fall_detection/realtime_cubit.dart';
import '../screens/fall_detection_screen.dart';
import '../get_it_dependencies.dart';
import '../services/camera_api.dart';
import '../services/realtime_stream.dart';
import '../services/sources_api.dart';
import '../screens/sources_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/history_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/analytics_screen.dart';

class AppRouter {
  static const String fallDetection = '/fall-detection';
  static const String cameraMonitor = '/camera-monitor';

  static Map<String, WidgetBuilder> routes = {
    '/': (_) => const DashboardScreen(),
    '/dashboard': (_) => const DashboardScreen(),
    '/sources': (_) => const SourcesScreen(),
    '/reports': (_) => const ReportsScreen(),
    '/history': (_) => const HistoryScreen(),
    '/logs': (_) => const LogsScreen(),
    '/ai-chat': (_) => const AiChatScreen(),
    '/analytics': (_) => const AnalyticsScreen(),
    fallDetection: (_) => BlocProvider(
          create: (_) => RealtimeCubit(getIt<RealtimeStream>()),
          child: const FallDetectionScreen(),
        ),
    cameraMonitor: (_) => BlocProvider(
          create: (_) => CameraMonitorCubit(
            getIt<RealtimeStream>(),
            getIt<CameraApi>(),
          ),
          child: const CameraMonitorScreen(),
        ),
  };
}
