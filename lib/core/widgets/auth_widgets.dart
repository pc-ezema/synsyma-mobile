import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../config/auth_config.dart';
import '../network/api_error.dart';
import '../theme/app_theme.dart';

const _titleColor = Colors.black;
const _bodyColor = Color(0xFF4A4E5A);
const _labelColor = Color(0xFF3A3F4B);
const _mutedColor = Color(0xFF6B7280);

/// Light page with an optional back arrow, title and subtitle.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = true,
    this.topPadding = 0,
    required this.children,
  });

  final String? title;
  final String? subtitle;
  final bool showBack;
  final double topPadding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // The design leaves ~44px for the phone's status bar. A browser has none,
    // so top up the difference and the spacing matches on every device.
    final statusInset = MediaQuery.paddingOf(context).top;
    final extraTop = statusInset < 44 ? 44 - statusInset : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.authBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: extraTop),
                    if (showBack)
                      SizedBox(
                        height: 44,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          // Nudged left so the arrow lines up with the page text.
                          child: Transform.translate(
                            offset: const Offset(-12, 0),
                            child: IconButton(
                              tooltip: 'Back',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                size: 30,
                                color: AppColors.navy,
                              ),
                              onPressed: () =>
                                  context.canPop() ? context.pop() : context.go('/login'),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(height: topPadding),
                    if (title != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _titleColor,
                        ),
                      ),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 14, height: 1.6, color: _bodyColor),
                      ),
                    ],
                    SizedBox(height: title != null ? 28 : 0),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label above a rounded field, with an optional show/hide eye for passwords.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _labelColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          autocorrect: !widget.obscure,
          enableSuggestions: !widget.obscure,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: const TextStyle(fontSize: 14, color: AppColors.navy),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9EA3B0)),
            filled: true,
            fillColor: AppColors.authBg,
            errorText: widget.errorText,
            errorMaxLines: 2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 22,
                      color: _mutedColor,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
            border: _border(AppColors.fieldBorder),
            enabledBorder: _border(AppColors.fieldBorder),
            focusedBorder: _border(AppColors.blueDark, 1.6),
            errorBorder: _border(AppColors.danger),
            focusedErrorBorder: _border(AppColors.danger, 1.6),
          ),
        ),
      ],
    );
  }
}

/// Always in the widget tree, so showing or hiding an error never shifts the fields below it.
class ErrorSlot extends StatelessWidget {
  const ErrorSlot(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : ErrorBanner(message!),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: AppColors.blueDark,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.blueDark.withValues(alpha: 0.65),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
            )
          : Text(label),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF7F1D2D))),
          ),
        ],
      ),
    );
  }
}

/// "Already have an account? Login" style line.
class TextLinkRow extends StatelessWidget {
  const TextLinkRow({super.key, required this.prefix, required this.action, required this.onTap});

  final String prefix;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(prefix, style: const TextStyle(fontSize: 14, color: _mutedColor)),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: Text(
                action,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.blueDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Code entry: boxes you see, one hidden field that does the typing.
/// The hidden field makes paste, SMS autofill and backspace all work.
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = kOtpLength,
    this.onCompleted,
    this.hasError = false,
  });

  final TextEditingController controller;
  final int length;
  final VoidCallback? onCompleted;
  final bool hasError;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _focus.addListener(() => setState(() {}));
  }

  void _onChange() {
    setState(() {});
    if (widget.controller.text.length == widget.length) widget.onCompleted?.call();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final four = widget.length <= 4;
    final boxWidth = four ? 50.0 : 46.0;

    return GestureDetector(
      onTap: _focus.requestFocus,
      child: SizedBox(
        height: 50,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: four ? 15 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(widget.length, (i) {
                  final filled = i < text.length;
                  final active = _focus.hasFocus && i == text.length;
                  final color = widget.hasError
                      ? AppColors.danger
                      : active
                          ? AppColors.blueDark
                          : filled
                              ? AppColors.blueDark.withValues(alpha: 0.5)
                              : AppColors.fieldBorder;
                  return Container(
                    width: boxWidth,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.authBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color, width: active || widget.hasError ? 1.6 : 1),
                    ),
                    child: Text(
                      filled ? text[i] : '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy),
                    ),
                  );
                }),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: widget.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Didn't get a code? Resend" with a countdown between sends.
class ResendRow extends StatefulWidget {
  const ResendRow({super.key, required this.initialSeconds, required this.onResend});

  final int initialSeconds;

  /// Sends a new code and returns the seconds until the next one is allowed.
  /// May throw [ApiError].
  final Future<int> Function() onResend;

  @override
  State<ResendRow> createState() => _ResendRowState();
}

class _ResendRowState extends State<ResendRow> {
  Timer? _timer;
  late int _left = widget.initialSeconds;
  bool _sending = false;
  String? _note;
  bool _noteIsError = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (_left <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _note = null;
    });
    try {
      final next = await widget.onResend();
      if (!mounted) return;
      setState(() {
        _left = next;
        _note = 'A new code has been sent.';
        _noteIsError = false;
      });
      _start();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.retryAfter != null) _left = e.retryAfter!;
        _note = e.message;
        _noteIsError = true;
      });
      _start();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = _left ~/ 60;
    final s = (_left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Didn’t get a code? ', style: TextStyle(fontSize: 14, color: _mutedColor)),
            if (_left > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Resend in $_clock', style: const TextStyle(fontSize: 14, color: _mutedColor)),
              )
            else
              InkWell(
                onTap: _sending ? null : _resend,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                  child: Text(
                    _sending ? 'Sending...' : 'Resend',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.blueDark),
                  ),
                ),
              ),
          ],
        ),
        if (_note != null)
          Text(
            _note!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _noteIsError ? AppColors.danger : AppColors.greenInk,
            ),
          ),
      ],
    );
  }
}
