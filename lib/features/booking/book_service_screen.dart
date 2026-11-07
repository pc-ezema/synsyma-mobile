import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../catalog/catalog_models.dart';
import '../catalog/catalog_repository.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import 'payment_flow.dart';
import 'booking_widgets.dart';

/// Pick an address, a date and a time, then confirm. Route: /book/:id   (id = the chosen option's id)
class BookServiceScreen extends ConsumerStatefulWidget {
  const BookServiceScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends ConsumerState<BookServiceScreen> {
  // Keep these the same as config/booking.php on the API.
  static const _minNoticeHours = 24;
  static const _maxDaysAhead = 90;
  static const _firstHour = 8;
  static const _lastHour = 18;

  String? _addressId;
  DateTime? _date;
  DateTime? _slot;
  final _notes = TextEditingController();
  final _promo = TextEditingController();
  String? _appliedCode; // a code the server has accepted
  String? _promoError;
  bool _checkingPromo = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = _firstAvailableDay();
  }

  @override
  void dispose() {
    _notes.dispose();
    _promo.dispose();
    super.dispose();
  }

  DateTime get _earliest => DateTime.now().add(const Duration(hours: _minNoticeHours));

  List<DateTime> _slotsFor(DateTime day) {
    final out = <DateTime>[];
    for (var h = _firstHour; h <= _lastHour; h++) {
      for (final m in const [0, 30]) {
        if (h == _lastHour && m > 0) continue;
        final t = DateTime(day.year, day.month, day.day, h, m);
        if (!t.isBefore(_earliest)) out.add(t);
      }
    }
    return out;
  }

  DateTime? _firstAvailableDay() {
    final start = _earliest;
    for (var i = 0; i <= _maxDaysAhead; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      if (_slotsFor(d).isNotEmpty) return d;
    }
    return null;
  }

  SavedAddress? _address(List<SavedAddress> list) {
    if (list.isEmpty) return null;
    return list.firstWhere(
      (a) => a.id == _addressId,
      orElse: () => list.firstWhere((a) => a.isDefault, orElse: () => list.first),
    );
  }

  Future<void> _chooseAddress() async {
    final id = await context.push<String>('/addresses?select=1');
    if (id != null) {
      ref.invalidate(addressesProvider);
      setState(() => _addressId = id);
    }
  }

