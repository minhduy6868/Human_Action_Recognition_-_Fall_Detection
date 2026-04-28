import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeStream {
  RealtimeStream(this.url);

  final String url;

  WebSocketChannel connect() {
    return WebSocketChannel.connect(Uri.parse(url));
  }

  Map<String, dynamic> decodeMessage(dynamic message) {
    return jsonDecode(message as String) as Map<String, dynamic>;
  }
}
