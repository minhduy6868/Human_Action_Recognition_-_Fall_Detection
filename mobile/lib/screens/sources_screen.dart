import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/sources_api.dart';
import '../models/source.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final _api = GetIt.instance<SourcesApi>();
  bool _loading = true;
  List<Source> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.listSources();
      setState(() {
        _items = items;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load sources: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _activate(Source s) async {
    setState(() => _loading = true);
    try {
      await _api.activateSource(s.id);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Activated ${s.name}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Activate failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _stop(Source s) async {
    setState(() => _loading = true);
    try {
      await _api.stopStream(s.id);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stopped ${s.name}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stop failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(Source s) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete source'),
            content: Text('Delete "${s.name.isEmpty ? s.sourceUrl : s.name}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await _api.deleteSource(s.id);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${s.name}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String type = 'rtsp';
    bool isActive = false;

    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'rtsp', child: Text('RTSP')),
                DropdownMenuItem(value: 'file', child: Text('File')),
                DropdownMenuItem(value: 'webcam', child: Text('Webcam (index)')),
                DropdownMenuItem(value: 'http_mjpeg', child: Text('HTTP MJPEG')),
                DropdownMenuItem(value: 'mjpeg', child: Text('MJPEG')),
              ],
              onChanged: (v) => type = v ?? type,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            const SizedBox(height: 8),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL / index / path')),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Activate now'),
              const SizedBox(width: 8),
              StatefulBuilder(builder: (context, setStateSB) {
                return Checkbox(value: isActive, onChanged: (v) => setStateSB(() => isActive = v ?? false));
              })
            ])
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (url.isEmpty) return;
              Navigator.of(context).pop(true);
              setState(() => _loading = true);
              try {
                await _api.createSource(name, type, url, isActive: isActive);
                await _load();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source created')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
              } finally {
                setState(() => _loading = false);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (res != true) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sources')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final s = _items[index];
                  return Card(
                    child: ListTile(
                      title: Text(s.name.isEmpty ? s.sourceUrl : s.name),
                      subtitle: Text('${s.sourceType} • ${s.sourceUrl}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.isActive) ...[
                            const Chip(label: Text('Active'), backgroundColor: Colors.green),
                            const SizedBox(width: 8),
                            TextButton(onPressed: () => _stop(s), child: const Text('Stop')),
                          ] else ...[
                            TextButton(onPressed: () => _activate(s), child: const Text('Activate')),
                          ],
                          IconButton(onPressed: () => _delete(s), icon: const Icon(Icons.delete_outline)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
