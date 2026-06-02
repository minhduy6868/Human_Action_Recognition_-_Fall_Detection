import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../models/user_profile.dart';
import '../services/admin_api.dart';
import '../shared_customization/localization/app_localizations.dart';
import '../state/auth/auth_cubit.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _adminApi = GetIt.instance<AdminApi>();
  final _searchController = TextEditingController();

  List<UserProfile> _users = [];
  bool _loading = true;
  String? _error;
  String? _planFilter;
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _adminApi.listUsers(
        query: query,
        plan: _planFilter,
        role: _roleFilter,
      );
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _quickSetPlan(UserProfile user, String plan) async {
    final loc = AppLocalizations.of(context);
    try {
      final updated = await _adminApi.updateUser(user.id, plan: plan);
      setState(() {
        _users = _users.map((u) => u.id == updated.id ? updated : u).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('user_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteUser(UserProfile user) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('delete_user')),
        content: Text(user.email),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.translate('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.translate('delete'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _adminApi.deleteUser(user.id);
      setState(() => _users = _users.where((u) => u.id != user.id).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('user_deleted'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _showEditSheet(UserProfile user) async {
    final loc = AppLocalizations.of(context);
    final nameController = TextEditingController(text: user.name);
    var role = user.role;
    var plan = user.plan;
    var saving = false;
    List<AdminUserSource> sources = [];
    var loadingSources = true;
    var sourcesRequested = false;

    Future<void> loadSources(StateSetter setSheetState) async {
      setSheetState(() => loadingSources = true);
      try {
        sources = await _adminApi.listUserSources(user.id);
      } catch (_) {
        sources = [];
      }
      setSheetState(() => loadingSources = false);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!sourcesRequested) {
              sourcesRequested = true;
              loadSources(setSheetState);
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: loc.translate('name'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(loc.translate('role'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'user', label: Text(loc.translate('role_user'))),
                        ButtonSegment(value: 'admin', label: Text(loc.translate('role_admin'))),
                      ],
                      selected: {role},
                      onSelectionChanged: saving
                          ? null
                          : (value) => setSheetState(() => role = value.first),
                    ),
                    const SizedBox(height: 16),
                    Text(loc.translate('plan'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'free', label: Text('Free')),
                        ButtonSegment(value: 'vip', label: Text('VIP')),
                      ],
                      selected: {plan},
                      onSelectionChanged: saving
                          ? null
                          : (value) => setSheetState(() => plan = value.first),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${loc.translate('admin_user_sources')} (${user.sourceCount})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (loadingSources)
                      const LinearProgressIndicator()
                    else if (sources.isEmpty)
                      Text(loc.translate('no_sources_configured'))
                    else
                      ...sources.take(5).map(
                            (source) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(source.name.isEmpty ? source.sourceType : source.name),
                              subtitle: Text(
                                source.sourceUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                source.isActive ? Icons.play_circle : Icons.pause_circle_outline,
                                color: source.isActive ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: saving ? null : () => _deleteUser(user),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(loc.translate('delete')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    setSheetState(() => saving = true);
                                    try {
                                      final updated = await _adminApi.updateUser(
                                        user.id,
                                        name: nameController.text.trim(),
                                        role: role,
                                        plan: plan,
                                      );
                                      if (!context.mounted) return;
                                      Navigator.of(context).pop();
                                      setState(() {
                                        _users = _users
                                            .map((u) => u.id == updated.id ? updated : u)
                                            .toList();
                                      });
                                      final currentUser = context.read<AuthCubit>().state.user;
                                      if (currentUser?.id == updated.id) {
                                        await context.read<AuthCubit>().refreshProfile();
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(content: Text(loc.translate('user_updated'))),
                                        );
                                      }
                                    } catch (e) {
                                      setSheetState(() => saving = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(loc.translate('save_changes')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    nameController.dispose();
  }

  Widget _buildFilters(AppLocalizations loc) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(loc.translate('admin_filter_all')),
            selected: _planFilter == null && _roleFilter == null,
            onSelected: (_) {
              setState(() {
                _planFilter = null;
                _roleFilter = null;
              });
              _loadUsers(query: _searchController.text);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Free'),
            selected: _planFilter == 'free',
            onSelected: (_) {
              setState(() {
                _planFilter = 'free';
                _roleFilter = null;
              });
              _loadUsers(query: _searchController.text);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('VIP'),
            selected: _planFilter == 'vip',
            onSelected: (_) {
              setState(() {
                _planFilter = 'vip';
                _roleFilter = null;
              });
              _loadUsers(query: _searchController.text);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(loc.translate('role_admin')),
            selected: _roleFilter == 'admin',
            onSelected: (_) {
              setState(() {
                _roleFilter = 'admin';
                _planFilter = null;
              });
              _loadUsers(query: _searchController.text);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: loc.translate('search_users'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () => _loadUsers(query: _searchController.text),
                icon: const Icon(Icons.search),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onSubmitted: (value) => _loadUsers(query: value),
          ),
        ),
        _buildFilters(loc),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _loadUsers(),
                            child: Text(loc.translate('retry')),
                          ),
                        ],
                      ),
                    )
                  : _users.isEmpty
                      ? Center(child: Text(loc.translate('no_users_found')))
                      : RefreshIndicator(
                          onRefresh: () => _loadUsers(query: _searchController.text),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  title: Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    user.name.isEmpty
                                        ? '${user.sourceCount} ${loc.translate('admin_sources_short')}'
                                        : '${user.name} · ${user.sourceCount} src',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showEditSheet(user);
                                      } else if (value == 'vip') {
                                        _quickSetPlan(user, 'vip');
                                      } else if (value == 'free') {
                                        _quickSetPlan(user, 'free');
                                      } else if (value == 'delete') {
                                        _deleteUser(user);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(value: 'edit', child: Text(loc.translate('edit'))),
                                      PopupMenuItem(value: 'vip', child: Text(loc.translate('admin_make_vip'))),
                                      PopupMenuItem(value: 'free', child: Text(loc.translate('admin_make_free'))),
                                      PopupMenuItem(value: 'delete', child: Text(loc.translate('delete'))),
                                    ],
                                    child: Wrap(
                                      spacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        _Badge(label: user.plan.toUpperCase(), color: user.plan == 'vip' ? const Color(0xFF1FBF9B) : null),
                                        const Icon(Icons.more_vert),
                                      ],
                                    ),
                                  ),
                                  onTap: () => _showEditSheet(user),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('admin_users_title')),
        actions: [
          IconButton(
            onPressed: () => _loadUsers(query: _searchController.text),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: content,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: resolved,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
