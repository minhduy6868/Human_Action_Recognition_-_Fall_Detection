import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/app_config.dart';
import '../core/auth/auth_styles.dart';
import '../state/app_settings_cubit.dart';
import '../state/auth/auth_cubit.dart';
import '../state/auth/auth_state.dart';
import '../core/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppConfig.googleServerClientId.isEmpty
        ? null
        : AppConfig.googleServerClientId,
  );
  bool _isObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      return;
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (!mounted) {
      return;
    }

    if (idToken == null || idToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate('google_login_failed_missing_token'),
          ),
        ),
      );
      return;
    }

    await context.read<AuthCubit>().loginWithGoogle(idToken);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentLang = context.select((AppSettingsCubit c) => c.state.locale.languageCode);

    return Scaffold(
      body: Stack(
        children: [
          _Backdrop(theme: theme),
          SafeArea(
            child: SizedBox.expand(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: AuthStyles.maxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Language switch
                              Align(
                                alignment: Alignment.topRight,
                                child: DropdownButton<String>(
                                  value: currentLang,
                                  underline: const SizedBox.shrink(),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'en',
                                      child: Text(AppLocalizations.of(context).translate('english')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'vi',
                                      child: Text(AppLocalizations.of(context).translate('vietnamese')),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == null) return;
                                    context.read<AppSettingsCubit>().setLanguage(val);
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(context)
                                    .translate('secure_access'),
                                style: AuthStyles.subtitle(context),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              Card(
                                child: Padding(
                                  padding: AuthStyles.cardPadding,
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)
                                              .translate('sign_in'),
                                          style: AuthStyles.title(context),
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          decoration: InputDecoration(
                                            labelText:
                                                AppLocalizations.of(context)
                                                    .translate('email'),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return AppLocalizations.of(
                                                      context)
                                                  .translate('email_required');
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 14),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _isObscured,
                                          decoration: InputDecoration(
                                            labelText:
                                                AppLocalizations.of(context)
                                                    .translate('password'),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _isObscured
                                                    ? Icons
                                                        .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _isObscured = !_isObscured;
                                                });
                                              },
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return AppLocalizations.of(
                                                      context)
                                                  .translate(
                                                      'password_required');
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        BlocBuilder<AuthCubit, AuthState>(
                                          builder: (context, state) {
                                            final isLoading = state.status ==
                                                AuthStatus.loading;
                                            final error = state.error;

                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                if (error != null)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.error
                                                          .withValues(
                                                              alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color: colorScheme.error
                                                            .withValues(
                                                                alpha: 0.4),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      error,
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color:
                                                            colorScheme.error,
                                                      ),
                                                    ),
                                                  ),
                                                if (error != null)
                                                  const SizedBox(height: 12),
                                                FilledButton(
                                                  onPressed: isLoading
                                                      ? null
                                                      : () {
                                                          if (_formKey
                                                                  .currentState
                                                                  ?.validate() !=
                                                              true) {
                                                            return;
                                                          }
                                                          context
                                                              .read<AuthCubit>()
                                                              .login(
                                                                _emailController
                                                                    .text
                                                                    .trim(),
                                                                _passwordController
                                                                    .text
                                                                    .trim(),
                                                              );
                                                        },
                                                  child: isLoading
                                                      ? const SizedBox(
                                                          height: 18,
                                                          width: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      : Text(AppLocalizations
                                                              .of(context)
                                                          .translate(
                                                              'continue_btn')),
                                                ),
                                                const SizedBox(height: 12),
                                                OutlinedButton.icon(
                                                  onPressed: isLoading
                                                      ? null
                                                      : _signInWithGoogle,
                                                  icon: const Icon(
                                                      Icons.g_mobiledata),
                                                  label: Text(
                                                    AppLocalizations.of(context)
                                                        .translate(
                                                            'continue_with_google'),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/register'),
                          child: Text(AppLocalizations.of(context)
                              .translate('create_account')),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/forgot'),
                          child: Text(AppLocalizations.of(context)
                              .translate('forgot_password')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
              ? [const Color(0xFF0A121B), const Color(0xFF122232)]
              : [const Color(0xFFEAF1F7), const Color(0xFFF7FAFD)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -20,
            child: _GlowBlob(
              color: const Color(0xFFF36B4E).withValues(alpha: 0.18),
              size: 180,
            ),
          ),
          Positioned(
            bottom: -80,
            left: -10,
            child: _GlowBlob(
              color: const Color(0xFF1FBF9B).withValues(alpha: 0.18),
              size: 200,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}
