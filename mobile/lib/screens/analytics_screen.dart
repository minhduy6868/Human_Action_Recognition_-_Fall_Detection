import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../core/l10n/app_localizations.dart';
import '../models/source.dart';
import '../services/monitoring_api.dart';
import '../services/sources_api.dart';
import '../state/auth/auth_cubit.dart';
import '../state/selected_source/selected_source_cubit.dart';
import '../state/selected_source/selected_source_state.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _monitoring = GetIt.instance<MonitoringApi>();
  final _sourcesApi = GetIt.instance<SourcesApi>();

  List<Source> _sources = [];
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;
  String? _sourceId;
  int _hours = 24;
  bool _isVip = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final plan = context.read<AuthCubit>().state.user?.plan ?? 'free';
    _isVip = plan.toLowerCase() == 'vip';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selected = context.read<SelectedSourceCubit>().state.selectedSourceId;
      _sourceId = selected;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sources = await _sourcesApi.listSources();
      final now = DateTime.now().toUtc();
      final from = now.subtract(Duration(hours: _hours)).millisecondsSinceEpoch;
      final logs = await _monitoring.getLogs(
        limit: _isVip ? 2000 : 800,
        sourceId: _sourceId,
        fromMs: from,
        toMs: now.millisecondsSinceEpoch,
      );
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _logs = logs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _label(String? id) {
    final loc = AppLocalizations.of(context);
    if (id == null) return loc.translate('all_sources');
    for (final s in _sources) {
      if (s.id == id) return s.name.isEmpty ? s.id : s.name;
    }
    return id;
  }

  int _falls() => _logs.where((l) => l['fall'] == true).length;

  Map<String, int> _actions() {
    final m = <String, int>{};
    for (final l in _logs) {
      final a = (l['action'] ?? 'unknown').toString();
      m[a] = (m[a] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final actions = _actions();
    final topActions = actions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BlocListener<SelectedSourceCubit, SelectedSourceState>(
      listenWhen: (prev, next) => prev.selectedSourceId != next.selectedSourceId,
      listener: (_, state) {
        setState(() => _sourceId = state.selectedSourceId);
        _load();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('analytics')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: Text(loc.translate('retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text(
                      _isVip
                          ? loc.translate('analytics_vip_title')
                          : loc.translate('analytics_free_title'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(loc.translate('window_24h')),
                          selected: _hours == 24,
                          onSelected: (_) {
                            setState(() => _hours = 24);
                            _load();
                          },
                        ),
                        ChoiceChip(
                          label: Text(loc.translate('window_7d')),
                          selected: _hours == 168,
                          onSelected: (_) {
                            setState(() => _hours = 168);
                            _load();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
                    if (_logs.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(loc.translate('analytics_empty_title')),
                              const SizedBox(height: 8),
                              Text(
                                loc.translate('analytics_empty_with_sources'),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/sources'),
                                child: Text(loc.translate('manage_sources')),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          _stat(context, '${_logs.length}', loc.translate('total_events')),
                          const SizedBox(width: 8),
                          _stat(context, '${_falls()}', loc.translate('fall_detected')),
                          const SizedBox(width: 8),
                          _stat(context, _label(_sourceId), loc.translate('source_field')),
                        ],
                      ),
                      if (_isVip && _sources.length > 1) ...[
                        const SizedBox(height: 12),
                        Text(loc.translate('analytics_per_source'),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ..._sources.map((s) {
                          final count = _logs
                              .where((l) => l['source_id'] == s.id)
                              .length;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(s.name.isEmpty ? s.id : s.name),
                            trailing: Text('$count'),
                            onTap: () {
                              setState(() => _sourceId = s.id);
                              _load();
                            },
                          );
                        }),
                      ],
                      const SizedBox(height: 12),
                      Text(loc.translate('action_distribution'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...topActions.take(5).map((e) {
                        final total = _logs.length;
                        final p = total == 0 ? 0.0 : e.value / total;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(loc.actionLabel(e.key)),
                              ),
                              Expanded(
                                flex: 3,
                                child: LinearProgressIndicator(value: p),
                              ),
                              const SizedBox(width: 8),
                              Text('${e.value}'),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.translate('recent_detections'),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/history'),
                            child: Text(loc.translate('view_full_history')),
                          ),
                        ],
                      ),
                      ..._logs.take(6).map((log) {
                        final ts = log['timestamp_ms'];
                        final dt = ts is int
                            ? DateTime.fromMillisecondsSinceEpoch(ts)
                            : DateTime.now();
                        final action = (log['action'] ?? '?').toString();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            log['fall'] == true
                                ? Icons.warning_amber
                                : Icons.circle,
                            size: 10,
                            color: log['fall'] == true
                                ? Colors.red
                                : Colors.grey,
                          ),
                          title: Text(loc.actionLabel(action)),
                          subtitle: Text(
                            '${_label((log['source_id'] ?? '').toString())} · ${DateFormat('dd/MM HH:mm').format(dt)}',
                          ),
                        );
                      }),
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
