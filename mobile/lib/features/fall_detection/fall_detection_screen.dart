import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../services/realtime_stream.dart';

class FallDetectionScreen extends StatefulWidget {
  const FallDetectionScreen({super.key});

  @override
  State<FallDetectionScreen> createState() => _FallDetectionScreenState();
}

class _FallDetectionScreenState extends State<FallDetectionScreen> {
  static const String wsUrl = 'ws://127.0.0.1:8000/api/ws';
  late final RealtimeStream _stream;
  late final WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    _stream = RealtimeStream(wsUrl);
    channel = _stream.connect();
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fall Detection')),
      body: StreamBuilder(
        stream: channel.stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Text('Waiting for stream...'));
          }

          final data = _stream.decodeMessage(snapshot.data);
          final action = data['action'] ?? 'unknown';
          final fall = data['fall'] ?? false;
          final confidence = data['confidence'] ?? 0.0;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Action: $action'),
                Text('Fall: $fall'),
                Text('Confidence: $confidence'),
              ],
            ),
          );
        },
      ),
    );
  }
}
