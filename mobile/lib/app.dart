import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'get_it_dependencies.dart';
import 'features/fall_detection/cubit/realtime_cubit.dart';
import 'features/fall_detection/fall_detection_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video AI Detect',
      theme: ThemeData(useMaterial3: true),
      home: BlocProvider(
        create: (_) => getIt<RealtimeCubit>(),
        child: const FallDetectionScreen(),
      ),
    );
  }
}
