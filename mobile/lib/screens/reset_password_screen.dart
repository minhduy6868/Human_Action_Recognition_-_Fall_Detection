import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/auth_api.dart';
import '../shared_customization/auth/auth_styles.dart';
import '../shared_customization/localization/app_localizations.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordHidden = true;
  bool _confirmHidden = true;
  bool _loading = false;

  AuthApi get _api => GetIt.instance<AuthApi>();

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _loading = true);
    try {
      await _api.resetPassword(
        widget.email,
        _otpCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)
                .translate('password_reset_success'))),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('reset_password_title'))),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.12),
                    colorScheme.surface,
                    colorScheme.secondary.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            SingleChildScrollView(
              padding: AuthStyles.pagePadding,
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AuthStyles.maxWidth),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: AuthStyles.cardPadding,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.translate('reset_password_title'),
                              style: AuthStyles.title(context),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.email,
                              style: AuthStyles.subtitle(context),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.translate('otp_code'),
                                prefixIcon: const Icon(Icons.pin_outlined),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? l10n.translate('otp_required')
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _passwordHidden,
                              decoration: InputDecoration(
                                labelText: l10n.translate('new_password'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() =>
                                        _passwordHidden = !_passwordHidden);
                                  },
                                  icon: Icon(
                                    _passwordHidden
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().length < 6
                                  ? l10n.translate('password_min_chars')
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _confirmHidden,
                              decoration: InputDecoration(
                                labelText:
                                    l10n.translate('confirm_new_password'),
                                prefixIcon:
                                    const Icon(Icons.lock_reset_outlined),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(
                                        () => _confirmHidden = !_confirmHidden);
                                  },
                                  icon: Icon(
                                    _confirmHidden
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => v != _passwordCtrl.text
                                  ? l10n.translate('passwords_do_not_match')
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(l10n.translate('set_password')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
