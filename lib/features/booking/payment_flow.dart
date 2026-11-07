import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import 'booking_repository.dart';

/// How the payment step ended.
enum PayResult {
  paid, // money taken (confirmed with the server)
  cancelled, // the customer closed the sheet / page
  redirected, // web: sent to Stripe or PayPal; they come back to the booking afterwards
  failed, // see PayOutcome.message
}

class PayOutcome {
  const PayOutcome(this.result, [this.message]);
  final PayResult result;
  final String? message;
}

enum PayMethod { card, paypal }

/// Asks which way to pay. Skips the question when only one way is switched on.
/// Returns null if the customer closes the sheet.
Future<PayMethod?> choosePayMethod(BuildContext context, BookingRepository repo) async {
  var methods = <PayMethod>[PayMethod.card];
  try {
    final ids = await repo.paymentMethods();
    final parsed = [
      if (ids.contains('card')) PayMethod.card,
      if (ids.contains('paypal')) PayMethod.paypal,
    ];
    if (parsed.isNotEmpty) methods = parsed;
  } catch (_) {
    // keep the card default
  }
  if (methods.length == 1) return methods.first;
  if (!context.mounted) return null;

  return showModalBottomSheet<PayMethod>(
    context: context,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Pay with', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
          const SizedBox(height: 8),
          for (final m in methods)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(ctx, m),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFE7E9EF), borderRadius: BorderRadius.circular(10)),
                    child: Icon(m == PayMethod.card ? Icons.credit_card_rounded : Icons.account_balance_wallet_outlined, size: 20, color: AppColors.navy),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(m == PayMethod.card ? 'Card' : 'PayPal', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF4A4E5A)))),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
                ]),
              ),
            ),
        ]),
      ),
    ),
  );
}

/// Pays for a booking. Card: the Stripe payment sheet on phones, Stripe's hosted page on the web.
/// PayPal: PayPal's page, then we wait for the booking to be confirmed.
///
/// Extra hours: pass [extraHours] and the number already on the booking ([extraHoursBefore]),
/// so the PayPal wait can tell when the new hours were added.
Future<PayOutcome> payForBooking(BookingRepository repo, String bookingId, {PayMethod method = PayMethod.card, int? extraHours, int extraHoursBefore = 0}) async {
  try {
    return method == PayMethod.paypal
        ? await _payWithPayPal(repo, bookingId, extraHours, extraHoursBefore)
        : await _payWithCard(repo, bookingId, extraHours);
  } on StripeException catch (e) {
    if (e.error.code == FailureCode.Canceled) return const PayOutcome(PayResult.cancelled);
    return PayOutcome(PayResult.failed, e.error.localizedMessage ?? 'The payment could not be completed.');
  } on ApiError catch (e) {
    return PayOutcome(PayResult.failed, e.message);
  } catch (_) {
    return const PayOutcome(PayResult.failed, 'The payment could not be completed.');
  }
}

Future<PayOutcome> _payWithCard(BookingRepository repo, String bookingId, int? extraHours) async {
  if (kIsWeb) {
    final returnUrl = '${Uri.base.origin}/#/bookings/$bookingId';
    final d = await repo.startPayment(bookingId, mode: 'checkout', returnUrl: returnUrl, extraHours: extraHours);
    final ok = await launchUrl(Uri.parse(d['url'] as String), webOnlyWindowName: '_self');
    return ok ? const PayOutcome(PayResult.redirected) : const PayOutcome(PayResult.failed, 'Could not open the payment page.');
  }

  final d = await repo.startPayment(bookingId, mode: 'sheet', extraHours: extraHours);
  Stripe.publishableKey = d['publishable_key'] as String;
  await Stripe.instance.applySettings();
  await Stripe.instance.initPaymentSheet(
    paymentSheetParameters: SetupPaymentSheetParameters(
      paymentIntentClientSecret: d['client_secret'] as String,
      merchantDisplayName: 'Synsyma',
      customerId: d['customer_id'] as String?,
      customerEphemeralKeySecret: d['ephemeral_key'] as String?,
      style: ThemeMode.light,
      appearance: const PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: AppColors.blueDark)),
    ),
  );
  await Stripe.instance.presentPaymentSheet();

  // The sheet closed without an error, so the card was charged. Settle the booking now (the webhook does the same).
  await repo.syncPayment(bookingId);
  return const PayOutcome(PayResult.paid);
}

Future<PayOutcome> _payWithPayPal(BookingRepository repo, String bookingId, int? extraHours, int extraHoursBefore) async {
  if (kIsWeb) {
    final returnUrl = '${Uri.base.origin}/#/bookings/$bookingId';
    final d = await repo.startPayment(bookingId, provider: 'paypal', mode: 'redirect', returnUrl: returnUrl, extraHours: extraHours);
    final ok = await launchUrl(Uri.parse(d['url'] as String), webOnlyWindowName: '_self');
    return ok ? const PayOutcome(PayResult.redirected) : const PayOutcome(PayResult.failed, 'Could not open PayPal.');
  }

  // Phone: PayPal opens in the browser. When the customer finishes there, the server confirms the
  // booking, and we poll for that here for up to three minutes.
  final d = await repo.startPayment(bookingId, provider: 'paypal', mode: 'redirect', extraHours: extraHours);
  final ok = await launchUrl(Uri.parse(d['url'] as String), mode: LaunchMode.externalApplication);
  if (!ok) return const PayOutcome(PayResult.failed, 'Could not open PayPal.');

  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(const Duration(seconds: 3));
    try {
      final b = await repo.syncPayment(bookingId);
      final done = extraHours != null ? b.extraHours > extraHoursBefore : b.status != 'pending_payment';
      if (done) return const PayOutcome(PayResult.paid);
    } catch (_) {
      // keep waiting
    }
  }
  return const PayOutcome(PayResult.cancelled);
}