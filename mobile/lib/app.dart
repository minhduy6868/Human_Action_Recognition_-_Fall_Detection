import 'package:flutter/material.dart';

import 'features/fall_detection/fall_detection_screen.dart';
import 'routes/app_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video AI Detect',
      routes: AppRouter.routes,
      initialRoute: AppRouter.fallDetection,
      theme: ThemeData(useMaterial3: true),
      home: const FallDetectionScreen(),
    );
  }
}
