import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String action;
  final double confidence;
  final bool isFalling;
  final double fallConfidence;

  const StatusCard({
    super.key,
    required this.action,
    required this.confidence,
    required this.isFalling,
    required this.fallConfidence,
  });

  static double _clamp01(double v) {
    if (v.isNaN || v.isInfinite) return 0;
    return v.clamp(0.0, 1.0);
  }

  static String _actionLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'standing':
        return 'STANDING';
      case 'walking':
        return 'WALKING';
      case 'running':
        return 'RUNNING';
      case 'sitting':
        return 'SITTING';
      case 'lying':
        return 'LYING';
      case 'crouching':
        return 'CROUCHING';
      default:
        return 'UNKNOWN';
    }
  }

  Color get actionColor {
    switch (action.toLowerCase()) {
      case 'standing':
        return const Color(0xFF1C7ED6);
      case 'walking':
        return const Color(0xFF3BC9DB);
      case 'running':
        return const Color(0xFFFF6B6B);
      case 'sitting':
        return const Color(0xFFF59F00);
      case 'lying':
        return const Color(0xFF2F9E44);
      case 'crouching':
        return const Color(0xFF12B886);
      default:
        return const Color(0xFF8391A1);
    }
  }

  IconData get actionIcon {
    switch (action.toLowerCase()) {
      case 'standing':
        return Icons.person;
      case 'walking':
        return Icons.directions_walk;
      case 'running':
        return Icons.directions_run;
      case 'sitting':
        return Icons.chair;
      case 'lying':
        return Icons.hotel;
      case 'crouching':
        return Icons.accessibility_new;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final conf01 = _clamp01(confidence);
    final fall01 = _clamp01(fallConfidence);
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              actionColor.withOpacity(0.92),
              actionColor.withOpacity(0.5),
            ],
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18),
              ),
              padding: const EdgeInsets.all(18),
              child: Icon(
                actionIcon,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _actionLabel(action),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Confidence',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    Text(
                      '${(conf01 * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: conf01,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.92),
                    ),
                  ),
                ),
              ],
            ),
            if (isFalling) ...[
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'FALL DETECTED',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confidence: ${(fall01 * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
