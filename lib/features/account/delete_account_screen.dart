import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Delete account. Asks why (optional), needs the password, then shows a final confirm dialog.
/// On success it calls [onDeleted]: clear your stored token and send the user to the login screen there.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, required this.dio, required this.onDeleted});

  final Dio dio;
  final Future<void> Function() onDeleted;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const _blue = Color(0xFF0066FF);
  static const _navy = Color(0xFF04143B);
  static const _bg = Color(0xFFF2F4F9);
  static const _red = Color(0xFFD92D4A);

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
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _comment.dispose();
    super.dispose();
  }

  String get _platform => kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

  Future<bool> _confirm() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete your account?', style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
        content: const Text('Your account and everything in it will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep my account')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: _red, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    return yes ?? false;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() { _passwordError = null; _error = null; });
    if (_password.text.isEmpty) {
      setState(() => _passwordError = 'Enter your password to confirm.');
      return;
    }
    if (!await _confirm() || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.dio.delete('/v1/account', data: {
        'password': _password.text,
        'reason': _reason,
        'comment': _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        'platform': _platform,
      });
      await widget.onDeleted();
    } on DioException catch (e) {
      final body = e.response?.data;
      final errors = body is Map ? body['errors'] : null;
      final pw = errors is Map && errors['password'] is List && (errors['password'] as List).isNotEmpty ? errors['password'][0].toString() : null;
      if (!mounted) return;
      setState(() {
        _passwordError = pw;
        _error = pw != null
            ? null
            : e.response?.statusCode == 429
                ? 'Too many attempts. Please wait a minute and try again.'
                : (body is Map && body['message'] is String ? body['message'] as String : "Couldn't delete your account. Check your connection and try again.");
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _navy), tooltip: 'Back', onPressed: _busy ? null : () => Navigator.of(context).maybePop()),
        title: const Text('Delete account', style: TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFFF4F6), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF6C9D1))),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: _red),
                SizedBox(width: 12),
                Expanded(child: Text('Deleting your account is permanent. Your profile, bookings and chat history are removed and you are signed out on every device.', style: TextStyle(color: Color(0xFF5B2430), height: 1.45))),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('Why are you leaving? (optional)', style: TextStyle(color: _navy, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) { if (!_busy) setState(() => _reason = v); },
                child: Column(children: [
                  for (final e in _reasons.entries)
                    RadioListTile<String>(value: e.key, title: Text(e.value, style: const TextStyle(fontSize: 14.5, color: _navy)), activeColor: _blue, dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
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
            const Text('Confirm with your password', style: TextStyle(color: _navy, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: _decoration('Password', error: _passwordError).copyWith(
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF8A94A8)),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: _red, fontSize: 13.5))),
            const SizedBox(height: 26),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: _red, disabledBackgroundColor: _red.withValues(alpha: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Delete my account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(foregroundColor: _blue, side: const BorderSide(color: _blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Keep my account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {String? error}) => InputDecoration(
        hintText: hint,
        errorText: error,
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _blue, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _red, width: 1.5)),
      );
}
