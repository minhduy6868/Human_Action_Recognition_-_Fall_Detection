import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../core/backend_runtime_config.dart';
import '../models/realtime_status.dart';
import '../models/source.dart';
import '../services/monitoring_api.dart';
import '../core/l10n/app_localizations.dart';
import '../core/storage/app_storage.dart';
import '../state/selected_source/selected_source_cubit.dart';
import '../state/selected_source/selected_source_state.dart';
import '../widgets/safe_mjpeg_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.isActive = true,
    this.onOpenAnalytics,
  });

  final bool isActive;
  final VoidCallback? onOpenAnalytics;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _monitoringApi = GetIt.instance<MonitoringApi>();
  final _storage = GetIt.instance<CustomSharedPreferences>();
  final _backendConfig = GetIt.instance<BackendRuntimeConfig>();

  List<dynamic> _events = [];
  List<dynamic> _reports = [];
  String? _error;
  bool _loadingMetrics = false;
  RealtimeStatus _streamStatus = RealtimeStatus.initial();
  Timer? _statusTimer;

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        AppLocalizations.of(context)
                            .translate('camera_sources'),
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                            AppLocalizations.of(context).translate('close'))),
                  ],
                ),
                const SizedBox(height: 8),
                if (context.read<SelectedSourceCubit>().state.sources.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(AppLocalizations.of(context)
                        .translate('no_camera_sources_yet')),
                  )
                else
                  ...context.read<SelectedSourceCubit>().state.sources.map((s) {
                    final idx = context
                        .read<SelectedSourceCubit>()
                        .state
                        .sources
                        .indexOf(s);
                    return ListTile(
                      title: Text(s.name.isEmpty
                          ? '${AppLocalizations.of(context).translate('camera')} ${idx + 1}'
                          : s.name),
                      subtitle: Text(s.sourceUrl),
                      trailing: s.isActive
                          ? Icon(Icons.circle, size: 10, color: Colors.green.shade600)
                          : null,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _selectSourceById(s.id);
                      },
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadData());
      _restartStatusPoll();
    });
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _restartStatusPoll();
    } else {
      _statusTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _restartStatusPoll() {
    _statusTimer?.cancel();
    if (!widget.isActive) return;
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollStreamStatus());
    });
    unawaited(_pollStreamStatus());
  }

  Future<void> _pollStreamStatus() async {
    final selected = context.read<SelectedSourceCubit>().state.selectedSource;
    if (selected == null || !selected.isActive) {
      if (!mounted) return;
      setState(() => _streamStatus = RealtimeStatus.initial());
      return;
    }
    try {
      final map = await _monitoringApi.getStreamStatus(selected.id);
      if (!mounted) return;
      setState(() => _streamStatus = RealtimeStatus.fromMap(map));
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _error = null;
        _loadingMetrics = true;
      });
    }
    try {
      await context.read<SelectedSourceCubit>().refreshSources();
      final sourceId = context.read<SelectedSourceCubit>().state.selectedSourceId;
      final results = await Future.wait([
        _monitoringApi.getHistory(limit: 60, sourceId: sourceId),
        _monitoringApi.getReports(limit: 20, sourceId: sourceId),
      ]);
      if (!mounted) return;
      setState(() {
        _events = results[0];
        _reports = results[1];
      });
      unawaited(_pollStreamStatus());
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMetrics = false);
      }
    }
  }

  Future<void> _selectSourceById(String sourceId) async {
    HapticFeedback.selectionClick();
    await context.read<SelectedSourceCubit>().selectSource(sourceId);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<SelectedSourceCubit, SelectedSourceState>(
      listenWhen: (prev, next) => prev.selectedSourceId != next.selectedSourceId,
      listener: (_, __) => unawaited(_loadData()),
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context).translate('control_center'),
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).translate('refresh'),
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).translate('monitor'),
            onPressed: () => Navigator.of(context).pushNamed('/camera-monitor'),
            icon: const Icon(Icons.videocam_rounded),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).translate('camera_sources'),
            onPressed: _showSourcePicker,
            icon: const Icon(Icons.filter_list_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          const _DashboardBackdrop(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildLiveFeedCard(theme),
                  const SizedBox(height: 16),
                  _buildSourceSelector(theme),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    _buildErrorBanner(theme),
                    const SizedBox(height: 16),
                  ],
                  _buildRealtimeSnapshot(theme),
                  const SizedBox(height: 16),
                  _buildShortcuts(theme),
                  const SizedBox(height: 16),
                  _buildTimelineSection(theme),
                  const SizedBox(height: 16),
                  _buildSystemSnapshot(theme),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildErrorBanner(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.error.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error ??
                    AppLocalizations.of(context)
                        .translate('unable_to_load_data'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
            TextButton(
                onPressed: _loadData,
                child: Text(AppLocalizations.of(context).translate('retry'))),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveFeedCard(ThemeData theme) {
    final loc = AppLocalizations.of(context);
    final source = context.watch<SelectedSourceCubit>().state.selectedSource;
    final name = source?.name.isNotEmpty == true
        ? source!.name
        : loc.translate('no_active_source_selected');
    final streamUrl = source != null && source.isActive
        ? _backendConfig.sourceMjpegUrl(source.id)
        : '';
    final headers = _storage.authorizationHeaders;
    final placeholderMessage = source == null
        ? loc.translate('no_active_source_selected')
        : (source.isActive
            ? loc.translate('stream_unavailable')
            : loc.translate('source_not_running'));

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openFullScreenCamera(name, streamUrl),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2E4C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.live_tv_rounded,
                        color: Color(0xFF0B2E4C)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            AppLocalizations.of(context)
                                .translate('live_camera_feed'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(name, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  _StreamStatusBadge(
                      label: loc.translate('live').toUpperCase(),
                      color: const Color(0xFF1FBF9B)),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: streamUrl.isEmpty
                  ? _buildStreamPlaceholder(theme, placeholderMessage)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.18),
                          child: SafeMjpegView(
                            enabled: widget.isActive,
                            streamUrl: streamUrl,
                            headers: headers,
                            placeholder: _buildStreamPlaceholder(
                              theme,
                              loc.translate('stream_unavailable'),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _StreamStatusBadge(
                                label: source!.isActive
                                    ? loc.translate('connected').toUpperCase()
                                    : loc.translate('connecting').toUpperCase(),
                                color: source.isActive
                                    ? const Color(0xFF1FBF9B)
                                    : const Color(0xFFF1A53A),
                              ),
                              _StreamStatusBadge(
                                label: loc.actionLabelUpper(_streamStatus.action),
                                color: const Color(0xFF0B2E4C),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: _StreamStatusBadge(
                            label:
                                '${(_streamStatus.confidence * 100).toStringAsFixed(1)}%',
                            color: const Color(0xFF0B2E4C),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenCamera(String name, String streamUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenCameraView(name: name, streamUrl: streamUrl),
      ),
    );
  }

  Widget _buildStreamPlaceholder(ThemeData theme, String message) {
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.18),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded,
              color: theme.colorScheme.outline, size: 44),
          const SizedBox(height: 12),
          Text(message, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Check camera source or backend stream endpoint.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeSnapshot(ThemeData theme) {
    final loc = AppLocalizations.of(context);
    final selected = context.watch<SelectedSourceCubit>().state.selectedSource;
    final status = _streamStatus;
    final timestamp = status.timestampMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(status.timestampMs)
        : null;

    return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Color(0xFF0B2E4C)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          AppLocalizations.of(context)
                              .translate('realtime_snapshot'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    if (selected != null)
                      Text(
                        loc.translate('viewing_source', {
                          'name': selected.name.isNotEmpty
                              ? selected.name
                              : selected.id,
                        }),
                        style: theme.textTheme.bodySmall,
                      ),
                    ConnectionPill(
                      isConnected: selected?.isActive == true &&
                          status.timestampMs > 0,
                      error: selected?.isActive == true ? null : loc.translate('source_not_running'),
                    ),
                  ],
                ),
                if (_loadingMetrics)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 16),
                _InfoRow(
                    label: loc.translate('action'),
                    value: loc.actionLabelUpper(status.action)),
                const SizedBox(height: 10),
                _ProgressRow(
                    label:
                        '${loc.translate('action')} ${loc.translate('confidence').toLowerCase()}',
                    value: status.confidence,
                    color: const Color(0xFF1FBF9B)),
                const SizedBox(height: 10),
                _ProgressRow(
                    label:
                        '${loc.translate('fall_detected')} ${loc.translate('confidence').toLowerCase()}',
                    value: status.fallConfidence,
                    color: const Color(0xFFF36B4E)),
                const SizedBox(height: 10),
                _InfoRow(
                    label: AppLocalizations.of(context).translate('track'),
                    value: status.trackId),
                const SizedBox(height: 10),
                _InfoRow(
                  label: AppLocalizations.of(context).translate('updated'),
                  value: timestamp == null
                      ? loc.translate('waiting')
                      : DateFormat('dd/MM HH:mm:ss').format(timestamp),
                ),
                if (status.fall) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF36B4E).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: const Color(0xFFF36B4E).withOpacity(0.24)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFF36B4E)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.translate('fall_detected'),
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
  }

  Widget _buildSourceSelector(ThemeData theme) {
    final loc = AppLocalizations.of(context);
    final sourceState = context.watch<SelectedSourceCubit>().state;
    final sources = sourceState.sources;
    final selected = sourceState.selectedSource;
    final activeLabel = selected == null
        ? loc.translate('no_active_source_selected')
        : (selected.name.isNotEmpty ? selected.name : selected.sourceUrl);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.video_library_rounded,
                    color: Color(0xFF0B2E4C)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.translate('quick_source'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(activeLabel, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/sources'),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(loc.translate('manage')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sources.isEmpty)
              Text(loc.translate('no_camera_sources_yet'),
                  style: theme.textTheme.bodyMedium)
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(sources.length, (index) {
                    final source = sources[index];
                    final label = source.name.isEmpty
                        ? '${loc.translate('camera')} ${index + 1}'
                        : source.name;
                    final isSelected = source.id == sourceState.selectedSourceId;

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (source.isActive) ...[
                              Icon(Icons.circle,
                                  size: 8, color: Colors.green.shade600),
                              const SizedBox(width: 6),
                            ],
                            Text(label),
                          ],
                        ),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (_) => unawaited(_selectSourceById(source.id)),
                      ),
                    );
                  }),
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${loc.translate('active_source')}: $activeLabel'
                      '${selected.isActive ? '' : ' • ${loc.translate('source_not_running')}'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShortcuts(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.monitor_heart_rounded,
            title: AppLocalizations.of(context).translate('fall_monitor'),
            subtitle:
                AppLocalizations.of(context).translate('realtime_alert_view'),
            onTap: () => Navigator.of(context).pushNamed('/fall-detection'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.analytics_rounded,
            title: AppLocalizations.of(context).translate('analytics'),
            subtitle:
                AppLocalizations.of(context).translate('analytics_hero_desc'),
            onTap: () => widget.onOpenAnalytics?.call(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSection(ThemeData theme) {
    final loc = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_rounded, color: Color(0xFF0B2E4C)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      AppLocalizations.of(context).translate('recent_activity'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/history'),
                  child: Text(loc.translate('history')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 42, color: theme.colorScheme.outline),
                      const SizedBox(height: 10),
                      Text(loc.translate('no_data'),
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)
                            .translate('detection_events_will_appear'),
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: List.generate(_events.take(6).length, (index) {
                  final event = _events[index] as Map<String, dynamic>;
                  final action = _readAction(event);
                  final timestamp = _readTimestamp(event);
                  final actionColor = _colorForAction(action);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: actionColor.withOpacity(0.12)),
                        color: actionColor.withOpacity(0.06),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: actionColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_getIconForAction(action),
                              color: actionColor),
                        ),
                        title: Text(loc.actionLabel(action),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${_readTrackId(event)} • ${DateFormat('dd/MM HH:mm').format(timestamp)}'),
                        trailing: Text(_compactTime(timestamp),
                            style: theme.textTheme.bodySmall),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemSnapshot(ThemeData theme) {
    final loc = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.translate('system_snapshot'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _SnapshotCard(
                        label: loc.translate('reports'),
                        value: _reports.length.toString(),
                        icon: Icons.description_rounded)),
                const SizedBox(width: 12),
                Expanded(
                    child: _SnapshotCard(
                        label: loc.translate('history'),
                        value: _events.length.toString(),
                        icon: Icons.history_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/reports'),
                    icon: const Icon(Icons.assessment_rounded),
                    label: Text(loc.translate('open_reports')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(loc.translate('sync_data')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForAction(String action) {
    switch (action.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk;
      case 'standing':
        return Icons.accessibility;
      case 'sitting':
        return Icons.chair;
      case 'lying':
        return Icons.bed;
      case 'fall':
        return Icons.warning;
      default:
        return Icons.camera;
    }
  }

  Color _colorForAction(String action) {
    switch (action.toLowerCase()) {
      case 'walking':
        return const Color(0xFF3BC9DB);
      case 'standing':
        return const Color(0xFF1FBF9B);
      case 'sitting':
        return const Color(0xFFF1A53A);
      case 'lying':
        return const Color(0xFF0B2E4C);
      case 'fall':
        return const Color(0xFFF36B4E);
      default:
        return const Color(0xFF7B8AA0);
    }
  }

  String _readAction(dynamic event) {
    if (event is Map<String, dynamic>) {
      return (event['action'] ?? event['event'] ?? event['name'] ?? 'unknown')
          .toString();
    }
    return 'unknown';
  }

  String _readTrackId(dynamic event) {
    if (event is Map<String, dynamic>) {
      final loc = AppLocalizations.of(context);
      return (event['track_id'] ?? event['trackId'] ?? loc.translate('track'))
          .toString();
    }
    return AppLocalizations.of(context).translate('track');
  }

  DateTime _readTimestamp(dynamic event) {
    if (event is Map<String, dynamic>) {
      final raw = event['timestamp_ms'] ??
          event['generated_at_ms'] ??
          event['created_at_ms'] ??
          event['timestamp'];
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
      if (raw is String) {
        final parsedInt = int.tryParse(raw);
        if (parsedInt != null)
          return DateTime.fromMillisecondsSinceEpoch(parsedInt);
        final parsedDate = DateTime.tryParse(raw);
        if (parsedDate != null) return parsedDate;
      }
    }
    return DateTime.now();
  }

  String _compactTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd/MM').format(dateTime);
  }
}

class _FullscreenCameraView extends StatelessWidget {
  const _FullscreenCameraView({required this.name, required this.streamUrl});

  final String name;
  final String streamUrl;
  static final _storage = GetIt.instance<CustomSharedPreferences>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(name),
      ),
      body: Container(
        color: const Color(0xFF0B1218),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: streamUrl.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)
                              .translate('no_stream_available'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      )
                    : SafeMjpegView(
                        streamUrl: streamUrl,
                        headers: _storage.authorizationHeaders,
                        placeholder: Center(
                          child: Text(
                            AppLocalizations.of(context)
                                .translate('stream_unavailable'),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

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
            right: -30,
            child: _GlowBlob(
                color: const Color(0xFFF36B4E).withOpacity(0.14), size: 200),
          ),
          Positioned(
            bottom: -90,
            left: -40,
            child: _GlowBlob(
                color: const Color(0xFF1FBF9B).withOpacity(0.14), size: 220),
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
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 12)],
      ),
    );
  }
}

class _StreamStatusBadge extends StatelessWidget {
  const _StreamStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow(
      {required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text('${(clamped * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class ConnectionPill extends StatelessWidget {
  const ConnectionPill({super.key, required this.isConnected, this.error});

  final bool isConnected;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isConnected ? const Color(0xFF1FBF9B) : const Color(0xFFF1A53A))
            .withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: isConnected
                ? const Color(0xFF1FBF9B)
                : const Color(0xFFF1A53A)),
      ),
      child: Text(
        isConnected
            ? loc.translate('connected')
            : (error != null
                ? loc.translate('connection_error')
                : loc.translate('connecting')),
        style: TextStyle(
          color:
              isConnected ? const Color(0xFF1FBF9B) : const Color(0xFFF1A53A),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2E4C).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF0B2E4C)),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0B2E4C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0B2E4C), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
