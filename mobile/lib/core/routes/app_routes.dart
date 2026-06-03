import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/injection.dart';
import '../../screens/ai_chat_screen.dart';
import '../../screens/analytics_screen.dart';
import '../../screens/camera_monitor_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/fall_detection_screen.dart';
import '../../screens/forgot_password_screen.dart';
import '../../screens/history_screen.dart';
import '../../screens/logs_screen.dart';
import '../../screens/register_screen.dart';
import '../../screens/reports_screen.dart';
import '../../screens/sources_screen.dart';
import '../../state/camera_monitor/camera_monitor_cubit.dart';
import '../../state/fall_detection/realtime_cubit.dart';

/// Central route names and builders for [MaterialApp.routes].
class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String analytics = '/analytics';
  static const String aiChat = '/ai-chat';
  static const String sources = '/sources';
  static const String history = '/history';
  static const String logs = '/logs';
  static const String reports = '/reports';
  static const String register = '/register';
  static const String forgot = '/forgot';
  static const String fallDetection = '/fall-detection';
  static const String cameraMonitor = '/camera-monitor';

  static Map<String, WidgetBuilder> get routes => {
        dashboard: (_) => const DashboardScreen(),
        analytics: (_) => const AnalyticsScreen(),
        aiChat: (_) => const AiChatScreen(),
        sources: (_) => const SourcesScreen(),
        history: (_) => const HistoryScreen(),
        logs: (_) => const LogsScreen(),
        reports: (_) => const ReportsScreen(),
        register: (_) => const RegisterScreen(),
        forgot: (_) => const ForgotPasswordScreen(),
        fallDetection: (_) => BlocProvider(
              create: (_) => getIt<RealtimeCubit>(),
              child: const FallDetectionScreen(),
            ),
        cameraMonitor: (_) => BlocProvider(
              create: (_) => getIt<CameraMonitorCubit>()..initialize(),
              child: const CameraMonitorScreen(),
            ),
      };
}
