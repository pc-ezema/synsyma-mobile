import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';

/// How far ahead customers may book, set by the admin in Settings.
class BookingRules {
  const BookingRules({this.minNoticeHours = 24, this.maxDaysAhead = 90});
  final int minNoticeHours;
  final int maxDaysAhead;

  factory BookingRules.fromJson(Map<String, dynamic> j) => BookingRules(
        minNoticeHours: (j['min_notice_hours'] as num?)?.toInt() ?? 24,
        maxDaysAhead: (j['max_days_ahead'] as num?)?.toInt() ?? 90,
      );
}

/// Falls back to 24 hours and 90 days if the call fails, so booking never breaks.
final bookingRulesProvider = FutureProvider<BookingRules>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get<dynamic>('/bookings/rules', options: Options(method: 'GET'));
    final json = res.data;
    final data = json is Map ? json['data'] : null;
    return data is Map ? BookingRules.fromJson(Map<String, dynamic>.from(data)) : const BookingRules();
  } catch (_) {
    return const BookingRules();
  }
});