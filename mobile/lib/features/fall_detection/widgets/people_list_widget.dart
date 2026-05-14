import 'package:flutter/material.dart';

import '../../../models/person_action.dart';

class PeopleListWidget extends StatelessWidget {
  const PeopleListWidget({
    super.key,
    required this.people,
  });

  final List<PersonAction> people;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.person_off, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Text(
                'No people detected',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                Icon(Icons.people, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'People Detected (${people.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0, color: Colors.grey[300]),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: people.length,
            separatorBuilder: (_, __) => Divider(
              height: 0,
              color: Colors.grey[200],
            ),
            itemBuilder: (context, index) {
              final person = people[index];
              return _buildPersonTile(person);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonTile(PersonAction person) {
    Color actionColor = Colors.blue;
    IconData actionIcon = Icons.person;

    switch (person.action.toLowerCase()) {
      case 'walking':
        actionColor = Colors.blue;
        actionIcon = Icons.directions_walk;
        break;
      case 'running':
        actionColor = Colors.deepPurple;
        actionIcon = Icons.directions_run;
        break;
      case 'sitting':
        actionColor = Colors.green;
        actionIcon = Icons.chair;
        break;
      case 'standing':
        actionColor = Colors.orange;
        actionIcon = Icons.person;
        break;
      case 'lying':
        actionColor = Colors.red;
        actionIcon = Icons.bed;
        break;
      case 'crouching':
        actionColor = Colors.teal;
        actionIcon = Icons.accessibility_new;
        break;
    }

    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: actionColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(actionIcon, color: actionColor),
      ),
      title: Text(
        'Person #${person.trackId}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Chip(
                label: Text(person.actionDisplay),
                backgroundColor: actionColor.withOpacity(0.3),
                labelStyle: TextStyle(color: actionColor, fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Text(
                '${(person.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          if (person.clothing.upper != 'unknown' || person.clothing.lower != 'unknown')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.checkroom, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      person.clothingDescription,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: person.fall
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'FALL',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
