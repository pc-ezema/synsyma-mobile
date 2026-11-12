import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// "Report a problem": a short description. onSubmit sends it and returns an error message to show, or null when it worked.
/// Returns true if it was sent.
Future<bool> showProblemSheet(
  BuildContext context, {
  required Future<String?> Function(String note) onSubmit,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _ProblemSheet(onSubmit: onSubmit),
  );
  return sent == true;
}

class _ProblemSheet extends StatefulWidget {
  const _ProblemSheet({required this.onSubmit});
  final Future<String?> Function(String note) onSubmit;

  @override
  State<_ProblemSheet> createState() => _ProblemSheetState();
}

class _ProblemSheetState extends State<_ProblemSheet> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _note.text.trim();
    if (text.length < 5) {
      setState(() => _error = 'Please tell us a little more about what went wrong.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSubmit(text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(child: Text('Report a problem', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black))),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Tell us what went wrong. Our team will contact you, and your job will not be completed automatically meanwhile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF4A4E5A)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            enabled: !_busy,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'What happened?',
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF5F7FB),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.blueDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Send report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}