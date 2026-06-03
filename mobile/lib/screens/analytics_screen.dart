import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../services/monitoring_api.dart';
import '../core/l10n/app_localizations.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _api = GetIt.instance<MonitoringApi>();
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getHistory(limit: 2000),
        _api.getReports(limit: 50),
        _api.getLogs(limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _history = results[0];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, int> _countActionsByType() {
    final counts = <String, int>{};
    for (final item in _history) {
      final action = ((item as Map<String, dynamic>)['action'] ?? 'unknown').toString();
      counts[action] = (counts[action] ?? 0) + 1;
    }
    return counts;
  }

  int _countFalls() {
    return _history.where((item) {
      final map = item as Map<String, dynamic>;
      return map['fall'] == true || (map['action'] ?? '').toString().toLowerCase() == 'fall';
    }).length;
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
        title: Text(loc.translate('summary')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadAnalytics, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Stack(
        children: [
          _Backdrop(theme: theme),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _HeroCard(total: _history.length, falls: _countFalls()),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total events',
                            value: '${_history.length}',
                            icon: Icons.event_rounded,
                            color: const Color(0xFF1FBF9B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Falls',
                            value: '${_countFalls()}',
                            icon: Icons.warning_rounded,
                            color: const Color(0xFFF36B4E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Actions',
                            value: '${_countActionsByType().length}',
                            icon: Icons.timeline_rounded,
                            color: const Color(0xFF3BC9DB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Last updated',
                            value: _history.isEmpty
                                ? '--'
                                : DateFormat('HH:mm').format(_readTimestamp(_history.first as Map<String, dynamic>)),
                            icon: Icons.schedule_rounded,
                            color: const Color(0xFFF1A53A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.translate('summary'),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _buildActionChart(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.translate('history'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushNamed('/history'),
                          child: Text(loc.translate('history')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._buildRecentEventsList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChart() {
    final loc = AppLocalizations.of(context);
    final counts = _countActionsByType();
    if (counts.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              loc.translate('no_data'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...sorted.map((entry) {
              final percentage = (entry.value / total * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            loc.actionLabel(entry.key),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value / total,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getColorForAction(entry.key),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecentEventsList() {
    final loc = AppLocalizations.of(context);
    if (_history.isEmpty) {
      return [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                loc.translate('no_data'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ),
      ];
    }

    return _history.take(10).map((item) {
      final event = item as Map<String, dynamic>;
      final action = (event['action'] ?? 'unknown').toString();
      final trackId = (event['track_id'] ?? 'N/A').toString();
      final timestamp = _readTimestamp(event);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _getColorForAction(action).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _getIconForAction(action),
                color: _getColorForAction(action),
              ),
            ),
            title: Text(loc.actionLabel(action)),
            subtitle: Text('Track: $trackId • ${DateFormat('dd/MM HH:mm').format(timestamp)}'),
          ),
        ),
      );
    }).toList();
  }

  Color _getColorForAction(String action) {
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

  IconData _getIconForAction(String action) {
    switch (action.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'standing':
        return Icons.accessibility_rounded;
      case 'sitting':
        return Icons.chair_rounded;
      case 'lying':
        return Icons.bed_rounded;
      case 'fall':
        return Icons.warning_rounded;
      default:
        return Icons.camera_rounded;
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.total, required this.falls});

  final int total;
  final int falls;

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
              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Báo cáo phân phối hành động và sự kiện gần nhất từ database.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.88))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(label: '$total events', color: Colors.white),
                      _Badge(label: '$falls falls', color: const Color(0xFFF36B4E)),
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
      child: Text(label, style: TextStyle(color: light ? const Color(0xFF0B2E4C) : color, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
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
