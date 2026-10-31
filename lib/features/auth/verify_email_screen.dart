import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/auth_config.dart';
import '../../core/network/api_error.dart';
import '../../core/widgets/auth_widgets.dart';
import 'auth_repository.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, required this.resendIn});

  final String email;
  final int resendIn;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  String? _banner;
  bool _hasError = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Typing again clears the red error state.
    _code.addListener(() {
      if (_hasError && _code.text.isNotEmpty) {
        setState(() {
          _hasError = false;
          _banner = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_code.text.length != kOtpLength) {
      setState(() => _banner = 'Enter the $kOtpLength-digit code from your email.');
      return;
    }
    setState(() {
      _loading = true;
      _banner = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyEmail(widget.email, _code.text);
      if (mounted) context.go('/verified');
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _banner = e.fields['otp'] ?? e.message;
        _hasError = true;
      });
      _code.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify Your Email',
      subtitle: 'A code has been sent to your registered email',
      children: [
        if (_banner != null) ErrorBanner(_banner!),
        OtpField(controller: _code, hasError: _hasError, onCompleted: _submit),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Verify', loading: _loading, onPressed: _submit),
        const SizedBox(height: 6),
        ResendRow(
          initialSeconds: widget.resendIn,
          onResend: () => ref.read(authRepositoryProvider).resendOtp(widget.email, 'email_verification'),
        ),
      ],
    );
  }
}
