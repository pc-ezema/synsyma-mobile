import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_widgets.dart';
import 'auth_repository.dart';

const _siteBase = 'https://synsyma.com';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  Map<String, String> _errors = {};
  String? _banner;
  bool _terms = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _strongEnough(String p) =>
      p.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p);

  Future<void> _submit() async {
    final email = _email.text.trim();
    final errors = <String, String>{};

    if (_first.text.trim().isEmpty) errors['first_name'] = 'Enter your first name.';
    if (_last.text.trim().isEmpty) errors['last_name'] = 'Enter your last name.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors['email'] = 'Enter a valid email address.';
    }
    if (!_strongEnough(_password.text)) {
      errors['password'] = 'Use at least 8 characters with letters and numbers.';
    }
    if (_confirm.text != _password.text) errors['confirm'] = 'Passwords do not match.';
    if (!_terms) errors['terms'] = 'Please accept the Terms & Conditions and Privacy Policy.';

    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _loading = true);
    try {
      final data = await ref.read(authRepositoryProvider).register(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            email: email,
            password: _password.text,
            acceptedTerms: _terms,
          );
      if (!mounted) return;
      final resend = (data['resend_in'] as num?)?.toInt() ?? 60;
      context.push('/verify-email?email=${Uri.encodeQueryComponent(email)}&resend=$resend');
    } on ApiError catch (e) {
      if (!mounted) return;
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
      showBack: false,
      topPadding: 28,
      title: 'Create An Account',
      subtitle: 'Sign up to get started!',
      children: [
        if (_banner != null) ErrorBanner(_banner!),
        AppTextField(
          label: 'First Name',
          hint: 'Enter your first name',
          controller: _first,
          textInputAction: TextInputAction.next,
          errorText: _errors['first_name'],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Last Name',
          hint: 'Enter your last name',
          controller: _last,
          textInputAction: TextInputAction.next,
          errorText: _errors['last_name'],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Email',
          hint: 'Enter your email address',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          errorText: _errors['email'],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Password',
          hint: 'Enter your password',
          controller: _password,
          obscure: true,
          textInputAction: TextInputAction.next,
          errorText: _errors['password'],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Confirm Password',
          hint: 'Enter your password',
          controller: _confirm,
          obscure: true,
          textInputAction: TextInputAction.done,
          errorText: _errors['confirm'],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        _TermsRow(
          accepted: _terms,
          error: _errors['terms'],
          onChanged: (v) => setState(() {
            _terms = v;
            _errors = {..._errors}..remove('terms');
          }),
        ),
        const SizedBox(height: 28),
        PrimaryButton(label: 'Sign Up', loading: _loading, onPressed: _submit),
        const SizedBox(height: 6),
        TextLinkRow(
          prefix: 'Already have an account? ',
          action: 'Login',
          onTap: () => context.go('/login'),
        ),
      ],
    );
  }
}

class _TermsRow extends StatefulWidget {
  const _TermsRow({required this.accepted, required this.onChanged, this.error});

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final String? error;

  @override
  State<_TermsRow> createState() => _TermsRowState();
}

class _TermsRowState extends State<_TermsRow> {
  late final TapGestureRecognizer _toggle = TapGestureRecognizer()
    ..onTap = () => widget.onChanged(!widget.accepted);
  late final TapGestureRecognizer _openTerms = TapGestureRecognizer()
    ..onTap = () => _openSite('terms.html');
  late final TapGestureRecognizer _openPrivacy = TapGestureRecognizer()
    ..onTap = () => _openSite('privacy.html');

  @override
  void dispose() {
    _toggle.dispose();
    _openTerms.dispose();
    _openPrivacy.dispose();
    super.dispose();
  }

  Future<void> _openSite(String page) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('$_siteBase/$page'), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the page.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = widget.accepted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              checked: accepted,
              label: 'I agree to the Terms and Conditions and the Privacy Policy',
              child: InkWell(
                onTap: () => widget.onChanged(!accepted),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accepted ? AppColors.blueDark : AppColors.authBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accepted ? AppColors.blueDark : const Color(0xFF9EA3B0),
                        width: 1.5,
                      ),
                    ),
                    child: accepted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14, color: Color(0xFF3A3F4B)),
                  children: [
                    TextSpan(text: 'I Agree to the ', recognizer: _toggle),
                    TextSpan(
                      text: 'Terms & Conditions',
                      recognizer: _openTerms,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.blueDark),
                    ),
                    TextSpan(text: ' and ', recognizer: _toggle),
                    TextSpan(
                      text: 'Privacy Policy',
                      recognizer: _openPrivacy,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.blueDark),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(widget.error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ),
      ],
    );
  }
}