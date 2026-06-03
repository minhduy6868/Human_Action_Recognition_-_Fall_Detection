import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/auth_api.dart';
import '../core/auth/auth_styles.dart';
import '../core/l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _passwordHidden = true;
  bool _confirmHidden = true;
  bool _loading = false;

  AuthApi get _api => GetIt.instance<AuthApi>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _loading = true);
    try {
      await _api.register(
        _emailCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)
                  .translate('account_created_success'))),
        );
      }
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
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.14),
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
                              l10n.translate('register'),
                              style: AuthStyles.title(context),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.translate('email_hint_register'),
                              style: AuthStyles.subtitle(context),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: InputDecoration(
                                labelText: l10n.translate('email'),
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? l10n.translate('email_required_short')
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: InputDecoration(
                                labelText: l10n.translate('full_name_optional'),
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _passwordHidden,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: l10n.translate('password'),
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
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                labelText: l10n.translate('confirm_password'),
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
                                  : Text(l10n.translate('create_account')),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: Text(l10n.translate('back_to_login')),
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
