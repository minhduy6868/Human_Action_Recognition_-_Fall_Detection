import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';

class StatsPanel extends StatelessWidget {
  const StatsPanel({
    super.key,
    required this.action,
    required this.confidence,
    required this.isFalling,
    required this.timestamp,
  });

  final String action;
  final double confidence;
  final bool isFalling;
  final DateTime timestamp;

  String _timeString(AppLocalizations loc) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return loc.translate('time_ago_s', {'n': diff.inSeconds});
    }
    if (diff.inMinutes < 60) {
      return loc.translate('time_ago_m', {'n': diff.inMinutes});
    }
    return loc.translate('time_ago_h', {'n': diff.inHours});
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? const Color(0xFF111C28) : const Color(0xFFF9FBFD),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.translate('live_statistics'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1FBF9B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          loc.translate('live'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              _StatRow(
                label: loc.translate('current_action'),
                value: loc.actionLabel(action),
                icon: Icons.directions_walk,
              ),
              _StatRow(
                label: loc.translate('confidence'),
                value: '${(confidence * 100).toStringAsFixed(1)}%',
                icon: Icons.analytics,
              ),
              _StatRow(
                label: loc.translate('status'),
                value: isFalling
                    ? loc.translate('fall_upper')
                    : loc.translate('safe'),
                icon: isFalling ? Icons.warning : Icons.check_circle,
                valueColor: isFalling ? Colors.red : const Color(0xFF1FBF9B),
              ),
              _StatRow(
                label: loc.translate('last_update'),
                value: _timeString(loc),
                icon: Icons.schedule,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: muted),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
