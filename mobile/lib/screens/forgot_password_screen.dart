import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/auth_api.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  AuthApi get _api => GetIt.instance<AuthApi>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final otp = await _api.requestOtp(_emailCtrl.text.trim(), purpose: 'reset');
      if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: _emailCtrl.text.trim(), otp: otp)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 20),
            FilledButton(onPressed: _loading ? null : _sendOtp, child: const Text('Send OTP')),
          ],
        ),
      ),
    );
  }
}
