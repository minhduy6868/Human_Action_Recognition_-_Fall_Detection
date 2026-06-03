import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/l10n/app_localizations.dart';
import '../state/auth/auth_cubit.dart';
import 'admin_overview_tab.dart';
import 'admin_users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = context.watch<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('admin_panel')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: loc.translate('admin_tab_overview')),
            Tab(text: loc.translate('admin_tab_users')),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  user.email.split('@').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          IconButton(
            tooltip: loc.translate('logout'),
            onPressed: () => context.read<AuthCubit>().logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AdminOverviewTab(),
          AdminUsersScreen(embedded: true),
        ],
      ),
    );
  }
}
