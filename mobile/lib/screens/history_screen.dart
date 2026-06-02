import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../services/monitoring_api.dart';
import '../shared_customization/localization/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = GetIt.instance<MonitoringApi>();
  bool _loading = true;
  List<dynamic> _items = [];

  int get _fallCount {
    return _items.where((item) {
      final action = ((item as Map<String, dynamic>)['action'] ?? '').toString().toLowerCase();
      return action == 'fall';
    }).length;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.getHistory(limit: 200);
      setState(() => _items = items);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('failed')}: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  DateTime _readTimestamp(Map<String, dynamic> item) {
    final raw = item['timestamp_ms'] ?? item['generated_at_ms'] ?? item['created_at_ms'] ?? item['timestamp'];
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    if (raw is String) {
      final parsedInt = int.tryParse(raw);
      if (parsedInt != null) return DateTime.fromMillisecondsSinceEpoch(parsedInt);
      final parsedDate = DateTime.tryParse(raw);
      if (parsedDate != null) return parsedDate;
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(loc.translate('history')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Stack(
        children: [
          _Backdrop(theme: theme),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _HeroCard(total: _items.length, fallCount: _fallCount),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_items.isEmpty)
                    _EmptyState(onRefresh: _load)
                  else
                    ..._items.take(40).map((item) {
                      final event = item as Map<String, dynamic>;
                      final action = (event['action'] ?? 'unknown').toString();
                      final trackId = (event['track_id'] ?? 'N/A').toString();
                      final timestamp = _readTimestamp(event);
                      final actionColor = _actionColor(action);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: actionColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(_actionIcon(action), color: actionColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(loc.actionLabel(action), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text('${AppLocalizations.of(context).translate('track')}: $trackId', style: theme.textTheme.bodySmall),
                                      const SizedBox(height: 6),
                                      Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp), style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                _ActionChip(label: loc.actionLabelUpper(action), color: actionColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _actionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'standing':
        return Icons.accessibility_new_rounded;
      case 'sitting':
        return Icons.chair_rounded;
      case 'lying':
        return Icons.bed_rounded;
      case 'fall':
        return Icons.warning_rounded;
      default:
        return Icons.timeline_rounded;
    }
  }

  Color _actionColor(String action) {
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
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.total, required this.fallCount});

  final int total;
  final int fallCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B2E4C), Color(0xFF124B6C)],
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
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.history_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).translate('activity_history'), style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context).translate('review_realtime_events'), style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.88))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(label: '$total events', color: Colors.white),
                      _Badge(label: '$fallCount falls', color: const Color(0xFFF36B4E)),
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
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final light = color == Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: light ? Colors.white : color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: light ? const Color(0xFF0B2E4C) : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).translate('no_history_items'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(AppLocalizations.of(context).translate('refresh_after_backend'), style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context).translate('refresh')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
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
    );
  }
}
