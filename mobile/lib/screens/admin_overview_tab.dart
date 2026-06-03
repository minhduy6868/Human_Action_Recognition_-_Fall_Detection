import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../models/user_profile.dart';
import '../services/admin_api.dart';
import '../core/l10n/app_localizations.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  final _adminApi = GetIt.instance<AdminApi>();
  AdminStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await _adminApi.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _stats;
    if (stats == null) {
      return Center(
        child: FilledButton(
          onPressed: _load,
          child: Text(loc.translate('retry')),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _StatGrid(
            items: [
              _StatItem(loc.translate('admin_stat_total'), stats.totalUsers, Icons.people),
              _StatItem(loc.translate('admin_stat_free'), stats.freeUsers, Icons.person_outline),
              _StatItem(loc.translate('admin_stat_vip'), stats.vipUsers, Icons.workspace_premium),
              _StatItem(loc.translate('admin_stat_sources'), stats.totalSources, Icons.videocam),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: items.map((item) => _StatCard(item: item)).toList(),
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, color: theme.colorScheme.primary),
            const Spacer(),
            Text(
              '${item.value}',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(item.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
