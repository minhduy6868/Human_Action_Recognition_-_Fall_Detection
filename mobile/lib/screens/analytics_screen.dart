import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/monitoring_api.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _api = GetIt.instance<MonitoringApi>();
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final history = await _api.getHistory(limit: 1000);
      setState(() => _history = history);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, int> _countActionsByType() {
    final counts = <String, int>{};
    for (final item in _history) {
      final action = (item as Map<String, dynamic>)['action'] ?? 'unknown';
      counts[action] = (counts[action] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: const Color(0xFF001a4d),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Summary Cards
                  _buildSummaryCard(
                    title: 'Total Events',
                    value: '${_history.length}',
                    icon: Icons.event,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryCard(
                    title: 'Last 24h',
                    value: 'Active',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),

                  // Action Distribution
                  const Text(
                    'Activity Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActionChart(),

                  const SizedBox(height: 24),

                  // Recent Events
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._buildRecentEventsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChart() {
    final counts = _countActionsByType();
    if (counts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No activity data',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Bar chart
            ...sorted.map((entry) {
              final percentage = (entry.value / total * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value / total,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getColorForAction(entry.key),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecentEventsList() {
    if (_history.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No events',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ),
      ];
    }

    return _history.take(10).map((item) {
      final event = item as Map<String, dynamic>;
      final action = event['action'] ?? 'unknown';
      final trackId = event['track_id'] ?? 'N/A';

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: Icon(
              _getIconForAction(action),
              color: _getColorForAction(action),
            ),
            title: Text(action),
            subtitle: Text('Track: $trackId'),
          ),
        ),
      );
    }).toList();
  }

  Color _getColorForAction(String action) {
    switch (action.toLowerCase()) {
      case 'walking':
        return Colors.blue;
      case 'standing':
        return Colors.green;
      case 'sitting':
        return Colors.orange;
      case 'lying':
        return Colors.red;
      case 'fall':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForAction(String action) {
    switch (action.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk;
      case 'standing':
        return Icons.accessibility;
      case 'sitting':
        return Icons.chair;
      case 'lying':
        return Icons.bed;
      case 'fall':
        return Icons.warning;
      default:
        return Icons.camera;
    }
  }
}
