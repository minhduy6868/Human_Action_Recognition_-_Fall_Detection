import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeStream {
  RealtimeStream(this.url);

  final String url;

  WebSocketChannel connect() {
    return WebSocketChannel.connect(Uri.parse(url));
  }

  Map<String, dynamic> decodeMessage(dynamic message) {
    if (message is List<int>) {
      return jsonDecode(utf8.decode(message)) as Map<String, dynamic>;
    }
    return jsonDecode(message as String) as Map<String, dynamic>;
  }
}
