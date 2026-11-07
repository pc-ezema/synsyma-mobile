import 'package:flutter/material.dart';

double _d(dynamic v) => v == null ? 0 : (double.tryParse(v.toString()) ?? 0);

String money(double v, [String currency = 'USD']) {
  final sym = currency == 'GBP' ? '£' : (currency == 'USD' ? '\$' : '$currency ');
  final parts = v.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$sym$whole.${parts[1]}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDay(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "2026-11-10T09:00:00-05:00": the local time plus this phone's offset, which is what the API expects.
String isoWithOffset(DateTime local) {
  final o = local.timeZoneOffset;
  final sign = o.isNegative ? '-' : '+';
  final hh = o.inHours.abs().toString().padLeft(2, '0');
  final mm = (o.inMinutes.abs() % 60).toString().padLeft(2, '0');
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}T${two(local.hour)}:${two(local.minute)}:00$sign$hh:$mm';
}

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.country,
    required this.addressLine1,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.oneLine,
    this.label,
    this.addressLine2,
    this.instructions,
    this.isDefault = false,
  });

  final String id;
  final String? label;
  final String country;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String region;
  final String postalCode;
  final String? instructions;
  final bool isDefault;
  final String oneLine;

  String get title {
    final l = (label ?? '').trim();
    return l.isNotEmpty ? l : addressLine1;
  }

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: j['id'] as String,
        label: j['label'] as String?,
        country: j['country'] as String,
        addressLine1: j['address_line1'] as String,
        addressLine2: j['address_line2'] as String?,
        city: j['city'] as String,
        region: j['region'] as String,
        postalCode: j['postal_code'] as String,
        instructions: j['instructions'] as String?,
        isDefault: j['is_default'] == true,
        oneLine: (j['one_line'] as String?) ?? '',
      );
}

class PricePreview {
  const PricePreview({
    required this.currency,
    required this.isQuote,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.includedHours,
  });

  final String currency;
  final bool isQuote;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final int? includedHours;

  factory PricePreview.fromJson(Map<String, dynamic> j) => PricePreview(
        currency: (j['currency'] as String?) ?? 'USD',
        isQuote: j['is_quote'] == true,
        subtotal: _d(j['subtotal']),
        discount: _d(j['discount_total']),
        tax: _d(j['tax_total']),
        total: _d(j['total']),
        includedHours: (j['included_hours'] as num?)?.toInt(),
      );
}

/// What cancelling would cost, from the server's policy.
class CancelQuote {
  const CancelQuote({required this.allowed, required this.currency, required this.paid, required this.fee, required this.refund, required this.message});
  final bool allowed;
  final String currency;
  final double paid;
  final double fee;
  final double refund;
  final String message;

  factory CancelQuote.fromJson(Map<String, dynamic> j) => CancelQuote(
        allowed: j['allowed'] == true,
        currency: (j['currency'] as String?) ?? 'USD',
        paid: _d(j['paid']),
        fee: _d(j['fee']),
        refund: _d(j['refund']),
        message: (j['message'] as String?) ?? '',
      );
}

/// What the customer may change right now, from the server's policy.
class BookingOptions {
  const BookingOptions({
    required this.canReschedule,
    required this.rescheduleMessage,
    required this.canAddHours,
    required this.maxMoreHours,
    required this.pricePerHour,
    required this.currency,
    required this.hoursMessage,
  });
  final bool canReschedule;
  final String rescheduleMessage;
  final bool canAddHours;
  final int maxMoreHours;
  final double pricePerHour;
  final String currency;
  final String hoursMessage;

  factory BookingOptions.fromJson(Map<String, dynamic> j) {
    final r = j['reschedule'] is Map ? Map<String, dynamic>.from(j['reschedule'] as Map) : <String, dynamic>{};
    final h = j['extra_hours'] is Map ? Map<String, dynamic>.from(j['extra_hours'] as Map) : <String, dynamic>{};
    return BookingOptions(
      canReschedule: r['allowed'] == true,
      rescheduleMessage: (r['message'] as String?) ?? '',
      canAddHours: h['allowed'] == true,
      maxMoreHours: (h['max_more'] as num?)?.toInt() ?? 0,
      pricePerHour: _d(h['price_per_hour']),
      currency: (h['currency'] as String?) ?? 'USD',
      hoursMessage: (h['message'] as String?) ?? '',
    );
  }
}

class BookingEvent {
  const BookingEvent({required this.type, this.toStatus, this.note, this.createdAt});
  final String type;
  final String? toStatus;
  final String? note;
  final DateTime? createdAt;

  factory BookingEvent.fromJson(Map<String, dynamic> j) => BookingEvent(
        type: j['type'] as String,
        toStatus: j['to_status'] as String?,
        note: j['note'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] as String?) ?? '')?.toLocal(),
      );
}

class BookingPayment {
  const BookingPayment({required this.status, required this.amount, this.refunded = 0, this.cardBrand, this.cardLast4, this.paidAt});
  final String status; // requires_payment | succeeded | failed | refunded | partially_refunded
  final double amount;
  final double refunded;
  final String? cardBrand;
  final String? cardLast4;
  final DateTime? paidAt;

  bool get isPaid => const ['succeeded', 'refunded', 'partially_refunded'].contains(status);

  String get cardLabel {
    if (cardBrand == 'paypal') return 'PayPal';
    if ((cardLast4 ?? '').isEmpty) return 'Card';
    final b = (cardBrand ?? '').isEmpty ? 'Card' : '${cardBrand![0].toUpperCase()}${cardBrand!.substring(1)}';
    return '$b •••• $cardLast4';
  }

