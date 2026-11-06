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
  Future<PricePreview> preview(String serviceId, String? addressId) async {
    final data = await _call('POST', '/users/bookings/preview', data: {'service_id': serviceId, if (addressId != null) 'address_id': addressId});
    return PricePreview.fromJson(_map(data));
  }

  Future<Booking> createBooking({required String serviceId, required String addressId, required DateTime startsAt, String? notes}) async {
    final data = await _call('POST', '/users/bookings', data: {
      'service_id': serviceId,
      'address_id': addressId,
      'starts_at': isoWithOffset(startsAt),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
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

  /// mode: 'sheet' (phone) or 'checkout' (web). Returns the data the payment step needs.
  Future<Map<String, dynamic>> startPayment(String id, {required String mode, String? returnUrl}) async {
    final data = await _call('POST', '/users/bookings/$id/pay', data: {'mode': mode, if (returnUrl != null) 'return_url': returnUrl});
    return _map(data);
  }

  /// Asks the server to check with Stripe, so the screen is right even before the webhook lands.
  Future<Booking> syncPayment(String id) async => Booking.fromJson(_map(await _call('POST', '/users/bookings/$id/pay/sync')));

  Future<Booking> booking(String id) async => Booking.fromJson(_map(await _call('GET', '/users/bookings/$id')));
}

final addressesProvider = FutureProvider.autoDispose<List<SavedAddress>>((ref) => ref.watch(bookingRepositoryProvider).addresses());

/// scope: 'upcoming', 'cancelled' or 'completed'
final bookingsProvider = FutureProvider.autoDispose.family<BookingPage, String>((ref, scope) => ref.watch(bookingRepositoryProvider).bookings(scope));

final bookingProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) => ref.watch(bookingRepositoryProvider).booking(id));

typedef PreviewKey = ({String serviceId, String? addressId});

final pricePreviewProvider = FutureProvider.autoDispose.family<PricePreview, PreviewKey>(
  (ref, key) => ref.watch(bookingRepositoryProvider).preview(key.serviceId, key.addressId),
);

/// Call after a booking is created or changed so the Bookings tab shows the latest.
void refreshBookings(WidgetRef ref) {
  for (final scope in const ['upcoming', 'cancelled', 'completed']) {
    ref.invalidate(bookingsProvider(scope));
  }
}