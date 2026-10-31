import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_error.dart';
import '../../core/widgets/auth_widgets.dart';
import 'auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _emailError;
  String? _banner;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _next(String email, int resend) {
    context.push('/reset-code?email=${Uri.encodeQueryComponent(email)}&resend=$resend');
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    setState(() {
      _banner = null;
      _emailError = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
          ? null
          : 'Enter a valid email address.';
    });
    if (_emailError != null) return;

    setState(() => _loading = true);
    try {
      final data = await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      _next(email, (data['resend_in'] as num?)?.toInt() ?? 60);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.retryAfter != null) {
        // A code was sent a moment ago, so carry on to the code screen.
        _next(email, e.retryAfter!);
      } else {
        setState(() => _banner = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Registered Email',
      subtitle: 'Enter the email associated with your account and we would send you an email to reset your password.',
      children: [
        if (_banner != null) ErrorBanner(_banner!),
        AppTextField(
          label: 'Email',
          hint: 'Enter your email address',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          errorText: _emailError,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Continue', loading: _loading, onPressed: _submit),
      ],
    );
  }
}
