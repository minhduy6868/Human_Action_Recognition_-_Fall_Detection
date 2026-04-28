import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/realtime_cubit.dart';
import 'cubit/realtime_state.dart';

class FallDetectionScreen extends StatefulWidget {
  const FallDetectionScreen({super.key});

  @override
  State<FallDetectionScreen> createState() => _FallDetectionScreenState();
}

class _FallDetectionScreenState extends State<FallDetectionScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RealtimeCubit>().connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fall Detection')),
      body: BlocBuilder<RealtimeCubit, RealtimeState>(
        builder: (context, state) {
          if (!state.isConnected) {
            return const Center(child: Text('Waiting for stream...'));
          }

          final status = state.status;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Action: ${status.action}'),
                Text('Fall: ${status.fall}'),
                Text('Confidence: ${status.confidence.toStringAsFixed(2)}'),
              ],
            ),
          );
        },
      ),
    );
  }
}
