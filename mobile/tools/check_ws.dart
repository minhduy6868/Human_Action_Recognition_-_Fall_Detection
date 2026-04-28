import 'dart:async';

import 'package:web_socket_channel/io.dart';
import 'package:video_ai_detect/core/app_config.dart';

Future<void> main() async {
  final url = AppConfig.wsUrl;
  print('Connecting to $url');

  late IOWebSocketChannel channel;
  try {
    channel = IOWebSocketChannel.connect(url);
  } catch (e) {
    print('Failed to connect: $e');
    return;
  }

  final completer = Completer<void>();

  final sub = channel.stream.listen(
    (message) {
      print('Received: $message');
      if (!completer.isCompleted) completer.complete();
    },
    onError: (e) {
      print('Stream error: $e');
      if (!completer.isCompleted) completer.complete();
    },
    onDone: () {
      print('Stream closed by server');
      if (!completer.isCompleted) completer.complete();
    },
  );

  // Wait for a message or timeout
  await Future.any([completer.future, Future.delayed(const Duration(seconds: 10))]);

  await sub.cancel();
  await channel.sink.close();

  print('Check complete');
}
