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
        return Colors.blue;
      case 'walking':
        return Colors.cyan;
      case 'running':
        return Colors.deepPurple;
      case 'sitting':
        return Colors.orange;
      case 'lying':
        return Colors.purple;
      case 'crouching':
        return Colors.teal;
      default:
        return Colors.grey;
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
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              actionColor.withOpacity(0.8),
              actionColor.withOpacity(0.4),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Action Icon
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              padding: const EdgeInsets.all(20),
              child: Icon(
                actionIcon,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Action Name
            Text(
              _actionLabel(action),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Confidence Bar
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
                        color: Colors.white.withOpacity(0.8),
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
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: conf01,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),

            // Fall Status
            if (isFalling) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'FALL DETECTED!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
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
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
