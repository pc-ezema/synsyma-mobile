import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// "How was your service?": five stars and an optional comment.
/// onSubmit sends it and returns an error message to show, or null when it worked. Returns true if it was saved.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String service,
  String? contractor,
  int initialRating = 0,
  String? initialComment,
  required Future<String?> Function(int rating, String comment) onSubmit,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _ReviewSheet(service: service, contractor: contractor, initialRating: initialRating, initialComment: initialComment, onSubmit: onSubmit),
  );
  return saved == true;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.service, required this.initialRating, required this.onSubmit, this.contractor, this.initialComment});

  final String service;
  final String? contractor;
  final int initialRating;
  final String? initialComment;
  final Future<String?> Function(int rating, String comment) onSubmit;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  static const _words = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  late int _rating = widget.initialRating;
  late final TextEditingController _comment = TextEditingController(text: widget.initialComment ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_rating == 0) {
      setState(() => _error = 'Tap a star to choose your rating.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onSubmit(_rating, _comment.text.trim());
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
    final who = (widget.contractor ?? '').isEmpty ? '' : ' with ${widget.contractor}';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)), onPressed: _busy ? null : () => Navigator.pop(context, false)),
            ),
            Text('How was your ${widget.service}$who?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                Semantics(
                  button: true,
                  label: '$i ${i == 1 ? 'star' : 'stars'}',
                  selected: i == _rating,
                  child: InkResponse(
                    radius: 28,
                    onTap: _busy ? null : () => setState(() { _rating = i; _error = null; }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedScale(
                        scale: i <= _rating ? 1.08 : 1,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 46, color: i <= _rating ? const Color(0xFFF5A524) : const Color(0xFFC3C9D6)),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            SizedBox(height: 20, child: Text(_words[_rating], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4A4E5A)))),
            const SizedBox(height: 14),
            TextField(
              controller: _comment,
              enabled: !_busy,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Tell us more (optional)',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF5F7FB),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger))),
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
                    : Text(widget.initialRating > 0 ? 'Update review' : 'Submit review', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}