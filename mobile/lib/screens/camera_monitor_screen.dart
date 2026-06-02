import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:get_it/get_it.dart';

import '../core/backend_runtime_config.dart';
import '../shared_customization/helpers/utilizations/storages.dart';
import '../shared_customization/localization/app_localizations.dart';
import '../state/camera_monitor/camera_monitor_cubit.dart';
import '../state/camera_monitor/camera_monitor_state.dart';
import '../widgets/fall_detection/connection_status.dart';

class CameraMonitorScreen extends StatefulWidget {
  const CameraMonitorScreen({super.key});

  @override
  State<CameraMonitorScreen> createState() => _CameraMonitorScreenState();
}

class _CameraMonitorScreenState extends State<CameraMonitorScreen> {
  final _storage = GetIt.instance<CustomSharedPreferences>();
  final _backendConfig = GetIt.instance<BackendRuntimeConfig>();

  @override
  void initState() {
    super.initState();
    context.read<CameraMonitorCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Realtime Monitor',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          BlocBuilder<CameraMonitorCubit, CameraMonitorState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ConnectionStatus(
                  isConnected: state.isConnected,
                  error: state.error,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<CameraMonitorCubit>().loadSources(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_input_antenna),
            onPressed: () => Navigator.of(context).pushNamed('/sources'),
          ),
        ],
      ),
      body: BlocBuilder<CameraMonitorCubit, CameraMonitorState>(
        builder: (context, state) {
          return Stack(
            children: [
              const _Backdrop(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, state),
                      const SizedBox(height: 16),
                      _buildStreamCard(context, state),
                      const SizedBox(height: 16),
                      _buildSourceSelector(context, state),
                      const SizedBox(height: 16),
                      _buildActionFrame(context, state),
                      const SizedBox(height: 16),
                      _buildLogPanel(context, state),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CameraMonitorState state) {
    final loc = AppLocalizations.of(context);
    final chipColor = state.isConnected ? const Color(0xFF1FBF9B) : const Color(0xFFF1A53A);
    final chipText = state.isConnected ? loc.translate('connected') : loc.translate('reconnecting');

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B2E4C),
              Color(0xFF124B6C),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.videocam, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.translate('live'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.translate('status'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeaderChip(label: chipText, color: chipColor),
                      _HeaderChip(label: loc.translate('live'), color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamCard(BuildContext context, CameraMonitorState state) {
    final source = state.selectedSource;
    final streamUrl = source == null ? '' : _backendConfig.sourceMjpegUrl(source.id);
    final headers = _storage.authorizationHeaders;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.24),
            child: Row(
              children: [
                const Icon(Icons.live_tv, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    source == null ? 'Camera feed' : source.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  state.isConnected ? 'Connected' : 'Waiting',
                  style: TextStyle(
                    color: state.isConnected ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF101418)),
                Mjpeg(
                  isLive: true,
                  stream: streamUrl,
                  headers: headers,
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _StreamBadge(
                    label: source == null ? 'Select a source' : source.name,
                    icon: Icons.stream,
                  ),
                ),
                if (!state.isConnected)
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off, color: Colors.white, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'Disconnected from backend',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector(BuildContext context, CameraMonitorState state) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.source_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your source',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (state.isLoadingSources)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.sources.isEmpty)
              Text(
                'No source configured for this account.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(state.sources.length, (index) {
                  final source = state.sources[index];
                  final selected = index == state.selectedIndex;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(source.name.isEmpty ? 'Source ${index + 1}' : source.name),
                    onSelected: (_) => context.read<CameraMonitorCubit>().selectSource(index),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionFrame(BuildContext context, CameraMonitorState state) {
    final loc = AppLocalizations.of(context);
    final status = state.status;
    final actionColor = _actionColor(status.action);
    final timestamp = status.timestampMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(status.timestampMs)
        : DateTime.now();

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              actionColor.withOpacity(0.92),
              actionColor.withOpacity(0.52),
            ],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_actionIcon(status.action),
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('action'),
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        loc.actionLabelUpper(status.action),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status.fall)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.9)),
                    ),
                    child: Text(
                      loc.translate('fall_detected').toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 120,
                  child: Text(
                    'Confidence',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: status.confidence.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.16),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(status.confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: loc.translate('confidence'),
              value: '${(status.fallConfidence * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Track ID',
              value: status.trackId,
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: loc.translate('status'),
              value: _formatTimestamp(timestamp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogPanel(BuildContext context, CameraMonitorState state) {
    final loc = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${loc.translate('status')} Logs',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  '${state.logs.length} entries',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: state.logs.isEmpty
                  ? Center(
                      child: Text(
                        loc.translate('waiting'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final line = state.logs[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Text(
                            line,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                    ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action.toLowerCase()) {
      case 'standing':
        return const Color(0xFF1C7ED6);
      case 'walking':
        return const Color(0xFF3BC9DB);
      case 'running':
        return const Color(0xFFFF6B6B);
      case 'sitting':
        return const Color(0xFFF59F00);
      case 'lying':
        return const Color(0xFF2F9E44);
      case 'crouching':
        return const Color(0xFF12B886);
      default:
        return const Color(0xFF8391A1);
    }
  }

  IconData _actionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'standing':
        return Icons.person;
      case 'walking':
        return Icons.directions_walk;
      case 'running':
        return Icons.directions_run;
      case 'sitting':
        return Icons.chair;
      case 'lying':
        return Icons.hotel;
      case 'crouching':
        return Icons.accessibility_new;
      default:
        return Icons.help_outline;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white.withOpacity(0.2) : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
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
            top: -80,
            right: -40,
            child: _GlowBlob(
              color: const Color(0xFFF36B4E).withOpacity(0.15),
              size: 200,
            ),
          ),
          Positioned(
            bottom: -70,
            left: -30,
            child: _GlowBlob(
              color: const Color(0xFF1FBF9B).withOpacity(0.12),
              size: 180,
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
            blurRadius: 80,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _StreamBadge extends StatelessWidget {
  const _StreamBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
