import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'booking_models.dart';

final bookingRepositoryProvider = Provider((ref) => BookingRepository(ref.watch(dioProvider)));

class BookingRepository {
  BookingRepository(this._dio);
  final Dio _dio;

  Future<dynamic> _call(String method, String path, {Object? data, Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.request<dynamic>(path, data: data, queryParameters: query, options: Options(method: method));
      final json = res.data;
      return json is Map ? json['data'] : null;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

  // ---- addresses ----
  Future<List<SavedAddress>> addresses() async {
    final data = await _call('GET', '/users/addresses');
    return (data is List ? data : const []).map((e) => SavedAddress.fromJson(_map(e))).toList();
  }

  Future<SavedAddress> saveAddress(Map<String, dynamic> body, {String? id}) async {
    final data = await _call(id == null ? 'POST' : 'PATCH', id == null ? '/users/addresses' : '/users/addresses/$id', data: body);
    return SavedAddress.fromJson(_map(data));
  }

  Future<void> deleteAddress(String id) => _call('DELETE', '/users/addresses/$id');

  // ---- bookings ----
  /// promoCode: checked by the server. A bad code throws an ApiError with the reason.
  Future<PricePreview> preview(String serviceId, String? addressId, {String? promoCode}) async {
    final data = await _call('POST', '/users/bookings/preview', data: {
      'service_id': serviceId,
      if (addressId != null) 'address_id': addressId,
      if (promoCode != null) 'promo_code': promoCode,
    });
    return PricePreview.fromJson(_map(data));
  }

  Future<Booking> createBooking({required String serviceId, required String addressId, required DateTime startsAt, String? notes, String? promoCode}) async {
    final data = await _call('POST', '/users/bookings', data: {
      'service_id': serviceId,
      'address_id': addressId,
      'starts_at': isoWithOffset(startsAt),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (promoCode != null) 'promo_code': promoCode,
    });
    return Booking.fromJson(_map(data));
  }

  /// scope: upcoming | cancelled | completed
  Future<BookingPage> bookings(String scope) async {
    try {
      final res = await _dio.get<dynamic>('/users/bookings', queryParameters: {'scope': scope});
      final json = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final data = json['data'];
      final meta = json['meta'] is Map ? Map<String, dynamic>.from(json['meta'] as Map) : <String, dynamic>{};
      return BookingPage.fromJson(data is List ? data : const [], meta);
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  /// mode: 'sheet' / 'checkout' (card) or 'redirect' (PayPal). provider: 'stripe' or 'paypal'.
  /// extraHours: pay for extra hours on the booking instead of the booking itself.
  Future<Map<String, dynamic>> startPayment(String id, {required String mode, String provider = 'stripe', String? returnUrl, int? extraHours}) async {
    final data = await _call('POST', '/users/bookings/$id/pay', data: {
      'provider': provider,
      'mode': mode,
      if (returnUrl != null) 'return_url': returnUrl,
      if (extraHours != null) 'extra_hours': extraHours,
    });
    return _map(data);
  }

  /// Which ways to pay are switched on: 'card', 'paypal'.
  Future<List<String>> paymentMethods() async {
    final data = await _call('GET', '/users/payment-methods');
    return (data is List ? data : const []).map((e) => _map(e)['id'] as String).toList();
  }

  /// Asks the server to check with Stripe, so the screen is right even before the webhook lands.
  Future<Booking> syncPayment(String id) async => Booking.fromJson(_map(await _call('POST', '/users/bookings/$id/pay/sync')));

  Future<CancelQuote> cancelPreview(String id) async =>
      CancelQuote.fromJson(_map(await _call('GET', '/users/bookings/$id/cancel-preview')));

  Future<Booking> cancelBooking(String id) async =>
      Booking.fromJson(_map(await _call('POST', '/users/bookings/$id/cancel')));

  Future<Booking> reschedule(String id, DateTime startsAt) async =>
      Booking.fromJson(_map(await _call('POST', '/users/bookings/$id/reschedule', data: {'starts_at': isoWithOffset(startsAt)})));

  Future<BookingOptions> options(String id) async =>
      BookingOptions.fromJson(_map(await _call('GET', '/users/bookings/$id/options')));

  // ---- quotes ----
  /// Accepting turns the quote into an unpaid booking, which the customer then pays.
  Future<Booking> acceptQuote(String id) async =>
      Booking.fromJson(_map(await _call('POST', '/users/bookings/$id/quote/accept')));

  /// Declines a sent quote, or cancels a request that has not been priced yet.
  Future<Booking> declineQuote(String id) async =>
      Booking.fromJson(_map(await _call('POST', '/users/bookings/$id/quote/decline')));

  Future<Booking> booking(String id) async => Booking.fromJson(_map(await _call('GET', '/users/bookings/$id')));
}

final addressesProvider = FutureProvider.autoDispose<List<SavedAddress>>((ref) => ref.watch(bookingRepositoryProvider).addresses());

/// scope: 'upcoming', 'cancelled' or 'completed'
final bookingsProvider = FutureProvider.autoDispose.family<BookingPage, String>((ref, scope) => ref.watch(bookingRepositoryProvider).bookings(scope));

final bookingProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) => ref.watch(bookingRepositoryProvider).booking(id));

final bookingOptionsProvider = FutureProvider.autoDispose.family<BookingOptions, String>(
  (ref, id) => ref.watch(bookingRepositoryProvider).options(id),
);

typedef PreviewKey = ({String serviceId, String? addressId, String? promoCode});

final pricePreviewProvider = FutureProvider.autoDispose.family<PricePreview, PreviewKey>(
  (ref, key) => ref.watch(bookingRepositoryProvider).preview(key.serviceId, key.addressId, promoCode: key.promoCode),
);

/// Call after a booking is created or changed so the Bookings tab shows the latest.
void refreshBookings(WidgetRef ref) {
  for (final scope in const ['upcoming', 'cancelled', 'completed']) {
    ref.invalidate(bookingsProvider(scope));
  }
}