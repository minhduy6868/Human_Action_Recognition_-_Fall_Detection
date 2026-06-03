import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/l10n/app_localizations.dart';
import '../services/api_exception.dart';
import '../services/vip_upgrade_launcher.dart';
import '../state/auth/auth_cubit.dart';

class PlanLimitDialog {
  PlanLimitDialog._();

  static bool isFreePlan(BuildContext context) {
    final plan = context.read<AuthCubit>().state.user?.plan ?? 'free';
    return plan.toLowerCase() != 'vip';
  }

  static Future<void> showVipRequiredForSources(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.workspace_premium_outlined, color: Color(0xFFF1A53A)),
        title: Text(loc.translate('vip_source_limit_title')),
        content: Text(loc.translate('vip_source_limit_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.translate('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              VipUpgradeLauncher.openTelegramUpgrade(context);
            },
            child: Text(loc.translate('upgrade_vip')),
          ),
        ],
      ),
    );
  }

  static Future<void> showActiveSourceLimit(BuildContext context, {String? message}) {
    final loc = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.videocam_off_outlined),
        title: Text(loc.translate('active_source_limit_title')),
        content: Text(message ?? loc.translate('active_source_limit_body')),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.translate('close')),
          ),
        ],
      ),
    );
  }

  static Future<bool> handleError(BuildContext context, Object error) async {
    if (error is! ApiException) {
      return false;
    }
    if (error.isActiveSourceLimit) {
      await showActiveSourceLimit(context, message: error.message);
      return true;
    }
    if (!error.isPlanLimit) {
      return false;
    }
    await showVipRequiredForSources(context);
    return true;
  }
}
