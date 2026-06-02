import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import 'package:get_it/get_it.dart';

import '../state/auth/auth_cubit.dart';
import '../state/app_settings_cubit.dart';
import '../services/push_notification_service.dart';
import '../services/vip_upgrade_launcher.dart';
import '../shared_customization/localization/app_localizations.dart';
import './dashboard_screen.dart';
import './analytics_screen.dart';
import './ai_chat_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(GetIt.instance<PushNotificationService>().initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: loc.translate('home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: loc.translate('analytics'),
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: loc.translate('ai'),
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: loc.translate('settings'),
          ),
        ],
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(isActive: _selectedIndex == 0),
          const AnalyticsScreen(),
          const AiChatScreen(),
          const _SettingsPanel(),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final loc = AppLocalizations.of(context);
    final authState = context.watch<AuthCubit>().state;
    final settingsState = context.watch<AppSettingsCubit>().state;
    final user = authState.user;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(loc.translate('settings_management')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _Backdrop(theme: theme),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _UserHeroCard(user: user),
                if (user?.plan != 'vip') ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF1FBF9B)),
                      title: Text(loc.translate('upgrade_vip_short')),
                      subtitle: Text(loc.translate('upgrade_vip_via')),
                      trailing: const Icon(Icons.telegram, color: Color(0xFF229ED9)),
                      onTap: () => VipUpgradeLauncher.openTelegramUpgrade(context),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.translate('appearance'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(loc.translate('darkMode')),
                          subtitle: Text(loc.translate('switch_between_light_and_dark')),
                          value: settingsState.themeMode == ThemeMode.dark,
                          onChanged: (_) => context.read<AppSettingsCubit>().toggleDarkMode(),
                        ),
                        const Divider(height: 24),
                        Text(
                          loc.translate('language'),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ChoiceChip(
                              label: Text(loc.translate('english')),
                              selected: settingsState.locale.languageCode == 'en',
                              onSelected: (_) => context.read<AppSettingsCubit>().setLanguage('en'),
                            ),
                            ChoiceChip(
                              label: Text(loc.translate('vietnamese')),
                              selected: settingsState.locale.languageCode == 'vi',
                              onSelected: (_) => context.read<AppSettingsCubit>().setLanguage('vi'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingsSection(
                  loc.translate('monitoring'),
                  [
                    _buildSettingsTile(
                      loc.translate('manage_sources'),
                      loc.translate('add_edit_remove_cameras'),
                      Icons.videocam,
                      () => Navigator.of(context).pushNamed('/sources'),
                      theme,
                    ),
                    _buildSettingsTile(
                      loc.translate('history'),
                      loc.translate('view_detection_history'),
                      Icons.history,
                      () => Navigator.of(context).pushNamed('/history'),
                      theme,
                    ),
                    _buildSettingsTile(
                      loc.translate('summary'),
                      loc.translate('system_logs'),
                      Icons.description,
                      () => Navigator.of(context).pushNamed('/logs'),
                      theme,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSettingsSection(
                  loc.translate('reports'),
                  [
                    _buildSettingsTile(
                      loc.translate('reports'),
                      loc.translate('view_activity_reports'),
                      Icons.assessment,
                      () => Navigator.of(context).pushNamed('/reports'),
                      theme,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: FilledButton.icon(
                    onPressed: () => context.read<AuthCubit>().logout(),
                    icon: const Icon(Icons.logout),
                    label: Text(loc.translate('logout')),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  static Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    return ListTile(
      leading: Icon(icon, color: colorScheme.secondary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _UserHeroCard extends StatelessWidget {
  const _UserHeroCard({required this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user?.name?.toString().isNotEmpty == true ? user.name.toString() : 'Guest';
    final email = user?.email?.toString() ?? 'No email';
    final plan = user?.plan?.toString() ?? 'free';

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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.88))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _UserPill(label: plan.toUpperCase(), color: const Color(0xFF1FBF9B)),
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

class _UserPill extends StatelessWidget {
  const _UserPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final light = color == Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: light ? Colors.white : color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: light ? const Color(0xFF0B2E4C) : color, fontWeight: FontWeight.w700)),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.theme});

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
    );
  }
}
