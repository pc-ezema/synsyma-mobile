import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../home/main_tab.dart';
import 'booking_models.dart';
import 'payment_flow.dart';
import 'booking_repository.dart';
import 'booking_widgets.dart';

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

  /// If the booking is still unpaid when we open it (for example we just came back from Stripe's page),
  /// ask the server to check with Stripe once.
  Future<void> _syncOnce(Booking b) async {
    if (_synced || b.status != 'pending_payment' || b.isQuote) return;
    _synced = true;
    try {
      final fresh = await ref.read(bookingRepositoryProvider).syncPayment(id);
      if (fresh.status != b.status) {
        ref.invalidate(bookingProvider(id));
        refreshBookings(ref);
        if (mounted) showToast(context, 'Payment received. Your booking is confirmed.');
      }
    } catch (_) {
      // not critical: the Pay button is still there
    }
  }

  Future<void> _pay() async {
    if (_paying) return;
    setState(() => _paying = true);
    final out = await payForBooking(ref.read(bookingRepositoryProvider), id);
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

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final async = ref.watch(bookingProvider(id));
    final b = async.value;
    if (b != null) WidgetsBinding.instance.addPostFrameCallback((_) => _syncOnce(b));

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
          b.needsPayment
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: AppColors.blueDark, side: const BorderSide(color: AppColors.blueDark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => _openChat(context, ref),
                  child: const Text('Chat with us about this booking', style: TextStyle(fontWeight: FontWeight.w600)),
                )
              : PrimaryButton(label: 'Chat with us about this booking', onPressed: () => _openChat(context, ref)),
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
        text = 'Your booking is saved. Pay below to confirm it.';
      case 'quote_requested':
        text = 'We received your request. Our team will reply with a price.';
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

  Widget _details(BuildContext context, WidgetRef ref, Booking b) {
    final pay = b.payment;
    final payment = switch (b.status) {
      'quote_requested' || 'quote_sent' => 'Quote',
      'pending_payment' => 'Not paid yet',
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
        child: b.isQuote
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Priced by quote. We will send you the price.', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
              )
            : InfoList(rows: [
                InfoRow('Amount', money(b.subtotal, b.currency)),
                InfoRow('Discount', b.discount > 0 ? '-${money(b.discount, b.currency)}' : money(0, b.currency)),
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
                      events[i].type == 'created' ? 'Booking created' : (events[i].toStatus != null ? statusText(events[i].toStatus!) : 'Update'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                    if (events[i].createdAt != null)
                      Text('${formatDay(events[i].createdAt!)} · ${formatTime(events[i].createdAt!)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}