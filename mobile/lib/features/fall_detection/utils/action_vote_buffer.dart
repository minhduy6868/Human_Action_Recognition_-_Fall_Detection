/// Majority vote over recent WS samples to reduce flickery rule-based actions.
class ActionVoteBuffer {
  ActionVoteBuffer({this.window = 9});

  final int window;
  final List<String> _recent = <String>[];

  void clear() => _recent.clear();

  ({String action, double confidence}) push(String action, double confidence) {
    _recent.add(action);
    if (_recent.length > window) {
      _recent.removeAt(0);
    }

    final counts = <String, int>{};
    for (final a in _recent) {
      counts[a] = (counts[a] ?? 0) + 1;
    }

    var winner = action;
    var bestCount = -1;
    counts.forEach((key, value) {
      if (value > bestCount) {
        bestCount = value;
        winner = key;
      }
    });

    final denom = _recent.isEmpty ? 1 : _recent.length;
    final stability = bestCount / denom;
    final conf = (confidence * stability).clamp(0.0, 1.0);
    return (action: winner, confidence: conf);
  }
}
