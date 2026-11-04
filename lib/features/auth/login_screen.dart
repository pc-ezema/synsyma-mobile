import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_widgets.dart';
import 'auth_controller.dart';
import 'biometric_login.dart';

/// Only the email is remembered by the app. The password is saved by the phone's own
/// password manager (Google Password Manager / iCloud Keychain) through autofill,
/// never by this app.
const _rememberedEmailKey = 'remembered_email';

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
  String? _lastPhotoUrl;
  bool _bioReady = false; // fingerprint sign-in is available and switched on

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
  }

  Future<void> _loadCachedProfile() async {
    final storage = ref.read(storageProvider);
    final name = await storage.read(key: lastFirstNameKey);
    final photo = await storage.read(key: lastPhotoUrlKey);
    final savedEmail = await storage.read(key: _rememberedEmailKey);
    final bio = ref.read(biometricLoginProvider);
    final bioReady = await bio.available && await bio.enabled;
    if (!mounted) return;
    setState(() {
      _bioReady = bioReady;
      if (name != null && name.isNotEmpty) _lastName = name;
      if (photo != null && photo.isNotEmpty) _lastPhotoUrl = photo;
      // Don't overwrite anything the person has already started typing or autofilled.
      if (savedEmail != null && savedEmail.isNotEmpty && _email.text.isEmpty) {
        _email.text = savedEmail;
      }
    });
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

    final bio = ref.read(biometricLoginProvider);
    final offerBiometric = await _shouldOfferBiometric(bio);

    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(email, password);

      // Login worked: remember the email, and let the phone offer to save the password.
      TextInput.finishAutofillContext();
      try {
        await ref.read(storageProvider).write(key: _rememberedEmailKey, value: email);
        if (offerBiometric) {
          await bio.save(email, password); // they said yes before signing in
        } else {
          await bio.refreshIfEnabled(email, password); // keep it in step if the password changed
        }
      } catch (_) {
        // Not being able to remember the email must never block a successful login.
      }
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

  /// Asks once, before the login request, whether to turn on fingerprint sign-in.
  /// Nothing is saved unless the login then succeeds.
  Future<bool> _shouldOfferBiometric(BiometricLogin bio) async {
    if (!await bio.available || await bio.enabled || await bio.declined) return false;
    if (!mounted) return false;

    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fingerprint_rounded, size: 52, color: AppColors.blueDark),
            const SizedBox(height: 12),
            const Text('Sign in faster?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 8),
            const Text(
              'Use your fingerprint or face next time instead of typing your password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.blueDark,
                    side: const BorderSide(color: AppColors.blueDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  child: const Text('Not now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.blueDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  child: const Text('Turn on'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (yes != true) {
      if (yes == false) await bio.decline(); // an explicit "Not now": do not ask again
      return false;
    }
    return bio.confirm('Confirm it is you to turn on fingerprint sign-in');
  }

  Future<void> _biometricSignIn() async {
    setState(() => _banner = null);
    final saved = await ref.read(biometricLoginProvider).unlock();
    if (saved == null || !mounted) return; // cancelled

    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(saved.email, saved.password);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.code == 'email_not_verified') {
        final resend = (e.data['resend_in'] as num?)?.toInt() ?? 60;
        context.push('/verify-email?email=${Uri.encodeQueryComponent(saved.email)}&resend=$resend');
      } else {
        // Most often the password was changed somewhere else. Signing in with the new
        // password below updates what the fingerprint uses.
        setState(() => _banner = '${e.message} If you changed your password, sign in with it once to update fingerprint sign-in.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: false,
      topPadding: 24,
      children: [
        Row(
          children: [
            _Avatar(name: _lastName, photoUrl: _lastPhotoUrl),
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
        // AutofillGroup is what makes Android and iOS offer to save and fill the login.
        AutofillGroup(
          child: Column(
            children: [
              AppTextField(
                label: 'Email',
                hint: 'Enter your email address',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
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
            ],
          ),
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
        if (_bioReady) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loading ? null : _biometricSignIn,
            icon: const Icon(Icons.fingerprint_rounded, size: 22),
            label: const Text('Sign in with fingerprint'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.blueDark,
              side: const BorderSide(color: AppColors.blueDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
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
  const _Avatar({this.name, this.photoUrl});
  final String? name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : null;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return ClipOval(
      child: SizedBox(
        width: 50,
        height: 50,
        child: hasPhoto
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                // Fallback while loading, or on failure (404, offline, etc.)
                loadingBuilder: (_, child, progress) => progress == null ? child : _Fallback(initial: initial),
                errorBuilder: (_, e, __) {
                  debugPrint('[AVATAR] load failed: $e  url=$photoUrl');
                  return _Fallback(initial: initial);
                },
              )
            : _Fallback(initial: initial),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.initial});
  final String? initial;

  @override
  Widget build(BuildContext context) {
    if (initial != null) {
      return Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(gradient: AppColors.blueGradient),
        child: Text(
          initial!,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
    }
    return Container(
      alignment: Alignment.center,
      color: AppColors.fieldBorder,
      child: const Icon(Icons.person_outline, color: Color(0xFF6B7280)),
    );
  }
}