import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/monitoring_api.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = GetIt.instance<MonitoringApi>();
  bool _loading = true;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.getReports();
      setState(() => _items = items);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final it = _items[index] as Map<String, dynamic>;
                  return ListTile(
                    title: Text(it['title'] ?? 'Report'),
                    subtitle: Text('Window: ${it['window_ms']} ms'),
                    trailing: Text('${it['generated_at_ms'] ?? ''}'),
                  );
                },
              ),
            ),
    );
  }
}
