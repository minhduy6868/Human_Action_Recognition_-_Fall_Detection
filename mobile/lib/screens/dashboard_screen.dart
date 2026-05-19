import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../core/app_config.dart';
import '../services/monitoring_api.dart';
import '../services/sources_api.dart';
import '../models/source.dart';
import '../state/fall_detection/realtime_cubit.dart';
import '../state/fall_detection/realtime_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _monitoringApi = GetIt.instance<MonitoringApi>();
  final _sourcesApi = GetIt.instance<SourcesApi>();

  List<dynamic> _events = [];
  List<Source> _sources = [];
  bool _loading = true;
  int _selectedSourceIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RealtimeCubit>().connect();
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sources = await _sourcesApi.listSources();
      final events = await _monitoringApi.getHistory(limit: 50);
      setState(() {
        _sources = sources;
        _events = events;
        if (_sources.isNotEmpty && _selectedSourceIndex >= _sources.length) {
          _selectedSourceIndex = 0;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF001a4d),
        title: const Text(
          'System Active',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'All ${_sources.length} cameras',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // Live Feed Section
                  if (_sources.isNotEmpty) ...[
                    _buildLiveFeedCard(),
                    const SizedBox(height: 16),
                  ],

                  // Source Selector
                  if (_sources.length > 1) _buildSourceSelector(),

                  const SizedBox(height: 16),

                  // Timeline Section
                  _buildTimelineSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildLiveFeedCard() {
    final source = _sources[_selectedSourceIndex];
    final name = source.name.isEmpty ? 'Camera' : source.name;
    final streamUrl = source.sourceUrl.isNotEmpty ? source.sourceUrl : AppConfig.mjpegUrl;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          // Background placeholder or image
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: BlocBuilder<RealtimeCubit, RealtimeState>(
              builder: (context, state) {
                if (streamUrl.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam_off,
                          color: Colors.white54,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Not connected',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                return Mjpeg(
                  isLive: true,
                  stream: streamUrl,
                  error: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_off,
                              color: Colors.white54, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Stream unavailable\n$streamUrl',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Status Badges
          Positioned(
            top: 12,
            left: 12,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record,
                          color: Colors.white, size: 8),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flash_on, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'AI ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Camera name at bottom
          Positioned(
            bottom: 12,
            left: 12,
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_sources.length, (index) {
          final source = _sources[index];
          final name = source.name.isEmpty ? 'Camera $index' : source.name;
          final isSelected = index == _selectedSourceIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(name),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedSourceIndex = index);
                }
              },
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Safety Timeline',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No events yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              final event = _events[index] as Map<String, dynamic>;
              final action = event['action'] ?? 'Unknown';
              final timestamp = event['timestamp_ms'] ?? 0;
              final dt = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
              final timeStr = DateFormat('HH:mm a').format(dt);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconForAction(action),
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(action),
                    subtitle:
                        Text('${event['track_id'] ?? 'Track'} • $timeStr'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              );
            },
          ),
      ],
    );
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
