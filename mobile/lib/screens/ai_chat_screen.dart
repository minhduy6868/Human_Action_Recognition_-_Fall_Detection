import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../services/monitoring_api.dart';
import '../core/l10n/app_localizations.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

enum _AssistantMode { databaseSummary, realtimeAssistant }

class _AiChatScreenState extends State<AiChatScreen> {
  final _api = GetIt.instance<MonitoringApi>();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <Map<String, dynamic>>[];

  bool _loading = false;
  _AssistantMode _mode = _AssistantMode.databaseSummary;
  int _selectedWindowMs = 24 * 60 * 60 * 1000;

  static const _windows = [
    (label: '1h', value: 60 * 60 * 1000),
    (label: '6h', value: 6 * 60 * 60 * 1000),
    (label: '24h', value: 24 * 60 * 60 * 1000),
    (label: '7d', value: 7 * 24 * 60 * 60 * 1000),
  ];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    _addMessage(
      'Tôi có thể tóm tắt hành động từ database theo 1h, 6h, 24h hoặc 7 ngày. Hãy nhập câu hỏi như “Hôm nay có gì bất thường?” hoặc “Tóm tắt 6 giờ gần nhất”.',
      isAi: true,
      meta: {'kind': 'welcome'},
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addMessage(
    String text, {
    required bool isAi,
    Map<String, dynamic>? meta,
  }) {
    setState(() {
      _messages.add({
        'text': text,
        'isAi': isAi,
        'timestamp': DateTime.now(),
        'meta': meta ?? const <String, dynamic>{},
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty || _loading) return;

    _controller.clear();
    _addMessage(userMessage, isAi: false);

    setState(() => _loading = true);
    try {
      final now = DateTime.now().toUtc();
      final from = now.subtract(Duration(milliseconds: _selectedWindowMs));
      final Map<String, dynamic> data;

      if (_mode == _AssistantMode.databaseSummary) {
        data = await _api.summarizeActivity(
          question: userMessage,
          from: from,
          to: now,
        );
      } else {
        data = await _api.askAssistant(
          userMessage,
          windowMs: _selectedWindowMs,
        );
      }

      final answer = (data['answer'] ?? data['message'] ?? data['summary'] ?? 'Không có phản hồi từ backend.').toString();
      final insight = data['insight'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final meta = _buildAnswerMeta(data, insight);
      _addMessage(answer, isAi: true, meta: meta);
    } catch (e) {
      _addMessage('Không thể lấy dữ liệu lúc này: $e', isAi: true, meta: {'kind': 'error'});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _buildAnswerMeta(Map<String, dynamic> data, Map<String, dynamic> insight) {
    final labels = (insight['segments'] as List<dynamic>?)?.length ?? 0;
    return {
      'intent': data['intent']?.toString() ?? '',
      'window_ms': data['window_ms'] ?? insight['window_ms'] ?? _selectedWindowMs,
      'total_samples': insight['total_samples'] ?? 0,
      'dominant_action': insight['dominant_action']?.toString() ?? 'unknown',
      'dominant_action_ratio': insight['dominant_action_ratio'] ?? 0,
      'fall_detected': insight['fall_detected'] ?? false,
      'segments': labels,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(loc.translate('ai_assistant')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh summary',
            onPressed: _loading ? null : _sendMessage,
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<_AssistantMode>(
                              segments: const [
                                ButtonSegment(
                                  value: _AssistantMode.databaseSummary,
                                  icon: Icon(Icons.storage_rounded),
                                  label: Text('Database'),
                                ),
                                ButtonSegment(
                                  value: _AssistantMode.realtimeAssistant,
                                  icon: Icon(Icons.flash_on_rounded),
                                  label: Text('Realtime'),
                                ),
                              ],
                              selected: {_mode},
                              onSelectionChanged: (value) {
                                setState(() => _mode = value.first);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _windows.map((item) {
                          final selected = _selectedWindowMs == item.value;
                          return ChoiceChip(
                            label: Text(item.label),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedWindowMs = item.value);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isAi = msg['isAi'] as bool;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MessageBubble(
                          text: msg['text'] as String,
                          isAi: isAi,
                          timestamp: msg['timestamp'] as DateTime,
                          meta: msg['meta'] as Map<String, dynamic>,
                        ),
                      );
                    },
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    12 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withOpacity(0.96),
                    border: Border(top: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: _mode == _AssistantMode.databaseSummary
                                ? 'Ví dụ: Tóm tắt 6 giờ gần nhất, có té ngã không?'
                                : 'Ví dụ: Có cảnh báo nào mới không?',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          enabled: !_loading,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        mini: true,
                        onPressed: _loading ? null : _sendMessage,
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
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
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isAi,
    required this.timestamp,
    required this.meta,
  });

  final String text;
  final bool isAi;
  final DateTime timestamp;
  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bubbleColor = isAi
        ? theme.brightness == Brightness.dark
            ? const Color(0xFF101B25)
            : Colors.white
        : colorScheme.secondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (isAi) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isAi ? 4 : 16),
                bottomRight: Radius.circular(isAi ? 16 : 4),
              ),
              border: Border.all(
                color: isAi ? theme.dividerColor.withOpacity(0.35) : colorScheme.secondary,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: isAi ? theme.textTheme.bodyMedium?.color : Colors.white,
                    height: 1.35,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _metaChips(meta),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  DateFormat('HH:mm').format(timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isAi ? theme.textTheme.bodySmall?.color : Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isAi) ...[
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.person_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _metaChips(Map<String, dynamic> meta) {
    final chips = <Widget>[];
    final intent = meta['intent']?.toString();
    final windowMs = meta['window_ms'];
    final totalSamples = meta['total_samples'];
    final dominantAction = meta['dominant_action']?.toString();
    final fallDetected = meta['fall_detected'] == true;
    final segments = meta['segments'];

    if (intent != null && intent.isNotEmpty) {
      chips.add(_MetaChip(label: intent));
    }
    if (windowMs != null) {
      chips.add(_MetaChip(label: '${_windowText(windowMs)} window'));
    }
    if (totalSamples != null) {
      chips.add(_MetaChip(label: '$totalSamples samples'));
    }
    if (dominantAction != null && dominantAction.isNotEmpty) {
      chips.add(_MetaChip(label: 'Dominant: $dominantAction'));
    }
    if (fallDetected) {
      chips.add(_MetaChip(label: 'Fall detected', color: const Color(0xFFF36B4E)));
    }
    if (segments != null) {
      chips.add(_MetaChip(label: '$segments segments'));
    }
    return chips;
  }

  String _windowText(dynamic windowMs) {
    final value = windowMs is num ? windowMs.toInt() : int.tryParse(windowMs?.toString() ?? '0') ?? 0;
    if (value >= 7 * 24 * 60 * 60 * 1000) return '7d';
    if (value >= 24 * 60 * 60 * 1000) return '24h';
    if (value >= 6 * 60 * 60 * 1000) return '6h';
    return '1h';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.color = const Color(0xFF0B2E4C)});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
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
