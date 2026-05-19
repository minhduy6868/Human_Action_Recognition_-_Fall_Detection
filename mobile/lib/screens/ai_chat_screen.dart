import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/monitoring_api.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _api = GetIt.instance<MonitoringApi>();
  final _controller = TextEditingController();
  final _messages = <Map<String, dynamic>>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    _addMessage(
      'I have analyzed 24 hours of footage across your cameras. Everything looks secure. Is there anything specific you would like to know about today\'s activity or your home\'s safety history?',
      isAi: true,
    );
  }

  void _addMessage(String text, {bool isAi = false}) {
    setState(() {
      _messages.add({
        'text': text,
        'isAi': isAi,
        'timestamp': DateTime.now(),
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMessage = _controller.text;
    _controller.clear();

    _addMessage(userMessage, isAi: false);

    setState(() => _loading = true);
    try {
      // Simulate AI response - in production this would call an AI API
      await Future.delayed(const Duration(milliseconds: 500));

      final response = _generateAiResponse(userMessage);
      _addMessage(response, isAi: true);
    } catch (e) {
      _addMessage('Sorry, I encountered an error: $e', isAi: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  String _generateAiResponse(String query) {
    final lower = query.toLowerCase();

    if (lower.contains('motion') || lower.contains('movement')) {
      return 'I detected human motion in the living room at 14:15 today. The activity lasted about 45 seconds. Would you like more details?';
    } else if (lower.contains('fall') || lower.contains('accident')) {
      return 'No falls were detected in the past 24 hours. All residents appear to be moving normally.';
    } else if (lower.contains('door') || lower.contains('access')) {
      return 'The front door was accessed twice today: once at 9:42 AM (delivery) and once at 14:23 PM. Both events were normal.';
    } else if (lower.contains('alert') || lower.contains('warning')) {
      return 'There are no active alerts or warnings. All systems are functioning normally.';
    } else {
      return 'I\'ve analyzed the available data. Is there a specific time period or location you\'d like me to focus on?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: const Color(0xFF001a4d),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAi = msg['isAi'] as bool;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:
                        isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                    children: [
                      if (isAi) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.smart_toy,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAi ? Colors.grey[200] : Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg['text'] as String,
                            style: TextStyle(
                              color: isAi ? Colors.black87 : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (!isAi) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Text('AI is thinking...'),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about your home...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    enabled: !_loading,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _loading ? null : _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
