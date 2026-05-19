import 'package:flutter/material.dart';

import '../../models/detected_object.dart';

class ObjectsListWidget extends StatelessWidget {
  const ObjectsListWidget({
    super.key,
    required this.objects,
  });

  final List<DetectedObject> objects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nonPeopleObjects = objects.where((obj) => !obj.isPerson).toList();

    if (nonPeopleObjects.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 12),
              Text(
                'No other objects detected',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.category, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Objects Detected (${nonPeopleObjects.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0, color: theme.dividerColor),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nonPeopleObjects.length,
            separatorBuilder: (_, __) => Divider(
              height: 0,
              color: theme.dividerColor,
            ),
            itemBuilder: (context, index) {
              final obj = nonPeopleObjects[index];
              return _buildObjectTile(obj);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildObjectTile(DetectedObject obj) {
    final color = _getObjectColor(obj.label);

    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.layers, color: color),
      ),
      title: Text(
        obj.objectType,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'Class ID: ${obj.classId}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: Chip(
        label: Text('${(obj.confidence * 100).toStringAsFixed(1)}%'),
        backgroundColor: color.withOpacity(0.2),
        labelStyle: TextStyle(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Color _getObjectColor(String label) {
    final labelLower = label.toLowerCase();
    if (labelLower.contains('chair')) return const Color(0xFF9C6B3A);
    if (labelLower.contains('table')) return const Color(0xFFF59F00);
    if (labelLower.contains('bed')) return const Color(0xFFE8590C);
    if (labelLower.contains('door')) return const Color(0xFF3BC9DB);
    if (labelLower.contains('window')) return const Color(0xFF1FBF9B);
    return const Color(0xFF1C7ED6);
  }
}
