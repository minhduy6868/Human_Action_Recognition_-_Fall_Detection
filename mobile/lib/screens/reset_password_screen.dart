import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/auth_api.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email, this.otp});

  final String email;
  final String? otp;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  AuthApi get _api => GetIt.instance<AuthApi>();

  @override
  void initState() {
    super.initState();
    if (widget.otp != null && widget.otp!.isNotEmpty) {
      _otpCtrl.text = widget.otp!;
    }
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_otpCtrl.text.isEmpty || _passwordCtrl.text.length < 6 || _passwordCtrl.text != _confirmCtrl.text) return;
    setState(() => _loading = true);
    try {
      await _api.resetPassword(widget.email, _otpCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset successful')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Reset password for ${widget.email}'),
            const SizedBox(height: 12),
            TextField(controller: _otpCtrl, decoration: const InputDecoration(labelText: 'OTP')),
            const SizedBox(height: 12),
            TextField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: 'New password'), obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: _confirmCtrl, decoration: const InputDecoration(labelText: 'Confirm password'), obscureText: true),
            const SizedBox(height: 20),
            FilledButton(onPressed: _loading ? null : _submit, child: const Text('Set password')),
          ],
        ),
      ),
    );
  }
}