  factory BookingPayment.fromJson(Map<String, dynamic> j) => BookingPayment(
        status: (j['status'] as String?) ?? 'requires_payment',
        amount: _d(j['amount']),
        refunded: _d(j['refunded_total']),
        cardBrand: j['card_brand'] as String?,
        cardLast4: j['card_last4'] as String?,
        paidAt: DateTime.tryParse((j['paid_at'] as String?) ?? '')?.toLocal(),
      );
}

class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.status,
    required this.serviceName,
    required this.priceType,
    required this.currency,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.totalLabel,
    required this.startsAt,
    required this.addressLine1,
    required this.city,
    required this.region,
    required this.postalCode,
    this.categoryName,
    this.tier,
    this.addressLine2,
    this.instructions,
    this.notes,
    this.contractorName,
    this.imageUrl,
    this.includedHours,
    this.payment,
    this.extraHours = 0,
    this.rescheduleCount = 0,
    this.events = const [],
  });

  final String id;
  final String reference;
  final String status;
  final String serviceName;
  final String? categoryName;
  final String? tier;
  final String priceType;
  final String currency;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String totalLabel;
  final DateTime startsAt; // the customer's local time at the job address
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String region;
  final String postalCode;
  final String? instructions;
  final String? notes;
  final String? contractorName;
  final String? imageUrl;
  final int? includedHours;
  final BookingPayment? payment;
  final int extraHours; // paid hours added after booking
  final int rescheduleCount;
  final List<BookingEvent> events;

  bool get isQuote => priceType == 'quote';
  bool get canCancel => const ['pending_payment', 'confirmed', 'assigned'].contains(status);
  bool get needsPayment => status == 'pending_payment' && !isQuote && total > 0;
  bool get isDone => const ['completed', 'cancelled', 'refunded'].contains(status);
  String get title => tier == null || tier!.isEmpty ? serviceName : '$serviceName (${tier![0].toUpperCase()}${tier!.substring(1)})';
  String get shortAddress => '$addressLine1, $city';
  String get durationLabel {
    if (priceType != 'hourly' || includedHours == null) return 'Per visit';
    final n = includedHours! + extraHours;
    return '$n ${n == 1 ? 'hour' : 'hours'}${extraHours > 0 ? ' (incl. $extraHours extra)' : ''}';
  }
  String get address => [addressLine1, addressLine2, city, region, postalCode].where((e) => (e ?? '').trim().isNotEmpty).join(', ');

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        reference: j['reference'] as String,
        status: j['status'] as String,
        serviceName: j['service_name'] as String,
        categoryName: j['category_name'] as String?,
        tier: j['tier'] as String?,
        priceType: (j['price_type'] as String?) ?? 'fixed',
        currency: (j['currency'] as String?) ?? 'USD',
        subtotal: _d(j['subtotal']),
        discount: _d(j['discount_total']),
        tax: _d(j['tax_total']),
        total: _d(j['total']),
        totalLabel: (j['total_label'] as String?) ?? '',
        startsAt: DateTime.tryParse((j['starts_at_local'] as String?) ?? '') ?? DateTime.now(),
        addressLine1: j['address_line1'] as String,
        addressLine2: j['address_line2'] as String?,
        city: j['city'] as String,
        region: j['region'] as String,
        postalCode: j['postal_code'] as String,
        instructions: j['instructions'] as String?,
        notes: j['notes'] as String?,
        contractorName: j['contractor_name'] as String?,
        imageUrl: j['image_url'] as String?,
        includedHours: (j['included_hours'] as num?)?.toInt(),
        extraHours: (j['extra_hours'] as num?)?.toInt() ?? 0,
        rescheduleCount: (j['reschedule_count'] as num?)?.toInt() ?? 0,
        payment: j['payment'] is Map ? BookingPayment.fromJson(Map<String, dynamic>.from(j['payment'] as Map)) : null,
        events: ((j['events'] as List?) ?? const [])
            .map((e) => BookingEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

String statusText(String s) => const {
      'pending_payment': 'Awaiting payment',
      'confirmed': 'Confirmed',
      'assigned': 'Contractor assigned',
      'in_progress': 'In progress',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'refunded': 'Refunded',
      'quote_requested': 'Quote requested',
      'quote_sent': 'Quote ready',
    }[s] ??
    s;

/// Background and text colour for a status chip.
(Color, Color) statusColors(String s) {
  switch (s) {
    case 'completed':
      return (const Color(0xFFE3F6E8), const Color(0xFF14702B));
    case 'cancelled':
    case 'refunded':
      return (const Color(0xFFFFECEF), const Color(0xFFB4233D));
    case 'pending_payment':
    case 'quote_requested':
    case 'quote_sent':
      return (const Color(0xFFFFF3DC), const Color(0xFF8A5A00));
    default:
      return (const Color(0xFFE6F0FE), const Color(0xFF0057D9));
  }
}

/// One page of bookings plus the tab counts.
class BookingPage {
  const BookingPage({required this.items, this.upcoming = 0, this.cancelled = 0, this.completed = 0});
  final List<Booking> items;
  final int upcoming;
  final int cancelled;
  final int completed;

  factory BookingPage.fromJson(List<dynamic> data, Map<String, dynamic> meta) {
    final c = meta['counts'] is Map ? Map<String, dynamic>.from(meta['counts'] as Map) : <String, dynamic>{};
    int n(String k) => (c[k] as num?)?.toInt() ?? 0;
    return BookingPage(
      items: data.map((e) => Booking.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      upcoming: n('upcoming'),
      cancelled: n('cancelled'),
      completed: n('completed'),
    );
  }
}