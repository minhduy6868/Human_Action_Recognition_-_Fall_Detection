import 'package:flutter/material.dart';

import '../features/fall_detection/fall_detection_screen.dart';

class AppRouter {
  static const String fallDetection = '/fall-detection';

  static Map<String, WidgetBuilder> routes = {
    fallDetection: (_) => const FallDetectionScreen(),
  };
}
