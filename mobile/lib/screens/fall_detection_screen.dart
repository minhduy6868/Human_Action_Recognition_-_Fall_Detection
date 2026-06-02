import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/fall_detection/realtime_cubit.dart';
import '../state/fall_detection/realtime_state.dart';
import '../shared_customization/localization/app_localizations.dart';
import '../widgets/fall_detection/index.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: _buildAppBar(),
      body: BlocBuilder<RealtimeCubit, RealtimeState>(
        builder: (context, state) {
          return Stack(
            children: [
              const _Backdrop(),
              if (!state.isConnected)
                _buildLoadingState(theme)
              else
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatusCard(
                        action: state.status.action,
                        confidence: state.status.confidence,
                        isFalling: state.status.fall,
                        fallConfidence: state.status.fallConfidence,
                      ),
                      const SizedBox(height: 16),
                      StatsPanel(
                        action: state.status.action,
                        confidence: state.status.confidence,
                        isFalling: state.status.fall,
                        timestamp: DateTime.fromMillisecondsSinceEpoch(
                          state.status.timestampMs,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PeopleListWidget(people: state.status.people),
                      const SizedBox(height: 16),
                      ObjectsListWidget(objects: state.status.objects),
                      if (state.status.fall) ...[
                        const SizedBox(height: 16),
                        _buildFallAlert(theme),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(AppLocalizations.of(context).translate('fall_detection_title')),
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

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 18),
          Text(
            AppLocalizations.of(context).translate('connecting_to_backend'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('waiting_for_realtime_stream'),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildFallAlert(ThemeData theme) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB91C1C),
              Color(0xFFEF4444),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.emergency, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).translate('fall_alert'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('immediate_assistance_recommended'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0B1218), const Color(0xFF111E2A)]
              : [const Color(0xFFF2F6FB), const Color(0xFFF8FBFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -30,
            child: _GlowBlob(
              color: const Color(0xFFF36B4E).withOpacity(0.12),
              size: 180,
            ),
          ),
          Positioned(
            bottom: -80,
            left: -30,
            child: _GlowBlob(
              color: const Color(0xFF1FBF9B).withOpacity(0.14),
              size: 200,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 90,
            spreadRadius: 12,
          ),
        ],
      ),
    );
  }
}
