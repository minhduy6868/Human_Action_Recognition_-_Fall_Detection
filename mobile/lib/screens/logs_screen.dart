import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/monitoring_api.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
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
      final items = await _api.getLogs(limit: 200);
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
      appBar: AppBar(title: const Text('Logs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final it = _items[index] as Map<String, dynamic>;
                  return ListTile(
                    title: Text(it['action'] ?? 'log'),
                    subtitle: Text(it['message']?.toString() ?? ''),
                    trailing: Text('${it['timestamp_ms'] ?? ''}'),
                  );
                },
              ),
            ),
    );
  }
}