  Future<void> _pickDate() async {
    final first = _firstAvailableDay();
    if (first == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? first,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: _maxDaysAhead)),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _slot = null;
    });
  }

  Future<void> _applyPromo(String serviceId, String? addressId) async {
    final code = _promo.text.trim();
    if (code.isEmpty || _checkingPromo) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _checkingPromo = true;
      _promoError = null;
    });
    try {
      // The server checks the code for this customer and answers with the new price.
      await ref.read(bookingRepositoryProvider).preview(serviceId, addressId, promoCode: code);
      if (mounted) setState(() => _appliedCode = code);
    } on ApiError catch (e) {
      if (mounted) setState(() => _promoError = e.message);
    } finally {
      if (mounted) setState(() => _checkingPromo = false);
    }
  }

  void _removePromo() => setState(() {
        _appliedCode = null;
        _promo.clear();
        _promoError = null;
      });

  Future<void> _confirm(ServiceOption option, SavedAddress address, bool isQuote) async {
    final slot = _slot;
    if (slot == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final b = await ref.read(bookingRepositoryProvider).createBooking(
            serviceId: option.id,
            addressId: address.id,
            startsAt: slot,
            notes: _notes.text,
            promoCode: _appliedCode,
          );
      refreshBookings(ref);

      // Straight on to payment. If they close it, the booking stays unpaid and shows a Pay button.
      if (!isQuote && b.needsPayment) {
        final repo = ref.read(bookingRepositoryProvider);
        final method = await choosePayMethod(context, repo);
        if (!mounted) return;
        final out = method == null ? const PayOutcome(PayResult.cancelled) : await payForBooking(repo, b.id, method: method);
        if (!mounted) return;
        if (out.result == PayResult.failed) showToast(context, out.message ?? 'The payment could not be completed.');
        if (out.result == PayResult.redirected) return; // the web page has left for Stripe
        refreshBookings(ref);
      }
      if (mounted) context.pushReplacement('/bookings/${b.id}');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(serviceProvider(widget.id));
    final addresses = ref.watch(addressesProvider);

    return SubPageScaffold(
      title: 'Book service',
      children: service.when(
        loading: () => const [Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))],
        error: (_, __) => [
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(children: [
              const Text('Could not load this service.', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => ref.invalidate(serviceProvider(widget.id)), child: const Text('Try again')),
            ]),
          ),
        ],
        data: (s) {
          if (s.options.isEmpty) return const [Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('This service is not available.')))];
          final option = s.options.firstWhere((o) => o.id == widget.id, orElse: () => s.options.first);
          return _sections(s, option, addresses);
        },
      ),
    );
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.authBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blueDark, width: 1.6)),
      );

  Widget _pickRow({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            IconTile(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF6B7280))),
                ],
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
          ]),
        ),
      );

  List<Widget> _sections(ServiceCard s, ServiceOption option, AsyncValue<List<SavedAddress>> addresses) {
    final list = addresses.value ?? const <SavedAddress>[];
    final address = _address(list);
    final preview = ref.watch(pricePreviewProvider((serviceId: option.id, addressId: address?.id, promoCode: _appliedCode)));
    final p = preview.value;
    final isQuote = p?.isQuote ?? option.priceLabel.toLowerCase().contains('quote');
    final slots = _date == null ? const <DateTime>[] : _slotsFor(_date!);
    final ready = address != null && _slot != null;

    return [
      GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: s.imageUrl != null
                  ? Image.network(s.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const IconTile(Icons.home_repair_service_outlined))
                  : const IconTile(Icons.home_repair_service_outlined),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(option.tierLabel == null ? s.name : '${s.name} (${option.tierLabel})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
              const SizedBox(height: 3),
              Text(option.priceLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              if (option.additionalLabel != null) Text(option.additionalLabel!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
          ),
        ]),
      ),
      const SectionLabel('Where'),
      GlassCard(
        child: addresses.isLoading && list.isEmpty
            ? const Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
            : address == null
                ? _pickRow(icon: Icons.add_location_alt_outlined, title: 'Add the job address', subtitle: 'Where should the contractor come?', onTap: _chooseAddress)
                : _pickRow(icon: Icons.location_on_outlined, title: address.title, subtitle: address.oneLine, onTap: _chooseAddress),
      ),
      const SectionLabel('When'),
      if (_date == null)
        const GlassCard(child: Padding(padding: EdgeInsets.all(14), child: Text('No times are available right now.', style: TextStyle(color: Color(0xFF6B7280)))))
      else
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _pickRow(icon: Icons.calendar_today_outlined, title: formatDay(_date!), subtitle: 'Tap to change the date', onTap: _pickDate),
            const Divider(height: 1, color: Color(0xFFE3E6EE)),
            const SizedBox(height: 14),
            if (slots.isEmpty)
              const Padding(padding: EdgeInsets.only(bottom: 14), child: Text('No start times are left on this day. Pick another date.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in slots)
                  ChoiceChip(
                    label: Text(formatTime(t)),
                    selected: _slot == t,
                    selectedColor: AppColors.blueDark,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: _slot == t ? AppColors.blueDark : AppColors.fieldBorder),
                    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _slot == t ? Colors.white : AppColors.navy),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _slot = t),
                  ),
              ]),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Start times run from 8:00 AM to 6:00 PM. Please book at least 24 hours ahead.', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ),
          ]),
        ),
      const SectionLabel('Notes for the contractor (optional)'),
      TextField(controller: _notes, maxLines: 3, maxLength: 1000, decoration: _fieldDeco('Anything we should know before we arrive?')),
      if (!isQuote) ...[
        const SectionLabel('Promo code'),
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: _appliedCode != null
              ? Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF1BA864), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((p?.promoCode ?? _appliedCode!).toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                      const SizedBox(height: 2),
                      Text(
                        p?.promoMessage?.isNotEmpty == true ? p!.promoMessage! : (p?.promoLabel ?? 'Code applied'),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                      ),
                    ]),
                  ),
                  TextButton(onPressed: _removePromo, child: const Text('Remove')),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _promo,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 40,
                        onChanged: (_) {
                          if (_promoError != null) setState(() => _promoError = null);
                        },
                        onSubmitted: (_) => _applyPromo(option.id, address?.id),
                        decoration: _fieldDeco('Enter code').copyWith(counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blueDark,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(84, 48),
                        fixedSize: const Size(84, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _checkingPromo ? null : () => _applyPromo(option.id, address?.id),
                      child: _checkingPromo
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Apply', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  if (_promoError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_promoError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5))),
                ]),
        ),
      ],
      const SectionLabel('Price'),
      GlassCard(
        child: preview.isLoading && p == null
            ? const Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
            : p == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      Expanded(child: Text(_appliedCode != null ? 'Your code no longer works for this booking.' : 'Could not load the price.', style: const TextStyle(color: Color(0xFF6B7280)))),
                      if (_appliedCode != null) TextButton(onPressed: _removePromo, child: const Text('Remove code')),
                    ]),
                  )
                : p.isQuote
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('This service is priced by quote. Send your request and our team will reply with a price.', style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4A4E5A))),
                      )
                    : InfoList(rows: [
                        InfoRow('Subtotal', money(p.subtotal, p.currency)),
                        if (p.discount > 0) InfoRow('Discount', '-${money(p.discount, p.currency)}'),
                        if (p.tax > 0) InfoRow('Tax', money(p.tax, p.currency)),
                        InfoRow('Total', p.total <= 0 ? 'Free' : money(p.total, p.currency), bold: true),
                      ]),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13.5))),
      const SizedBox(height: 22),
      PrimaryButton(label: isQuote ? 'Request a quote' : 'Confirm booking', busy: _busy, onPressed: ready ? () => _confirm(option, address, isQuote) : null),
      const SizedBox(height: 8),
      Text(
        !ready ? 'Choose an address and a start time to continue.' : isQuote ? 'Our team will reply with a price.' : (p != null && p.total <= 0) ? 'No payment needed. Your booking is confirmed straight away.' : 'You will pay securely on the next step.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      ),
    ];
  }
}