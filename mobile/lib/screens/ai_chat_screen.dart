import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../core/l10n/app_localizations.dart';
import '../models/source.dart';
import '../services/monitoring_api.dart';
import '../state/selected_source/selected_source_cubit.dart';
import '../state/selected_source/selected_source_state.dart';
import '../utils/plan_limit_dialog.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _api = GetIt.instance<MonitoringApi>();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<({String text, bool isAi})> _messages = [];

  bool _loading = false;
  bool _welcomeAdded = false;
  int _windowMs = 6 * 60 * 60 * 1000;
  List<Source> _sources = [];
  String? _sourceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSourcesFromScope());
  }

  void _syncSourcesFromScope() {
    final cubit = context.read<SelectedSourceCubit>();
    final state = cubit.state;
    setState(() {
      _sources = state.sources;
      _sourceId = state.selectedSourceId;
    });
    if (state.sources.isEmpty) {
      cubit.refreshSources().then((_) {
        if (!mounted) return;
        final refreshed = context.read<SelectedSourceCubit>().state;
        setState(() {
          _sources = refreshed.sources;
          _sourceId = refreshed.selectedSourceId;
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_welcomeAdded) {
      _welcomeAdded = true;
      _bootstrapMessages();
    }
  }

  Future<void> _bootstrapMessages() async {
    final loc = AppLocalizations.of(context);
    final seeded = <({String text, bool isAi})>[
      (text: loc.translate('ai_welcome'), isAi: true),
    ];
    try {
      final rows = await _api.getChatHistory(limit: 40);
      final historical = <({String text, bool isAi})>[];
      for (final row in rows.reversed) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final q = (map['question'] ?? '').toString().trim();
        final a = (map['answer'] ?? '').toString().trim();
        if (q.isNotEmpty) historical.add((text: q, isAi: false));
        if (a.isNotEmpty) historical.add((text: a, isAi: true));
      }
      seeded.addAll(historical);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(seeded);
    });
  }

  String _cameraLabel(AppLocalizations loc) {
    if (_sourceId == null) return loc.translate('ai_all_cameras');
    for (final s in _sources) {
      if (s.id == _sourceId) return s.name.isEmpty ? s.id : s.name;
    }
    return _sourceId!;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final loc = AppLocalizations.of(context);
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _messages.add((text: question, isAi: false));
      _loading = true;
    });
    _scrollBottom();

    try {
      final data = await _api.askAssistant(
        question,
        windowMs: _windowMs,
        sourceId: _sourceId,
      );
      final answer = (data['answer'] ?? data['message'] ?? '')
          .toString()
          .trim();
      if (!mounted) return;
      setState(() {
        _messages.add((
          text: answer.isEmpty ? loc.translate('ai_no_data') : answer,
          isAi: true,
        ));
      });
    } catch (e) {
      if (!mounted) return;
      if (await PlanLimitDialog.handleError(context, e)) return;
      setState(() => _messages.add((
        text: loc.translate('ai_error_prefix', {'message': '$e'}),
        isAi: true,
      )));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollBottom();
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return BlocListener<SelectedSourceCubit, SelectedSourceState>(
      listenWhen: (prev, next) =>
          prev.selectedSourceId != next.selectedSourceId ||
          prev.sources.length != next.sources.length,
      listener: (_, state) {
        setState(() {
          _sources = state.sources;
          _sourceId = state.selectedSourceId;
        });
      },
      child: Scaffold(
      appBar: AppBar(title: Text(loc.translate('ai_assistant'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.videocam_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loc.translate('ai_camera_label', {'name': _cameraLabel(loc)}),
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_sources.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _sources
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(s.name.isEmpty ? s.id : s.name),
                                selected: _sourceId == s.id,
                                visualDensity: VisualDensity.compact,
                                onSelected: _loading
                                    ? null
                                    : (_) {
                                        setState(() => _sourceId = s.id);
                                        context
                                            .read<SelectedSourceCubit>()
                                            .selectSource(s.id);
                                      },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _timeChip(loc, 'time_chip_1h', 3600000),
                    const SizedBox(width: 6),
                    _timeChip(loc, 'time_chip_6h', 21600000),
                    const SizedBox(width: 6),
                    _timeChip(loc, 'time_chip_24h', 86400000),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ActionChip(
                  label: Text(loc.translate('ai_chip_timeline')),
                  onPressed: _loading
                      ? null
                      : () => _send(loc.translate('send_question_timeline')),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: Text(loc.translate('ai_chip_fall')),
                  onPressed: _loading
                      ? null
                      : () => _send(loc.translate('send_question_fall')),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (_loading && i == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(),
                  );
                }
                final m = _messages[i];
                return Align(
                  alignment:
                      m.isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                    ),
                    decoration: BoxDecoration(
                      color: m.isAi
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: m.isAi
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              8 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_loading,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: loc.translate('ai_input_hint'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : () => _send(),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _timeChip(AppLocalizations loc, String labelKey, int ms) {
    final selected = _windowMs == ms;
    return ChoiceChip(
      label: Text(loc.translate(labelKey)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _windowMs = ms),
    );
  }
}
