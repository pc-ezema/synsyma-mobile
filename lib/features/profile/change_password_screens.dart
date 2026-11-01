import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/auth_config.dart';
import '../../core/network/api_error.dart';
import '../../core/widgets/auth_widgets.dart';
import '../../core/widgets/sub_page.dart';
import '../auth/reset_code_screen.dart' show maskEmail;
import 'profile_controller.dart';
import 'profile_repository.dart';

/// Step 1: confirm the account email and send a code.
class PasswordEmailScreen extends ConsumerStatefulWidget {
  const PasswordEmailScreen({super.key});

  @override
  ConsumerState<PasswordEmailScreen> createState() => _PasswordEmailScreenState();
}

class _PasswordEmailScreenState extends ConsumerState<PasswordEmailScreen> {
  late final TextEditingController _email;
  String? _emailError;
  String? _banner;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: ref.read(profileProvider).value?.email ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _next(String email, int resend) {
    context.push('/profile/password/code?email=${Uri.encodeQueryComponent(email)}&resend=$resend');
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
      final resend = await ref.read(profileRepositoryProvider).requestPasswordCode(email);
      if (mounted) _next(email, resend);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.retryAfter != null) {
        _next(email, e.retryAfter!); // a code was sent a moment ago
      } else if (e.fields['email'] != null) {
        setState(() => _emailError = e.fields['email']);
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
      subtitle: 'Enter the email associated with your account and we will send you a code to update your password.',
      children: [
        ErrorSlot(_banner),
        AppTextField(
          label: 'Email',
          hint: 'Enter your email address',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          errorText: _emailError,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Continue', loading: _loading, onPressed: _submit),
      ],
    );
  }
}

/// Step 2: enter the code from the email.
class PasswordCodeScreen extends ConsumerStatefulWidget {
  const PasswordCodeScreen({super.key, required this.email, required this.resendIn});
  final String email;
  final int resendIn;

  @override
  ConsumerState<PasswordCodeScreen> createState() => _PasswordCodeScreenState();
}

class _PasswordCodeScreenState extends ConsumerState<PasswordCodeScreen> {
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
      final token = await ref.read(profileRepositoryProvider).verifyPasswordCode(_code.text);
      if (!mounted) return;
      context.pushReplacement('/profile/password/new', extra: {'changeToken': token});
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
        ErrorSlot(_banner),
        OtpField(controller: _code, hasError: _hasError, onCompleted: _submit),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Continue', loading: _loading, onPressed: _submit),
        const SizedBox(height: 6),
        ResendRow(
          initialSeconds: widget.resendIn,
          onResend: () => ref.read(profileRepositoryProvider).requestPasswordCode(widget.email),
        ),
      ],
    );
  }
}

/// Step 3: choose the new password.
class PasswordNewScreen extends ConsumerStatefulWidget {
  const PasswordNewScreen({super.key, required this.changeToken});
  final String changeToken;

  @override
  ConsumerState<PasswordNewScreen> createState() => _PasswordNewScreenState();
}

class _PasswordNewScreenState extends ConsumerState<PasswordNewScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String> _errors = {};
  String? _banner;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p = _password.text;
    final errors = <String, String>{};
    if (p.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) {
      errors['password'] = 'Use at least 8 characters with letters and numbers.';
    }
    if (_confirm.text != p) errors['confirm'] = 'Passwords do not match.';

    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _loading = true);
    try {
      await ref.read(profileRepositoryProvider).changePassword(widget.changeToken, p);
      if (mounted) context.go('/profile/password/done');
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'change_expired') {
        showToast(context, 'That session expired. Please request a new code.');
        context.go('/profile/password');
        return;
      }
      setState(() {
        if (e.fields.isNotEmpty) {
          _errors = e.fields;
        } else {
          _banner = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create A New Password',
      subtitle: 'Your password must be different from the previously used password.',
      children: [
        ErrorSlot(_banner),
        AppTextField(
          label: 'New Password',
          hint: 'Enter your password',
          controller: _password,
          obscure: true,
          textInputAction: TextInputAction.next,
          errorText: _errors['password'],
        ),
        const SizedBox(height: 20),
        AppTextField(
          label: 'Confirm Password',
          hint: 'Enter your password',
          controller: _confirm,
          obscure: true,
          textInputAction: TextInputAction.done,
          errorText: _errors['confirm'],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 32),
        PrimaryButton(label: 'Continue', loading: _loading, onPressed: _submit),
      ],
    );
  }
}