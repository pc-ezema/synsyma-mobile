import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _banner;
  bool _loading = false;
  String? _lastName; // shown as "Welcome Back, <name>" for returning people

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await ref.read(storageProvider).read(key: lastFirstNameKey);
    if (mounted && name != null && name.isNotEmpty) setState(() => _lastName = name);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    setState(() {
      _banner = null;
      _emailError = email.contains('@') ? null : 'Enter a valid email address.';
      _passwordError = password.isEmpty ? 'Enter your password.' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(email, password);
      // The router moves on to /home once the state changes.
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'email_not_verified') {
        final resend = (e.data['resend_in'] as num?)?.toInt() ?? 60;
        context.push('/verify-email?email=${Uri.encodeQueryComponent(email)}&resend=$resend');
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
      showBack: false,
      topPadding: 48,
      children: [
        Row(
          children: [
            _Avatar(name: _lastName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: _lastName == null ? 20 : 14,
                      fontWeight: _lastName == null ? FontWeight.w700 : FontWeight.w400,
                      color: _lastName == null ? Colors.black : const Color(0xFF4A4E5A),
                    ),
                  ),
                  if (_lastName != null)
                    Text(
                      _lastName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        if (_banner != null) ErrorBanner(_banner!),
        AppTextField(
          label: 'Email',
          hint: 'Enter your email address',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          errorText: _emailError,
        ),
        const SizedBox(height: 20),
        AppTextField(
          label: 'Password',
          hint: 'Enter your password',
          controller: _password,
          obscure: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          errorText: _passwordError,
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/forgot-password'),
            child: const Text(
              'Reset Password',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.blueDark),
            ),
          ),
        ),
        const SizedBox(height: 72),
        PrimaryButton(label: 'Login', loading: _loading, onPressed: _submit),
        const SizedBox(height: 6),
        TextLinkRow(
          prefix: 'Don’t have an account? ',
          action: 'Sign up',
          onTap: () => context.push('/register'),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final hasName = name != null && name!.isNotEmpty;
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasName ? AppColors.blueGradient : null,
        color: hasName ? null : AppColors.fieldBorder,
      ),
      child: hasName
          ? Text(
              name![0].toUpperCase(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            )
          : const Icon(Icons.person_outline, color: Color(0xFF6B7280)),
    );
  }
}
