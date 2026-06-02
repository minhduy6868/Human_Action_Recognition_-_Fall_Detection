import 'package:flutter/material.dart';

import '../../shared_customization/localization/app_localizations.dart';

class ConnectionStatus extends StatelessWidget {
  final bool isConnected;
  final String? error;

  const ConnectionStatus({
    super.key,
    required this.isConnected,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1FBF9B).withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1FBF9B), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1FBF9B),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              loc.translate('connected'),
              style: const TextStyle(
                color: Color(0xFF1FBF9B),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1A53A).withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1A53A), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF1A53A)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            error != null ? loc.translate('connection_error') : loc.translate('connecting'),
            style: const TextStyle(
              color: Color(0xFFF1A53A),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
