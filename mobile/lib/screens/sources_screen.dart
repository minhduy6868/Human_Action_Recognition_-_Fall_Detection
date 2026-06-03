import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/l10n/app_localizations.dart';
import '../models/source.dart';
import '../services/sources_api.dart';
import '../utils/plan_limit_dialog.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('failed_to_load_sources')}: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _activate(Source s) async {
    setState(() => _loading = true);
    try {
      await _api.activateSource(s.id);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('activated')} ${s.name}')));
    } catch (e) {
      if (!mounted) return;
      if (await PlanLimitDialog.handleError(context, e)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).translate('activate_failed')}: $e',
          ),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _stop(Source s) async {
    setState(() => _loading = true);
    try {
      await _api.stopStream(s.id);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('stopped')} ${s.name}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('stop_failed')}: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(Source s) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).translate('delete_source')),
            content: Text('"${s.name.isEmpty ? s.sourceUrl : s.name}"'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context).translate('cancel'))),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context).translate('delete'))),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await _api.deleteSource(s.id);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('deleted')} ${s.name}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).translate('delete_failed')}: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    if (PlanLimitDialog.isFreePlan(context) && _items.length >= 1) {
      await PlanLimitDialog.showVipRequiredForSources(context);
      return;
    }
    await _showSourceSheet();
  }

  Future<void> _showEditDialog(Source source) async {
    await _showSourceSheet(existing: source);
  }

  Future<void> _showSourceSheet({Source? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.sourceUrl ?? '');
    String type = existing?.sourceType.isNotEmpty == true ? existing!.sourceType : 'rtsp';
    bool isActive = existing?.isActive ?? false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        existing == null ? AppLocalizations.of(context).translate('create_source') : AppLocalizations.of(context).translate('edit_source'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(labelText: AppLocalizations.of(context).translate('name')),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: type,
                        items: [
                          DropdownMenuItem(value: 'rtsp', child: Text(AppLocalizations.of(context).translate('rtsp'))),
                          DropdownMenuItem(value: 'file', child: Text(AppLocalizations.of(context).translate('file'))),
                          DropdownMenuItem(value: 'webcam', child: Text(AppLocalizations.of(context).translate('webcam_index'))),
                          DropdownMenuItem(value: 'http_mjpeg', child: Text(AppLocalizations.of(context).translate('http_mjpeg'))),
                          DropdownMenuItem(value: 'mjpeg', child: Text(AppLocalizations.of(context).translate('mjpeg'))),
                        ],
                        onChanged: (value) => setModalState(() => type = value ?? type),
                        decoration: InputDecoration(labelText: AppLocalizations.of(context).translate('source_type')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlCtrl,
                        decoration: InputDecoration(labelText: AppLocalizations.of(context).translate('url_index_path')),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        onChanged: (value) => setModalState(() => isActive = value),
                        title: Text(AppLocalizations.of(context).translate('activate_after_save')),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final url = urlCtrl.text.trim();
                          if (url.isEmpty) return;

                          Navigator.of(context).pop();
                          setState(() => _loading = true);
                          try {
                            if (existing == null) {
                              await _api.createSource(name, type, url, isActive: isActive);
                            } else {
                              await _api.patchSource(existing.id, {
                                'name': name,
                                'source_type': type,
                                'source_url': url,
                                'is_active': isActive,
                              });
                            }
                            await _load();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(existing == null ? AppLocalizations.of(context).translate('source_created') : AppLocalizations.of(context).translate('source_updated'))),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            final handled = await PlanLimitDialog.handleError(context, e);
                            if (!handled) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${AppLocalizations.of(context).translate('save_failed')}: $e',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                        child: Text(existing == null ? AppLocalizations.of(context).translate('create_source') : AppLocalizations.of(context).translate('save_changes')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('manage_sources_title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: _showCreateDialog, icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: Stack(
        children: [
          _SourcesBackdrop(theme: theme),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _SourceHeroCard(total: _items.length, active: _items.where((source) => source.isActive).length),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 42),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_items.isEmpty)
                    _EmptyState(onCreate: _showCreateDialog)
                  else
                    ..._items.map((source) {
                      final label = source.name.isEmpty ? source.sourceUrl : source.name;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.videocam_rounded, color: Color(0xFF0B2E4C)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text('${source.sourceType} • ${source.sourceUrl}', style: theme.textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                    _StatusChip(active: source.isActive),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showEditDialog(source),
                                      icon: const Icon(Icons.edit_rounded),
                                      label: Text(AppLocalizations.of(context).translate('edit')),
                                    ),
                                    if (source.isActive)
                                      FilledButton.icon(
                                        onPressed: () => _stop(source),
                                        icon: const Icon(Icons.stop_circle_rounded),
                                        label: Text(AppLocalizations.of(context).translate('stop')),
                                      )
                                    else
                                      FilledButton.icon(
                                        onPressed: () => _activate(source),
                                        icon: const Icon(Icons.play_circle_rounded),
                                        label: Text(AppLocalizations.of(context).translate('activate')),
                                      ),
                                    TextButton.icon(
                                      onPressed: () => _delete(source),
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      label: Text(AppLocalizations.of(context).translate('delete')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _SourceHeroCard extends StatelessWidget {
  const _SourceHeroCard({required this.total, required this.active});

  final int total;
  final int active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B2E4C), Color(0xFF124B6C)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).translate('camera_sources'), style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(AppLocalizations.of(context).translate('camera_sources_subtitle'), style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.88))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SourcePill(label: '$total total', color: Colors.white),
                      _SourcePill(label: '$active active', color: const Color(0xFF1FBF9B)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isLight = color == Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isLight ? const Color(0xFF0B2E4C) : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final color = active ? const Color(0xFF1FBF9B) : const Color(0xFFF1A53A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? loc.translate('active') : loc.translate('idle'),
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.video_library_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context).translate('no_sources_configured'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(AppLocalizations.of(context).translate('create_first_camera_source'), style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(AppLocalizations.of(context).translate('create_source')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcesBackdrop extends StatelessWidget {
  const _SourcesBackdrop({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0B1218), const Color(0xFF111E2A)]
              : [const Color(0xFFF2F6FB), const Color(0xFFF8FBFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF36B4E).withOpacity(0.12),
                boxShadow: [BoxShadow(color: const Color(0xFFF36B4E).withOpacity(0.18), blurRadius: 90, spreadRadius: 12)],
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1FBF9B).withOpacity(0.12),
                boxShadow: [BoxShadow(color: const Color(0xFF1FBF9B).withOpacity(0.18), blurRadius: 90, spreadRadius: 12)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
