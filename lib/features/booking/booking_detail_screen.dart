import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../home/main_tab.dart';
import 'booking_models.dart';
import 'payment_flow.dart';
import 'booking_repository.dart';
import 'booking_widgets.dart';
import 'confirm_sheet.dart';
import 'extra_hours_sheet.dart';
import 'reschedule_screen.dart';

/// One booking. Route: /bookings/:id
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _paying = false;
  bool _synced = false;

  String get id => widget.id;

  void _openChat(BuildContext context, WidgetRef ref) {
    ref.read(mainTabProvider.notifier).select(2); // the Chat tab
    context.go('/home');
  }

  /// When we open an active booking (for example we just came back from Stripe's or PayPal's page),
  /// ask the server to check with the gateways once.
  Future<void> _syncOnce(Booking b) async {
    if (_synced || b.isDone || b.isQuoteOpen) return;
    _synced = true;
    try {
      final fresh = await ref.read(bookingRepositoryProvider).syncPayment(id);
      if (fresh.status != b.status || fresh.extraHours != b.extraHours) {
        ref.invalidate(bookingProvider(id));
        ref.invalidate(bookingOptionsProvider(id));
        refreshBookings(ref);
        if (mounted) showToast(context, fresh.extraHours != b.extraHours ? 'Extra hours added.' : 'Payment received. Your booking is confirmed.');
      }
    } catch (_) {
      // not critical: the Pay button is still there
    }
  }

  Future<void> _pay() async {
    if (_paying) return;
    final repo = ref.read(bookingRepositoryProvider);
    final method = await choosePayMethod(context, repo);
    if (method == null || !mounted) return;
    setState(() => _paying = true);
    final out = await payForBooking(repo, id, method: method);
    if (!mounted) return;
    setState(() => _paying = false);
    switch (out.result) {
      case PayResult.paid:
        ref.invalidate(bookingProvider(id));
        refreshBookings(ref);
        showToast(context, 'Payment received. Your booking is confirmed.');
      case PayResult.failed:
        showToast(context, out.message ?? 'The payment could not be completed.');
      case PayResult.cancelled:
      case PayResult.redirected:
        break;
    }
  }

  Future<void> _acceptQuote(Booking b) async {
    final yes = await showConfirmSheet(
      context,
      title: 'Accept this quote?',
      message: 'You agree to pay ${b.quote?.priceLabel ?? money(b.total, b.currency)} for this job. You can pay right after.',
      yesLabel: 'Yes, accept',
      noLabel: 'Not yet',
    );
    if (!yes || !mounted) return;
    setState(() => _paying = true);
    try {
      await ref.read(bookingRepositoryProvider).acceptQuote(id);
      _changed();
      if (mounted) showToast(context, 'Quote accepted. You can pay now.');
    } on ApiError catch (e) {
      if (mounted) showToast(context, e.message);
      ref.invalidate(bookingProvider(id)); // it may have expired while the screen was open
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _declineQuote(Booking b) async {
    final sent = b.status == 'quote_sent';
    final yes = await showConfirmSheet(
      context,
      title: sent ? 'Decline this quote?' : 'Cancel this request?',
      message: sent ? 'The quote will be closed. You can always ask for a new one.' : 'Your quote request will be cancelled.',
      yesLabel: sent ? 'Yes, decline' : 'Yes, cancel',
      danger: true,
    );
    if (!yes || !mounted) return;
    setState(() => _paying = true);
    try {
      await ref.read(bookingRepositoryProvider).declineQuote(id);
      _changed();
      if (mounted) showToast(context, sent ? 'Quote declined.' : 'Request cancelled.');
    } on ApiError catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _changed() {
    ref.invalidate(bookingProvider(id));
    ref.invalidate(bookingOptionsProvider(id));
    refreshBookings(ref);
  }

  Future<void> _reschedule(Booking b, BookingOptions? o) async {
    if (o == null) return;
    if (!o.canReschedule) {
      showToast(context, o.rescheduleMessage);
      return;
    }
    final moved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RescheduleScreen(booking: b, note: o.rescheduleMessage)),
    );
    if (moved == true) _changed();
  }

  Future<void> _addHours(Booking b, BookingOptions o) async {
    final hours = await pickExtraHours(context, o);
    if (hours == null || !mounted) return;
    final repo = ref.read(bookingRepositoryProvider);
    final method = await choosePayMethod(context, repo);
    if (method == null || !mounted) return;

    setState(() => _paying = true);
    final out = await payForBooking(repo, id, method: method, extraHours: hours, extraHoursBefore: b.extraHours);
    if (!mounted) return;
    setState(() => _paying = false);
    switch (out.result) {
      case PayResult.paid:
        _changed();
        showToast(context, 'Extra hours added.');
      case PayResult.failed:
        showToast(context, out.message ?? 'The payment could not be completed.');
      case PayResult.cancelled:
      case PayResult.redirected:
        break;
    }
  }

  Future<void> _cancel() async {
    final repo = ref.read(bookingRepositoryProvider);
    CancelQuote q;
    try {
      q = await repo.cancelPreview(id);
    } on ApiError catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    if (!mounted) return;
    if (!q.allowed) {
      showToast(context, q.message);
      return;
    }
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Cancel this booking?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 12),
            Text(q.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF4A4E5A))),
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
                  child: const Text('No, keep it'),
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
                  child: const Text('Yes, cancel'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (yes != true || !mounted) return;

    setState(() => _paying = true);
    try {
      await repo.cancelBooking(id);
      ref.invalidate(bookingProvider(id));
      refreshBookings(ref);
      if (mounted) showToast(context, q.refund > 0 ? 'Booking cancelled. Your refund is on its way.' : 'Booking cancelled.');
    } on ApiError catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final async = ref.watch(bookingProvider(id));
    final b = async.value;
    if (b != null) WidgetsBinding.instance.addPostFrameCallback((_) => _syncOnce(b));
    final opts = b == null ? null : ref.watch(bookingOptionsProvider(id)).value;

    return SubPageScaffold(
      title: 'Booking details',
      children: [
        if (b == null && async.isLoading)
          const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
        else if (b == null)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(children: [
              const Text('Could not load this booking.', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => ref.invalidate(bookingProvider(id)), child: const Text('Try again')),
            ]),
          )
        else ...[
          _header(b),
          _banner(b),
          if (b.status == 'quote_sent' && b.quote != null) _quoteCard(b),
          const SectionLabel('Booking details'),
          _details(context, ref, b),
          const SectionLabel('Price'),
          _price(b),
          if (b.events.isNotEmpty) ...[const SectionLabel('History'), _history(b)],
          const SizedBox(height: 22),
          if (b.needsPayment) ...[
            PrimaryButton(label: 'Pay ${money(b.total, b.currency)}', busy: _paying, onPressed: _pay),
            const SizedBox(height: 10),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text('Secure payment by Stripe', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ]),
            const SizedBox(height: 14),
          ],
          if (opts != null && opts.canAddHours) ...[
            PrimaryButton(label: 'Add extra hours', busy: _paying, onPressed: () => _addHours(b, opts)),
            const SizedBox(height: 14),
          ],
          b.needsPayment || (opts != null && opts.canAddHours) || (b.quote?.canAccept ?? false)
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: AppColors.blueDark, side: const BorderSide(color: AppColors.blueDark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => _openChat(context, ref),
                  child: const Text('Chat with us about this booking', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              : PrimaryButton(label: 'Chat with us about this booking', onPressed: () => _openChat(context, ref)),
          if (b.quote?.canDecline ?? false) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _paying ? null : () => _declineQuote(b),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(b.status == 'quote_sent' ? 'Decline quote' : 'Cancel request', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          if (b.canCancel) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: _paying ? null : () => _reschedule(b, opts),
                style: TextButton.styleFrom(foregroundColor: AppColors.blueDark),
                child: const Text('Reschedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _paying ? null : _cancel,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Cancel booking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        ],
      ],
    );
  }

  Widget _header(Booking b) => GlassCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BookingThumb(url: b.imageUrl, width: 108),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CategoryPill(b.categoryName ?? 'Service'),
                  const SizedBox(height: 8),
                  Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(b.shortAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [StatusChip(b.status), const SizedBox(width: 8), Flexible(child: Text('#${b.reference}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))))]),
                ]),
              ),
            ),
          ]),
        ),
      );

  Widget _banner(Booking b) {
    String? text;
    switch (b.status) {
      case 'pending_payment':
        text = b.isQuote ? 'You accepted the quote. Pay below to confirm your booking.' : 'Your booking is saved. Pay below to confirm it.';
      case 'quote_requested':
        text = 'We received your request. Our team will reply with a price.';
      case 'quote_sent':
        text = (b.quote?.isExpired ?? false) ? 'This quote has expired. Chat with us and we will send a new one.' : 'Your quote is ready. Check the price below, then accept or decline.';
      case 'confirmed':
        text = 'Your booking is confirmed. We are finding the right contractor for you.';
      case 'assigned':
        text = '${b.contractorName ?? 'A contractor'} will come to you at the time shown below.';
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFCFE0FF))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 19, color: AppColors.blueDark),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.navy))),
        ]),
      ),
    );
  }

  /// The price the team sent, and the two answers.
  Widget _quoteCard(Booking b) {
    final q = b.quote!;
    final exp = q.expiresAt;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your quote', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(q.priceLabel ?? money(b.total, b.currency), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black)),
          if (exp != null) ...[
            const SizedBox(height: 4),
            Text(q.isExpired ? 'Expired on ${formatDay(exp)}' : 'Valid until ${formatDay(exp)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: q.isExpired ? AppColors.danger : const Color(0xFF6B7280))),
          ],
          if ((q.message ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(q.message!, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4A4E5A))),
          ],
          if (q.canAccept) ...[
            const SizedBox(height: 16),
            PrimaryButton(label: 'Accept quote', busy: _paying, onPressed: () => _acceptQuote(b)),
          ],
        ]),
      ),
    );
  }

  Widget _details(BuildContext context, WidgetRef ref, Booking b) {
    final pay = b.payment;
    final payment = switch (b.status) {
      'quote_requested' || 'quote_sent' => 'Quote',
      'pending_payment' => 'Not paid yet',
      _ when pay != null && pay.status == 'refunded' => 'Refunded ${money(pay.refunded, b.currency)}',
      _ when pay != null && pay.status == 'partially_refunded' => 'Paid · ${money(pay.refunded, b.currency)} refunded',
      _ => pay != null && pay.isPaid ? 'Paid · ${pay.cardLabel}' : 'Paid',
    };
    return GlassCard(
      child: Column(children: [
        InfoList(rows: [
          InfoRow('Date', formatDay(b.startsAt)),
          InfoRow('Time', formatTime(b.startsAt)),
          InfoRow('Duration', b.durationLabel),
          InfoRow('Payment', payment),
          InfoRow('Address', b.address),
          if ((b.instructions ?? '').isNotEmpty) InfoRow('Access notes', b.instructions!),
          if ((b.notes ?? '').isNotEmpty) InfoRow('Your notes', b.notes!),
          InfoRow('Contractor', b.contractorName ?? 'Not assigned yet'),
        ]),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => _openChat(context, ref),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Report an issue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _price(Booking b) => GlassCard(
        child: b.isQuote && (b.quote?.price == null)
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Priced by quote. We will send you the price.', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              )
            : InfoList(rows: [
                InfoRow('Amount', money(b.subtotal, b.currency)),
                InfoRow(b.promoCode != null ? 'Discount (${b.promoCode})' : 'Discount', b.discount > 0 ? '-${money(b.discount, b.currency)}' : money(0, b.currency)),
                InfoRow('Tax', money(b.tax, b.currency)),
                InfoRow('Total', money(b.total, b.currency), bold: true),
              ]),
      );

  Widget _history(Booking b) {
    final events = b.events.reversed.toList();
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      child: Column(children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5), decoration: const BoxDecoration(color: AppColors.blueDark, shape: BoxShape.circle)),
                if (i < events.length - 1) Expanded(child: Container(width: 2, color: const Color(0xFFE3E6EE))),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      switch (events[i].type) {
                        'created' => 'Booking created',
                        'rescheduled' => 'Rescheduled',
                        'extra_hours' => 'Extra hours added',
                        'quote_sent' => 'Quote sent',
                        'quote_revised' => 'Quote updated',
                        'quote_withdrawn' => 'Quote withdrawn',
                        'quote_accepted' => 'Quote accepted',
                        'quote_declined' => 'Quote declined',
                        'quote_expired' => 'Quote expired',
                        _ => events[i].toStatus != null ? statusText(events[i].toStatus!) : 'Update',
                      },
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                    if (events[i].createdAt != null)
                      Text('${formatDay(events[i].createdAt!)} · ${formatTime(events[i].createdAt!)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    if ((events[i].type == 'rescheduled' || events[i].type == 'extra_hours') && (events[i].note ?? '').isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 2), child: Text(events[i].note!, style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF6B7280)))),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}