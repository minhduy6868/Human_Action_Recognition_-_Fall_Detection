import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../core/l10n/app_localizations.dart';
import '../models/source.dart';
import '../services/monitoring_api.dart';
import '../services/sources_api.dart';
import '../state/selected_source/selected_source_cubit.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = GetIt.instance<MonitoringApi>();
  final _sourcesApi = GetIt.instance<SourcesApi>();
  bool _loading = true;
  List<dynamic> _items = [];
  List<Source> _sources = [];
  String? _sourceId;

  int get _totalWindowMs {
    return _items.fold<int>(0, (sum, item) {
      final map = item as Map<String, dynamic>;
      final window = map['window_ms'];
      if (window is num) return sum + window.toInt();
      return sum;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sourceId = context.read<SelectedSourceCubit>().state.selectedSourceId;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sources = await _sourcesApi.listSources();
      final items = await _api.getReports(sourceId: _sourceId);
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _items = items;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('failed')}: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  DateTime _readTimestamp(Map<String, dynamic> item) {
    final raw = item['generated_at_ms'] ?? item['timestamp_ms'] ?? item['created_at_ms'] ?? item['timestamp'];
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

  String _insightLine(AppLocalizations loc, Map<String, dynamic> report) {
    final insight = report['insight'];
    if (insight is! Map) return '';
    final action = loc.actionLabel((insight['dominant_action'] ?? 'unknown').toString());
    final samples = insight['total_samples'] ?? 0;
    final falls = insight['fall_detected'] == true;
    return loc.translate('insight_line', {
      'action': action,
      'samples': samples,
      'fall_suffix': falls ? loc.translate('insight_fall_suffix') : '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('reports')),
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
                  _HeroCard(total: _items.length, totalWindowMs: _totalWindowMs),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: Text(loc.translate('all_sources')),
                        selected: _sourceId == null,
                        onSelected: (_) {
                          setState(() => _sourceId = null);
                          _load();
                        },
                      ),
                      ..._sources.map(
                        (s) => FilterChip(
                          label: Text(s.name.isEmpty ? s.id : s.name),
                          selected: _sourceId == s.id,
                          onSelected: (_) {
                            setState(() => _sourceId = s.id);
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_items.isEmpty)
                    _EmptyState(onRefresh: _load)
                  else
                    ..._items.take(50).map((item) {
                      final report = item as Map<String, dynamic>;
                      final title =
                          (report['title'] ?? loc.translate('default_report')).toString();
                      final windowMs = report['window_ms'];
                      final generatedAt = _readTimestamp(report);
                      final color = _reportColor(title);

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
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.assessment_rounded, color: color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${loc.translate('window')}: ${windowMs ?? '-'} ${loc.translate('ms_unit')}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      if (_insightLine(loc, report).isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(_insightLine(loc, report), style: theme.textTheme.bodySmall),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(generatedAt), style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                _ReportChip(label: AppLocalizations.of(context).translate('report').toUpperCase(), color: color),
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

  Color _reportColor(String title) {
    final text = title.toLowerCase();
    if (text.contains('fall')) return const Color(0xFFF36B4E);
    if (text.contains('activity')) return const Color(0xFF1FBF9B);
    return const Color(0xFF0B2E4C);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.total, required this.totalWindowMs});

  final int total;
  final int totalWindowMs;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
              child: const Icon(Icons.description_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.translate('reports'), style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(loc.translate('reports_desc'), style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.88))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(
                        label: loc.translate('reports_badge', {'count': total}),
                        color: Colors.white,
                      ),
                      _Badge(
                        label: loc.translate('window_ms_badge', {'ms': totalWindowMs}),
                        color: const Color(0xFF1FBF9B),
                      ),
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

class _ReportChip extends StatelessWidget {
  const _ReportChip({required this.label, required this.color});

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
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(loc.translate('no_reports_available'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(loc.translate('refresh_reports_body'), style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(loc.translate('refresh')),
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
