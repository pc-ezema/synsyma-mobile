import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import 'address_suggestion.dart';
import 'booking_repository.dart';

/// "Find your address": type a street address, tap a suggestion, and the form fills in.
/// Searches inside [country]. Everything stays editable, and the search can be ignored entirely.
class AddressSearchField extends ConsumerStatefulWidget {
  const AddressSearchField({super.key, required this.country, required this.onPick});

  final String country;
  final ValueChanged<AddressSuggestion> onPick;

  @override
  ConsumerState<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends ConsumerState<AddressSearchField> {
  final _c = TextEditingController();
  Timer? _timer;
  CancelToken? _cancel;
  List<AddressSuggestion> _items = const [];
  bool _loading = false;
  bool _searched = false;
  bool _unavailable = false;
  String _filled = '';

  @override
  void didUpdateWidget(covariant AddressSearchField old) {
    super.didUpdateWidget(old);
    if (old.country != widget.country) {
      // suggestions for another country no longer apply
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reset();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancel?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _reset() {
    _timer?.cancel();
    _cancel?.cancel();
    _c.clear();
    setState(() {
      _items = const [];
      _loading = false;
      _searched = false;
      _unavailable = false;
      _filled = '';
    });
  }

  /// Scrolls the form so the box and its suggestions are on screen above the keyboard.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _cancel?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      setState(() {
        _items = const [];
        _loading = false;
        _searched = false;
        _unavailable = false;
        _filled = '';
      });
      return;
    }
    setState(() {
      _loading = true;
      _searched = false;
      _unavailable = false;
      _filled = '';
    });
    _timer = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    final token = CancelToken();
    _cancel = token;
    try {
      final rows = await ref.read(bookingRepositoryProvider).searchAddresses(q, widget.country, cancelToken: token);
      if (!mounted || token.isCancelled || rows == null) return;
      setState(() {
        _items = rows;
        _searched = true;
        _loading = false;
      });
      _reveal();
    } catch (_) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _items = const [];
        _unavailable = true;
        _loading = false;
      });
      _reveal();
    }
  }

  void _pick(AddressSuggestion a) {
    FocusScope.of(context).unfocus();
    widget.onPick(a);
    _c.clear();
    setState(() {
      _filled = a.label;
      _items = const [];
      _searched = false;
      _unavailable = false;
      _loading = false;
    });
  }

  static const _border = BorderSide(color: AppColors.fieldBorder);

  @override
  Widget build(BuildContext context) {
    final showList = _items.isNotEmpty || _searched || _unavailable;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Find your address (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.navy)),
          const SizedBox(height: 8),
          TextField(
            controller: _c,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14, color: AppColors.navy),
            decoration: InputDecoration(
              hintText: 'Start typing your street address',
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9EA3B0)),
              isDense: true,
              filled: true,
              fillColor: AppColors.authBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              prefixIcon: const Icon(Icons.search_rounded, size: 22, color: Color(0xFF6B7280)),
              suffixIcon: _loading
                  ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: _border),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: _border),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blueDark, width: 1.6)),
            ),
          ),
          if (showList)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              // Material (not a coloured Container) so the rows' tap effect draws correctly
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: _border),
                child: Column(
                  children: [
                    for (final a in _items)
                      InkWell(
                        onTap: () => _pick(a),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.place_outlined, size: 20, color: AppColors.blueDark)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(a.label, style: const TextStyle(fontSize: 14, height: 1.35, color: AppColors.navy))),
                            ],
                          ),
                        ),
                      ),
                    if (_unavailable)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text("Address search isn't available right now. Fill in the fields below.", style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      )
                    else if (_searched && _items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No matches. Check the spelling, or fill in the fields below.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (_filled.isNotEmpty)
            Text('Filled from: $_filled. Check the details below and add your apartment or unit if you have one.',
                style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.navy))
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Pick a result to fill in the fields below. Suggestions by ', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse('https://www.geoapify.com/'), mode: LaunchMode.externalApplication),
                  child: const Text('Geoapify', style: TextStyle(fontSize: 12.5, color: AppColors.blueDark, decoration: TextDecoration.underline)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}