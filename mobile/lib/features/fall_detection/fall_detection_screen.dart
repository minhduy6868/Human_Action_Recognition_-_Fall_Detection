import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/realtime_cubit.dart';
import 'cubit/realtime_state.dart';
import 'widgets/index.dart';

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
      appBar: _buildAppBar(),
      body: BlocBuilder<RealtimeCubit, RealtimeState>(
        builder: (context, state) {
          if (!state.isConnected) {
            return _buildLoadingState();
          }

          final status = state.status;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                spacing: 16,
                children: [
                  // Main Status Card
                  StatusCard(
                    action: status.action,
                    confidence: status.confidence,
                    isFalling: status.fall,
                    fallConfidence: status.fallConfidence,
                  ),

                  // Statistics Panel
                  StatsPanel(
                    action: status.action,
                    confidence: status.confidence,
                    isFalling: status.fall,
                    timestamp: DateTime.fromMillisecondsSinceEpoch(status.timestampMs),
                  ),

                  // People List (NEW)
                  PeopleListWidget(people: status.people),

                  // Objects List (NEW)
                  ObjectsListWidget(objects: status.objects),

                  // Alert Section (if falling)
                  if (status.fall) _buildFallAlert(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Fall Detection System',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      elevation: 0,
      actions: [
        BlocBuilder<RealtimeCubit, RealtimeState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ConnectionStatus(
                isConnected: state.isConnected,
                error: state.error,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting to Backend',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Initializing video stream...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallAlert() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade600,
              Colors.red.shade800,
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'FALL ALERT',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Immediate assistance recommended',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

