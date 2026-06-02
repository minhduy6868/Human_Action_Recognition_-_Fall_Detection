import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared_customization/localization/app_localizations.dart';
import '../state/auth/auth_cubit.dart';

class VipUpgradeLauncher {
  VipUpgradeLauncher._();

  static const telegramUsername = 'Codebox88';

  static Uri buildTelegramUri({String? email, String? name}) {
    final buffer = StringBuffer(
      'Xin chao Codebox88, toi muon nang cap goi VIP cho Video AI Detect.',
    );
    if (email != null && email.isNotEmpty) {
      buffer.write('\nEmail: $email');
    }
    if (name != null && name.isNotEmpty) {
      buffer.write('\nTen: $name');
    }
    return Uri.parse('https://t.me/$telegramUsername').replace(
      queryParameters: {'text': buffer.toString()},
    );
  }

  static Future<void> openTelegramUpgrade(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final user = context.read<AuthCubit>().state.user;
    final uri = buildTelegramUri(email: user?.email, name: user?.name);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('telegram_open_failed'))),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.translate('telegram_open_failed'))),
      );
    }
  }
}
