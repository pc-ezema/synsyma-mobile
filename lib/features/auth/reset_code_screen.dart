import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/auth_config.dart';
import '../../core/network/api_error.dart';
import '../../core/widgets/auth_widgets.dart';
import 'auth_repository.dart';

String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at < 1) return email;
  final name = email.substring(0, at);
  final shown = name.length <= 4 ? name.substring(0, 1) : name.substring(0, 4);
  return '$shown***${email.substring(at)}';
}

class ResetCodeScreen extends ConsumerStatefulWidget {
  const ResetCodeScreen({super.key, required this.email, required this.resendIn});

  final String email;
  final int resendIn;

  @override
  ConsumerState<ResetCodeScreen> createState() => _ResetCodeScreenState();
}

class _ResetCodeScreenState extends ConsumerState<ResetCodeScreen> {
  final _code = TextEditingController();
  String? _banner;
  bool _hasError = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
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
      final token = await ref.read(authRepositoryProvider).verifyResetCode(widget.email, _code.text);
      if (!mounted) return;
      // The code is used up now, so replace this screen rather than stack on it.
      context.pushReplacement('/new-password', extra: {'email': widget.email, 'resetToken': token});
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
      title: 'Reset Code',
      subtitle: 'An Authentication code has been sent to ${maskEmail(widget.email)}',
      children: [
        if (_banner != null) ErrorBanner(_banner!),
        OtpField(controller: _code, hasError: _hasError, onCompleted: _submit),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Continue', loading: _loading, onPressed: _submit),
        const SizedBox(height: 6),
        ResendRow(
          initialSeconds: widget.resendIn,
          onResend: () => ref.read(authRepositoryProvider).resendOtp(widget.email, 'password_reset'),
        ),
      ],
    );
  }
}
