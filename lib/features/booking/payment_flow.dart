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
  cancelled, // the customer closed the sheet
  redirected, // web: sent to Stripe's page; they come back to the booking afterwards
  failed, // see PayOutcome.message
}

class PayOutcome {
  const PayOutcome(this.result, [this.message]);
  final PayResult result;
  final String? message;
}

/// Pays for a booking: the Stripe payment sheet on phones, Stripe's hosted page on the web.
Future<PayOutcome> payForBooking(BookingRepository repo, String bookingId) async {
  try {
    if (kIsWeb) {
      final returnUrl = '${Uri.base.origin}/#/bookings/$bookingId';
      final d = await repo.startPayment(bookingId, mode: 'checkout', returnUrl: returnUrl);
      final ok = await launchUrl(Uri.parse(d['url'] as String), webOnlyWindowName: '_self');
      return ok ? const PayOutcome(PayResult.redirected) : const PayOutcome(PayResult.failed, 'Could not open the payment page.');
    }

    final d = await repo.startPayment(bookingId, mode: 'sheet');
    Stripe.publishableKey = d['publishable_key'] as String;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: d['client_secret'] as String,
        merchantDisplayName: 'Synsyma',
        customerId: d['customer_id'] as String?,
        customerEphemeralKeySecret: d['ephemeral_key'] as String?,
        style: ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: AppColors.blueDark),
        ),
      ),
    );
    await Stripe.instance.presentPaymentSheet();

    // The sheet closed without an error, so the card was charged. Settle the booking now (the webhook does the same).
    await repo.syncPayment(bookingId);
    return const PayOutcome(PayResult.paid);
  } on StripeException catch (e) {
    if (e.error.code == FailureCode.Canceled) return const PayOutcome(PayResult.cancelled);
    return PayOutcome(PayResult.failed, e.error.localizedMessage ?? 'The payment could not be completed.');
  } on ApiError catch (e) {
    return PayOutcome(PayResult.failed, e.message);
  } catch (_) {
    return const PayOutcome(PayResult.failed, 'The payment could not be completed.');
  }
}