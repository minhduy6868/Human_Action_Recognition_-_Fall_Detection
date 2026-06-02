import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class SafeMjpegView extends StatefulWidget {
  const SafeMjpegView({
    super.key,
    required this.streamUrl,
    this.headers,
    required this.placeholder,
    this.enabled = true,
  });

  final String streamUrl;
  final Map<String, String>? headers;
  final Widget placeholder;
  final bool enabled;

  @override
  State<SafeMjpegView> createState() => _SafeMjpegViewState();
}

class _SafeMjpegViewState extends State<SafeMjpegView> {
  bool _failed = false;
  int _generation = 0;

  @override
  void didUpdateWidget(SafeMjpegView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl || oldWidget.enabled != widget.enabled) {
      _failed = false;
      _generation++;
    }
  }

  void _markFailed() {
    if (!mounted || _failed) return;
    setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.streamUrl.isEmpty || _failed) {
      return widget.placeholder;
    }

    return Mjpeg(
      key: ValueKey('mjpeg-${widget.streamUrl}-$_generation'),
      isLive: true,
      stream: widget.streamUrl,
      headers: widget.headers ?? const {},
      error: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _markFailed());
        return widget.placeholder;
      },
    );
  }
}
