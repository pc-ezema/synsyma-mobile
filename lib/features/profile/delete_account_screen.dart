import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../auth/auth_controller.dart';
import '../auth/biometric_login.dart';
import '../home/main_tab.dart';
import '../../core/network/api_client.dart';

/// Delete account. Route: /profile/delete
/// Optional reason, password to confirm, then a final confirm sheet like Logout.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const _reasons = <String, String>{
    'not_using': 'I no longer use the app',
    'found_alternative': 'I found another service',
    'privacy': 'Privacy concerns',
    'bad_experience': 'I had a bad experience',
    'other': 'Other',
  };

  final _password = TextEditingController();
  final _comment = TextEditingController();
  String? _reason;
  bool _show = false;
  bool _busy = false;
  String? _passwordError;

  @override
  void dispose() {
    _password.dispose();
    _comment.dispose();
    super.dispose();
  }

  String get _platform => kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

  Future<bool> _confirm() async {
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)), onPressed: () => Navigator.pop(ctx, false)),
            ),
            const SizedBox(height: 8),
            const Text('Delete your account?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 8),
            const Text('Everything in your account will be removed. This cannot be undone.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            const SizedBox(height: 28),
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
                  child: const Text('No, Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  child: const Text('Yes, Delete'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    return yes == true;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _passwordError = null);
    if (_password.text.isEmpty) {
      setState(() => _passwordError = 'Enter your password to confirm.');
      return;
    }
    if (!await _confirm() || !mounted) return;

    setState(() => _busy = true);
    try {
      final Dio dio = ref.read(dioProvider);
      await dio.delete('/account', data: {
        'password': _password.text,
        'reason': _reason,
        'comment': _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        'platform': _platform,
      });
      await ref.read(biometricLoginProvider).disable(); // forget the saved fingerprint login
      ref.invalidate(mainTabProvider);
      await ref.read(authProvider.notifier).logout(); // the router sends them to /login
    } on ApiError catch (e) {
      if (mounted) setState(() => _passwordError = e.message);
    } on DioException catch (e) {
      final err = ApiError.from(e);
      if (mounted) setState(() => _passwordError = err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPageScaffold(
      title: 'Delete account',
      children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF4F6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF6C9D1))),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Deleting your account is permanent. Your profile, bookings and chat history are removed and you are signed out on every device.',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF5B2430), height: 1.45),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Why are you leaving? (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white)),
            child: RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) {
                if (!_busy) setState(() => _reason = v);
              },
              child: Column(children: [
                for (final e in _reasons.entries)
                  RadioListTile<String>(
                    value: e.key,
                    dense: true,
                    activeColor: AppColors.blueDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: Text(e.value, style: const TextStyle(fontSize: 14, color: Color(0xFF4A4E5A))),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _comment,
            enabled: !_busy,
            maxLength: 500,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Anything you want to tell us? (optional)'),
          ),
          const SizedBox(height: 14),
          const Text('Confirm with your password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: !_show,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _submit(),
            decoration: _decoration('Password', error: _passwordError).copyWith(
              suffixIcon: IconButton(
                tooltip: _show ? 'Hide password' : 'Show password',
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF6B7280)),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Delete my account'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : () => context.pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: AppColors.blueDark,
              side: const BorderSide(color: AppColors.blueDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            child: const Text('Keep my account'),
          ),
      ],
    );
  }

  InputDecoration _decoration(String hint, {String? error}) => InputDecoration(
        hintText: hint,
        errorText: error,
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blueDark, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      );
}