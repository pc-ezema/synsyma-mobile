import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_error.dart';
import '../../core/widgets/auth_widgets.dart';
import 'auth_repository.dart';

class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key, required this.email, required this.resetToken});

  final String email;
  final String resetToken;

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
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
      await ref.read(authRepositoryProvider).resetPassword(
            email: widget.email,
            resetToken: widget.resetToken,
            password: p,
          );
      if (mounted) context.go('/password-updated');
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'reset_expired') {
        // The reset window ran out: start again.
        context.go('/forgot-password');
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
        if (_banner != null) ErrorBanner(_banner!),
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
